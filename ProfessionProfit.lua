local _,ns=...
local L=ns.L
local unpack=unpack or table.unpack
local rows=setmetatable({}, {__mode="k"})
local cache={}
local attached,pending
local profitTooltip
local function Number(v) return not (issecretvalue and issecretvalue(v)) and type(v)=="number" end
local function Call(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok then return v end
end
-- Opt-in, bounded diagnostics. Nothing polls or prints during normal use.
local diagnostics={enabled=false,log={},counts={}}
local function Debug(event,row,detail)
    if not diagnostics.enabled then return end
    local d=diagnostics
    d.counts[event]=(d.counts[event]or 0)+1
    local state=row and rows[row]
    local stamp=GetTime and string.format("%.2f",GetTime())or "-"
    local message=stamp.." "..event..(row and (" row="..tostring(row))or "")
    if state and state.result then message=message.." result="..(state.result.reason or "ready") end
    if detail then message=message.." "..detail end
    d.log[#d.log+1]=message
    if #d.log>40 then table.remove(d.log,1)end
end
local function Flag(object,method,...)
    if not object or type(object[method])~="function"then return "-"end
    local value=Call(object[method],object,...)
    if issecretvalue and issecretvalue(value)then return "secret"end
    return tostring(value)
end
local function Price(v) return Number(v) and v>0 and v or nil end
function ns.GetProfessionProfitSettings()
    local db=ns.GetSettings();db.professionProfit=db.professionProfit or {};return db.professionProfit
end
local function AuctionAPI()
    return Auctionator and Auctionator.API and Auctionator.API.v1
end
function ns.GetProfessionPriceSources()
    local a=AuctionAPI()
    return {
        auctionator=a and type(a.GetAuctionPriceByItemID)=="function" or false,
        tsm=TSM_API and type(TSM_API.GetCustomPriceValue)=="function" or false,
        craftprofit=CraftProfit and type(CraftProfit.GetSalePrice)=="function" or false,
    }
end
local names={auctionator="Auctionator",tsm="TradeSkillMaster",craftprofit="CraftProfit"}
local function Lookup(itemID,kind,used)
    local available=ns.GetProfessionPriceSources()
    local wanted=ns.GetProfessionProfitSettings().source or "auto"
    local order=wanted=="auto" and {"auctionator","tsm","craftprofit"} or {wanted}
    local value
    for _,key in ipairs(order) do
        if available[key] then
            if key=="auctionator" then value=Call(AuctionAPI().GetAuctionPriceByItemID,"BelToolbox",itemID)
            elseif key=="tsm" then value=Call(TSM_API.GetCustomPriceValue,"DBMarket","i:"..itemID)
            else value=Call(CraftProfit.GetSalePrice,CraftProfit,itemID) end
            value=Price(value)
            if value then used[names[key]]=true;break end
        end
    end
    if kind=="reagent" then
        local api=AuctionAPI()
        local vendor=api and Price(Call(api.GetVendorPriceByItemID,"BelToolbox",itemID))
        if vendor and (not value or vendor<value) then value=vendor;used[L("Vendor purchase price")]=true end
    end
    return value
end
local function Missing(reason) return {reason=reason} end
function ns.CalculateRecipeProfit(recipeID)
    local settings=ns.GetProfessionProfitSettings()
    local signature=(settings.source or "auto")..":"..tostring(settings.ahCut or 5)
    local saved=cache[recipeID]
    if saved and saved.signature==signature then return saved.value end
    local t=C_TradeSkillUI
    local schematic=t and Call(t.GetRecipeSchematic,recipeID,false)
    if type(schematic)~="table" then return Missing("Recipe data unavailable") end
    local used={}
    local cost=0
    for _,slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if slot.required~=false and slot.reagentType==((Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 0) then
            local quantity=slot.quantityRequired
            if not Number(quantity) or quantity<0 then return Missing("Recipe data unavailable") end
            if quantity>0 then
                local best
                for _,reagent in ipairs(slot.reagents or {}) do
                    if Number(reagent.itemID) then
                        local value=Lookup(reagent.itemID,"reagent",used)
                        if value and (not best or value<best) then best=value end
                    end
                end
                if not best then return Missing("Missing reagent prices") end
                cost=cost+best*quantity
            end
        end
    end
    local output=schematic.outputItemID
    if not Number(output) or output<=0 then
        local info=Call(t.GetRecipeOutputItemData,recipeID,{})
        if type(info)=="table" then
            output=info.itemID
            if (not Number(output) or output<=0) and type(info.hyperlink)=="string" then output=tonumber(info.hyperlink:match("item:(%d+)")) end
        end
    end
    if not Number(output) or output<=0 then return Missing("No tradable item output") end
    local sale=Lookup(output,"sale",used)
    if not sale then return Missing("Missing output price") end
    local minimum=schematic.quantityMin or 1
    local maximum=schematic.quantityMax or minimum
    if not Number(minimum) or not Number(maximum) or minimum<=0 or maximum<minimum then return Missing("Recipe data unavailable") end
    local quantity=(minimum+maximum)/2
    local cut=settings.ahCut
    cut=Number(cut) and math.max(0,math.min(30,cut)) or 5
    local value={cost=cost,sale=sale*quantity,net=sale*quantity*(1-cut/100)-cost,quantity=quantity,cut=cut,used=used,variable=maximum~=minimum}
    value.returnPercent=cost>0 and value.net/cost*100 or nil
    cache[recipeID]={signature=signature,value=value}
    return value
end
local function Money(v)
    v=math.floor(math.abs(v)+.5)
    if GetMoneyString then return GetMoneyString(v,true) end
    return tostring(v)
end
local percentUnits={{1e9,"b"},{1e6,"m"},{1e3,"k"}}
local function Percent(value,compact)
    if not Number(value) then return "—" end
    local sign=value>=0 and "+" or "-"
    local amount=math.abs(value)
    if compact then
        for _,unit in ipairs(percentUnits)do
            if amount>=unit[1]then return sign..string.format("%.1f",amount/unit[1])..unit[2].."%"end
        end
        if amount>=100 then return sign..string.format("%.0f%%",amount)end
    end
    return sign..string.format("%.1f%%",amount)
end
local function Tag(net,percent)
    local amount=math.abs(net)
    local coin,number
    if amount>=10000 then coin="Gold";number=string.format(amount>=1000000 and "%.0f" or "%.1f",amount/10000)
    elseif amount>=100 then coin="Silver";number=tostring(math.floor(amount/100+.5))
    else coin="Copper";number=tostring(math.floor(amount+.5)) end
    local color=net>=0 and "|cff55ee55" or "|cffff5555"
    return color..(net>=0 and "+" or "-")..number.."|r|TInterface\\MoneyFrame\\UI-"..coin.."Icon:12:12:0:0|t "..color.."("..Percent(percent,true)..")|r"
end
local function Restore(row,state)
    if state.tag then state.tag:Hide() end
    if row.Label and state.width and row.Label:GetWidth()==state.appliedWidth then row.Label:SetWidth(state.width) end
    state.width,state.appliedWidth=nil,nil
    if row.Label and state.color then
        local r,g,b=row.Label:GetTextColor()
        if r==state.color[1] and g==state.color[2] and b==state.color[3] and state.originalColor then row.Label:SetTextColor(unpack(state.originalColor)) end
    end
    state.color,state.originalColor=nil,nil
end
local function RowInfo(row,node)
    node=node or (row.GetElementData and row:GetElementData())
    local data=node and (node.GetData and node:GetData() or node.data or node)
    return data and data.recipeInfo
end
local function Difficulty(info)
    if not info.learned or info.disabled then return end
    local t=C_TradeSkillUI
    if (t.IsTradeSkillGuild and t.IsTradeSkillGuild()) or (t.IsNPCCrafting and t.IsNPCCrafting()) or (t.IsRuneforging and t.IsRuneforging()) then return end
    if info.canSkillUp==false then return TRIVIAL_DIFFICULTY_COLOR or GRAY_FONT_COLOR end
    local e=Enum.TradeskillRelativeDifficulty
    if not e then return end
    if info.relativeDifficulty==e.Optimal then return DIFFICULT_DIFFICULTY_COLOR
    elseif info.relativeDifficulty==e.Medium then return FAIR_DIFFICULTY_COLOR
    elseif info.relativeDifficulty==e.Easy then return EASY_DIFFICULTY_COLOR
    elseif info.relativeDifficulty==e.Trivial then return TRIVIAL_DIFFICULTY_COLOR or GRAY_FONT_COLOR end
end
local function ShowInfo(row)
    local state=rows[row]
    Debug("tooltip-request",row)
    if not state or not state.result or not state.tag or not state.tag:IsShown() then Debug("tooltip-skipped",row);return end
    if not profitTooltip then
        profitTooltip=CreateFrame("GameTooltip","BelToolboxProfitTooltip",UIParent,"GameTooltipTemplate")
        if profitTooltip.HookScript then
            profitTooltip:HookScript("OnHide",function()
                if not diagnostics.enabled then return end
                local stack=debugstack and debugstack(2,4,0)or "-"
                Debug("tooltip-hide",nil,tostring(stack):gsub("[\r\n]+"," | "):sub(1,600))
            end)
        end
    end
    local tip=profitTooltip
    -- Hidden tooltips can retain their owner; always start a fresh build.
    tip:SetOwner(row,"ANCHOR_RIGHT")
    tip:AddLine(L("Recipe Profit"),1,.82,0)
    local result=state.result
    if result.reason then tip:AddLine(L(result.reason),1,1,1)
    else
        tip:AddDoubleLine(L("Craft cost"),Money(result.cost),1,1,1,1,1,1)
        tip:AddDoubleLine(L("Expected sale value"),Money(result.sale),1,1,1,1,1,1)
        tip:AddDoubleLine(L("Auction cut"),tostring(result.cut).."%",1,1,1,1,1,1)
        tip:AddDoubleLine(L("Estimated net profit"),(result.net<0 and "-" or "+")..Money(result.net),1,1,1,result.net>=0 and .3 or 1,result.net>=0 and 1 or .3,.3)
        tip:AddDoubleLine(L("Return on crafting cost"),Percent(result.returnPercent),1,1,1,result.net>=0 and .3 or 1,result.net>=0 and 1 or .3,.3)
    end
    tip:Show()
    if EllesmereUI and type(EllesmereUI._skinBlizzardTooltipFrame)=="function" then
        EllesmereUI._skinBlizzardTooltipFrame(tip)
    end
    Debug("tooltip-shown",row,"shown="..Flag(tip,"IsShown").." visible="..Flag(tip,"IsVisible").." alpha="..Flag(tip,"GetAlpha"))
end
local function HideInfo(row)
    if profitTooltip and profitTooltip:GetOwner()==row then profitTooltip:Hide()end
end
local Paint
local function EnsureRowScripts(row,state)
    if state.bindingScripts then return end
    state.bindingScripts=true
    for script,handler in pairs(state.handlers)do
        local current=row.GetScript and row:GetScript(script)
        if not state.scripts[script]or (row.GetScript and current~=state.scripts[script])then
            row:HookScript(script,handler)
            state.scripts[script]=row.GetScript and row:GetScript(script)or true
            Debug("row-script-bound",row,script)
        end
    end
    state.bindingScripts=nil
end
Paint=function(row,node)
    if not row or not row.Label then return end
    local state=rows[row]
    if not state then
        state={scripts={},handlers={}};rows[row]=state
        state.handlers.OnHide=function()
            Debug("row-hide",row)
            HideInfo(row)
            Restore(row,state);state.result=nil
        end
        -- Pooled rows can be shown again without an initialization callback.
        -- Also refresh on entry in case a parent window reopened before data
        -- arrived or its show hook ran while the profession frame was hidden.
        state.handlers.OnShow=function()Debug("row-show",row);Paint(row)end
        state.handlers.OnEnter=function()Debug("row-enter",row);Paint(row);ShowInfo(row)end
        state.handlers.OnLeave=function()
            Debug("row-leave",row)
            HideInfo(row)
            Paint(row)
        end
        -- Native recipe Init can replace a row's OnEnter via SetScript.
        -- Reattach after that replacement, preserving the new native handler.
        -- The guard also covers clients where HookScript calls SetScript.
        if type(row.SetScript)=="function"then
            hooksecurefunc(row,"SetScript",function(_,script)
                if state.handlers[script]then EnsureRowScripts(row,state)end
            end)
        end
    end
    EnsureRowScripts(row,state)
    Restore(row,state)
    -- The ScrollBox callback's node is authoritative. Some Forever row
    -- instances do not expose GetElementData after a parent hide/show.
    -- Keep that binding until the next initialization replaces it, including
    -- category nodes (which intentionally have no recipeInfo).
    local current=node or (row.GetElementData and row:GetElementData())
    if current then state.node=current end
    local info=RowInfo(row,state.node)
    local settings=ns.GetProfessionProfitSettings()
    if settings.enabled==false or not info or not Number(info.recipeID) then
        state.result=nil;Debug("row-no-data",row,settings.enabled==false and "disabled"or "missing-recipe");HideInfo(row);return
    end
    if settings.difficulty~=false then
        local color=Difficulty(info)
        if color then
            state.originalColor={row.Label:GetTextColor()}
            state.color={color.r,color.g,color.b};row.Label:SetTextColor(unpack(state.color))
        end
    end
    -- Let CraftProfit/CraftShuffle own their active row tags; never duplicate or
    -- suppress another addon's widgets or alter its settings.
    if CraftProfit and CraftProfit.settings and CraftProfit.settings.showRowTags~=false then state.result=nil;Debug("row-yield-craftprofit",row);HideInfo(row);return end
    if not state.tag then
        state.tag=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        state.tag:SetJustifyH("RIGHT");state.tag:SetWordWrap(false)
    end
    local result=ns.CalculateRecipeProfit(info.recipeID);state.result=result
    state.tag:ClearAllPoints()
    local locked=row.LockedIcon and row.LockedIcon:IsShown()
    state.tag:SetPoint("RIGHT",locked and row.LockedIcon or row,locked and "LEFT" or "RIGHT",-4,0)
    state.tag:SetWidth(0)
    state.tag:SetText(result.net and Tag(result.net,result.returnPercent) or "|cff999999—|r")
    local textWidth=state.tag.GetUnboundedStringWidth and state.tag:GetUnboundedStringWidth()or state.tag:GetStringWidth()
    local tagWidth=math.ceil(textWidth)+4
    state.tag:SetWidth(tagWidth)
    state.tag:Show()
    -- Reserve only the right side. Leave SkillUps and its native colors/show
    -- state entirely to Blizzard, even for trivial recipes and pooled rows.
    local width=row:GetWidth()
    local left=row.Label:GetLeft();local rowLeft=row:GetLeft()
    local inset=Number(left) and Number(rowLeft) and left-rowLeft or 24
    local count=row.Count and row.Count:IsShown() and row.Count:GetStringWidth() or 0
    local lockWidth=locked and row.LockedIcon:GetWidth()+4 or 0
    state.width=row.Label:GetWidth()
    state.appliedWidth=math.max(30,math.min(state.width,width-inset-count-lockWidth-tagWidth-10))
    row.Label:SetWidth(state.appliedWidth)
end
function ns.RefreshProfessionProfit()
    wipe(cache)
    if ProfessionsFrame and ProfessionsFrame.IsShown and not ProfessionsFrame:IsShown() then return end
    local list=ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList
    local scroll=list and list.ScrollBox
    if scroll and scroll.ForEachFrame then scroll:ForEachFrame(function(row,node)Paint(row,node)end) end
end
local function Attach()
    if ProfessionsFrame and ProfessionsFrame.HookScript and diagnostics.windowHooked~=ProfessionsFrame then
        -- Track the window object separately from the opt-in log session.
        local frame=ProfessionsFrame
        diagnostics.windowHooked=frame
        frame:HookScript("OnShow",function()Debug("window-show")end)
        frame:HookScript("OnHide",function()Debug("window-hide")end)
    end
    local scroll=ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList and ProfessionsFrame.CraftingPage.RecipeList.ScrollBox
    if not scroll or attached==scroll then return end
    local event=ScrollBoxListMixin and ScrollBoxListMixin.Event and ScrollBoxListMixin.Event.OnInitializedFrame
    if not event or not scroll.RegisterCallback then return end
    attached=scroll
    Debug("attach",nil,tostring(scroll))
    scroll:RegisterCallback(event,function(_,row,node)Debug("row-init",row);Paint(row,node)end,ns)
    hooksecurefunc(scroll,"SetDataProvider",function()ns.RefreshProfessionProfit()end)
    ns.RefreshProfessionProfit()
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","SKILL_LINES_CHANGED","AUCTION_HOUSE_CLOSED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,addon)
    if event=="ADDON_LOADED"and addon~="Blizzard_Professions"and addon~="Auctionator"and addon~="TradeSkillMaster"and addon~="CraftProfit"then return end
    Debug(event)
    if pending then return end
    pending=true
    C_Timer.After(.1,function()pending=nil;Attach();ns.RefreshProfessionProfit()end)
end)

SLASH_BELPROFITDEBUG1="/belprofitdebug"
SlashCmdList.BELPROFITDEBUG=function(command)
    command=(command or ""):lower():match("^%s*(.-)%s*$")
    local function Print(text)print(L("Bel Toolbox")..": "..text)end
    if command=="on"then
        diagnostics={enabled=true,log={},counts={},windowHooked=diagnostics.windowHooked}
        Print(L("Profit diagnostics enabled. Reproduce the issue, then run /belprofitdebug to report."))
    elseif command=="off"then
        diagnostics.enabled=false
        Print(L("Profit diagnostics disabled."));return
    end
    local frame=ProfessionsFrame
    local scroll=frame and frame.CraftingPage and frame.CraftingPage.RecipeList and frame.CraftingPage.RecipeList.ScrollBox
    Print(L("Profit debug window: shown=%s, visible=%s, scroll=%s, attached=%s",
        Flag(frame,"IsShown"),Flag(frame,"IsVisible"),tostring(scroll),tostring(scroll~=nil and scroll==attached)))
    Print(L("Profit debug tooltip: created=%s, shown=%s, visible=%s, alpha=%s, owner=%s",
        tostring(profitTooltip~=nil),Flag(profitTooltip,"IsShown"),Flag(profitTooltip,"IsVisible"),Flag(profitTooltip,"GetAlpha"),Flag(profitTooltip,"GetOwner")))
    local enabled=ns.GetProfessionProfitSettings().enabled~=false
    Print("enabled="..tostring(enabled).." CraftProfitTags="..tostring(CraftProfit and CraftProfit.settings and CraftProfit.settings.showRowTags~=false or false))
    local count,limit=0,6
    if scroll and type(scroll.ForEachFrame)=="function"then
        scroll:ForEachFrame(function(row,node)
            count=count+1
            if count>limit then return end
            local state=rows[row]
            local info=RowInfo(row,node)
            Print("row="..tostring(row).." recipe="..tostring(info and info.recipeID).." tracked="..tostring(state~=nil)
                .." visible="..Flag(row,"IsVisible").." mouse="..Flag(row,"IsMouseEnabled").." over="..Flag(row,"IsMouseOver")
                .." getter="..tostring(type(row.GetElementData)=="function").." enter="..Flag(row,"GetScript","OnEnter")
                .." tag="..Flag(state and state.tag,"IsShown").." result="..tostring(state and state.result and (state.result.reason or "ready")))
        end)
    end
    Print(L("Profit debug rows: %d",count))
    local counts={};for event,n in pairs(diagnostics.counts)do counts[#counts+1]=event.."="..n end;table.sort(counts)
    Print(table.concat(counts,", "))
    for _,message in ipairs(diagnostics.log)do Print(message)end
    if GetMouseFoci then
        local focus=GetMouseFoci()
        if type(focus)=="table"then
            for i=1,math.min(3,#focus)do
                local target=focus[i]
                Print("mouse-focus="..tostring(target).." name="..Flag(target,"GetName").." parent="..Flag(target,"GetParent"))
            end
        end
    end
end
