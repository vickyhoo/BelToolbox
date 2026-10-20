local _, ns = ...

-- Visual post-processing only. Keep state outside Blizzard's tooltip frames.
local active = setmetatable({}, {__mode="k"})
local unpack = unpack or table.unpack
local borderHooked, applying
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Text(v) return Plain(v) and type(v)=="string" end
local function Allowed(tip)
    if not tip or (tip.IsForbidden and tip:IsForbidden()) then return false end
    -- A widget anchor can restrict layout without marking the tooltip forbidden.
    if tip.GetWidth then
        local ok,width=pcall(tip.GetWidth,tip)
        if not ok or not Plain(width) then return false end
    end
    return true
end
function ns.GetTooltipColorSettings()
    local db=ns.GetSettings()
    db.tooltipColors=db.tooltipColors or {}
    return db.tooltipColors
end
local function Enabled(key)
    local db=ns.GetTooltipColorSettings()
    return db.enabled~=false and db[key]~=false
end
local function Line(tip,i)
    local name=tip.GetName and tip:GetName()
    return Text(name) and _G[name.."TextLeft"..i]
end
local function ClassColor(unit)
    if not UnitClass then return end
    local _,key=UnitClass(unit)
    return Text(key) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[key]
end
local function UnitColor(unit)
    local player=UnitIsPlayer(unit)
    if not Plain(player) then return end
    if player then
        local c=ClassColor(unit)
        if c then return {c.r,c.g,c.b} end
    end
    local reaction=UnitReaction and UnitReaction(unit,"player")
    local c=Plain(reaction) and type(reaction)=="number" and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then return {c.r,c.g,c.b} end
end

-- ApplyBorderStyle is shared by EUI skins. Reuse its exact geometry and alpha,
-- changing only RGB on tooltip-owned borders. No EUI source patch is required.
local function InstallBorderHook()
    local eui=EllesmereUI
    if borderHooked or not (eui and type(eui.ApplyBorderStyle)=="function") then return end
    borderHooked=true
    hooksecurefunc(eui,"ApplyBorderStyle",function(frame,...)
        if applying or not frame or not frame.GetParent then return end
        local owner=frame:GetParent()
        local state=active[owner]
        if not state or not state.color or not Allowed(owner) then return end
        local args={n=select("#",...),...}
        state.frame,state.args=frame,args
        local c=state.color
        applying=true
        eui.ApplyBorderStyle(frame,args[1],c[1],c[2],c[3],unpack(args,5,args.n))
        applying=nil
    end)
end
local function RestoreBorder(tip,state)
    if not Allowed(tip) then return end
    if state.frame and state.args and EllesmereUI and EllesmereUI.ApplyBorderStyle then
        applying=true
        EllesmereUI.ApplyBorderStyle(state.frame,unpack(state.args,1,state.args.n))
        applying=nil
    end
    if state.native and tip.NineSlice and tip.NineSlice.SetBorderColor then
        tip.NineSlice:SetBorderColor(unpack(state.native))
    end
end
local function Clear(tip)
    local state=active[tip]
    if not state then return end
    active[tip]=nil
    RestoreBorder(tip,state)
end
local hooked=setmetatable({}, {__mode="k"})
local function State(tip)
    local state=active[tip]
    if not state then state={lines={}};active[tip]=state end
    if not hooked[tip] and tip.HookScript then
        hooked[tip]=true
        tip:HookScript("OnTooltipCleared",Clear)
        tip:HookScript("OnHide",Clear)
    end
    return state
end
local function Border(tip,state,color)
    if tip.IsEmbedded or not color then return end
    state.color=color
    InstallBorderHook()
    local eui=EllesmereUI
    if borderHooked and eui._applyBlizzardConfiguredBorder and not (EllesmereUIDB and EllesmereUIDB.customTooltips==false) then
        local legacy=1
        if eui.GetTooltipBorder then local _,_,_,_,size=eui.GetTooltipBorder();legacy=size or 1 end
        eui._applyBlizzardConfiguredBorder(tip,"tooltip",legacy)
    elseif tip.NineSlice and tip.NineSlice.SetBorderColor then
        if not state.native then
            local c=TOOLTIP_DEFAULT_COLOR
            state.native=c and {c:GetRGB()} or {1,1,1}
            if tip.NineSlice.GetBorderColor then state.native={tip.NineSlice:GetBorderColor()} end
        end
        tip.NineSlice:SetBorderColor(unpack(color))
    end
end
local function Code(c)
    return string.format("|cff%02x%02x%02x",math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5))
end
local function Wrap(text,first,last,color)
    return text:sub(1,first-1)..Code(color)..text:sub(first,last).."|r"..text:sub(last+1)
end
local function UnitTooltip(tip,data)
    if not Allowed(tip) then return end
    if not Enabled("enabled") then Clear(tip);return end
    local _,unit
    if TooltipUtil and TooltipUtil.GetDisplayedUnit then _,unit=TooltipUtil.GetDisplayedUnit(tip)
    elseif tip.GetUnit then _,unit=tip:GetUnit() end
    if not Text(unit) then return end
    local exists=UnitExists(unit)
    if not Plain(exists) or not exists then return end
    local state=State(tip)
    local color=UnitColor(unit)
    if Enabled("unitBorder") then Border(tip,state,color) end
    if Enabled("unitName") and color then
        local line=Line(tip,1)
        if line then line:SetTextColor(unpack(color)) end
    end
    local guild=GetGuildInfo and GetGuildInfo(unit)
    local ownGuild=GetGuildInfo and GetGuildInfo("player")
    local level=UnitLevel and UnitLevel(unit)
    local class=UnitClass and UnitClass(unit)
    local classColor=ClassColor(unit)
    local count=tip.NumLines and tip:NumLines() or 0
    if not Plain(count) then return end
    for i=2,count do
        local line=Line(tip,i)
        local text=line and line:GetText()
        if Text(text) then
            local previous=state.lines[i]
            if previous and text==previous.rendered then text=previous.original end
            local original=text
            local isGuild=Text(guild) and guild~="" and text:find(guild,1,true)
            if isGuild and Enabled("guild") then
                local mine=Text(ownGuild) and ownGuild==guild
                line:SetTextColor(mine and .25 or .65,mine and 1 or .65,mine and .25 or .65)
            elseif not isGuild then
                -- Match against the localized native level line, not arbitrary
                -- numbers elsewhere (health, item level, inventory counts).
                local lines=data and data.lines
                local native=Plain(lines) and type(lines)=="table" and lines[i]
                local source=native and native.leftText
                local levelLine=Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitLevel
                local isLevel=native and levelLine and Plain(native.type) and native.type==levelLine
                if not isLevel and Text(source) and Plain(level) and type(level)=="number" then
                    local template=UNIT_LEVEL_TEMPLATE
                    if Text(template) then
                        local pattern=template:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"):gsub("%%%%d","%%d+"):gsub("%%%%s",".+")
                        isLevel=source:match(pattern)~=nil
                    end
                end
                if isLevel then
                    if Enabled("level") and Plain(level) and type(level)=="number" then
                        local get=GetCreatureDifficultyColor or GetQuestDifficultyColor
                        local c=get and get(level>0 and level or 999)
                        local first,last=text:find(level>0 and ("%f[%d]"..level.."%f[%D]") or "%?%?")
                        if c and first then text=Wrap(text,first,last,c) end
                    end
                    if Enabled("class") and Text(class) and classColor then
                        local first,last=text:find(class,1,true)
                        if first then text=Wrap(text,first,last,classColor) end
                    end
                elseif Enabled("class") and Text(class) and text==class and classColor then
                    line:SetTextColor(classColor.r,classColor.g,classColor.b)
                end
            end
            if Enabled("faction") then
                if text==FACTION_ALLIANCE then line:SetTextColor(.2,.55,1)
                elseif text==FACTION_HORDE then line:SetTextColor(1,.25,.25) end
            end
            if text~=original then line:SetText(text);state.lines[i]={original=original,rendered=text} end
        end
    end
end
local function ItemTooltip(tip,data)
    if not Allowed(tip) then return end
    if not Enabled("itemBorder") then Clear(tip);return end
    local id=data and data.id
    if not Plain(id) or type(id)~="number" or not C_Item or not C_Item.GetItemQualityByID then return end
    local quality=C_Item.GetItemQualityByID(id)
    if not Plain(quality) or type(quality)~="number" then return end
    local get=C_Item.GetItemQualityColor or GetItemQualityColor
    if not get then return end
    local r,g,b=get(quality)
    if Plain(r) and Plain(g) and Plain(b) and type(r)=="number" and type(g)=="number" and type(b)=="number" then
        Border(tip,State(tip),{r,g,b})
    end
end
function ns.RefreshTooltipColors()
    -- Text settings take effect on the next native tooltip build.
    for tip in pairs(active) do Clear(tip) end
end
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,UnitTooltip)
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,ItemTooltip)
InstallBorderHook()
