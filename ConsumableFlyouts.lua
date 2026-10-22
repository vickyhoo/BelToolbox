-- Secure hover flyouts. Item actions and default selection are independent:
-- left click uses that item; right click changes the category's default.
local _,ns=...
local F={};ns.ConsumableFlyouts=F
local mains={}
local leave=[[
    local popup=self:GetFrameRef("flyout")
    if popup:IsShown() and not popup:GetFrameRef("main"):IsUnderMouse()
        and not popup:IsUnderMouse(true) then popup:Hide() end
]]
local function Style(button,icon)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.icon=button:CreateTexture(nil,"ARTWORK")
    -- No inset: spacing=0 must mean touching visible icon edges.
    button.icon:SetAllPoints();button.icon:SetTexCoord(.08,.92,.08,.92);button.icon:SetTexture(icon)
    button.count=button:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall");button.count:SetPoint("BOTTOMRIGHT",-1,1)
    button.cooldown=CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate");button.cooldown:SetAllPoints()
end
function F.Geometry(left,right,bottom,top,width,height,count,size,gap)
    local step=size+gap
    local room={UP=height-top,DOWN=bottom,LEFT=left,RIGHT=width-right}
    local directions={room.UP>=room.DOWN and "UP"or "DOWN",room.UP>=room.DOWN and "DOWN"or "UP",
        room.RIGHT>=room.LEFT and "RIGHT"or "LEFT",room.RIGHT>=room.LEFT and "LEFT"or "RIGHT"}
    for _,direction in ipairs(directions)do
        local vertical=direction=="UP"or direction=="DOWN"
        local along=math.min(count,6,math.floor((room[direction]+gap)/step))
        local across=math.floor(((vertical and width or height)+gap)/step)
        if along>=1 and across>=1 and math.ceil(count/along)<=across then
            local columns=vertical and math.ceil(count/along)or along
            local rows=vertical and along or math.ceil(count/along)
            return direction,columns,rows
        end
    end
    -- Extremely small viewports: a compact, clamped grid is the last resort.
    local columns=math.max(1,math.floor((width+gap)/step))
    return directions[1],columns,math.ceil(count/columns)
end
function F.Position(main)
    if InCombatLockdown()or not main.flyout then return end
    local size=main:GetWidth();local gap=math.max(0,math.min(16,tonumber(ns.Consumables.Settings().spacing)or 2))
    local scale=main:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local width,height=UIParent:GetWidth()/scale,UIParent:GetHeight()/scale
    local left,bottom=main:GetLeft(),main:GetBottom()
    if not left or not bottom then return end
    local count=main.flyoutCount or 1
    local direction,columns,rows=F.Geometry(left,left+size,bottom,bottom+size,width,height,count,size,gap)
    local popup=main.flyout;popup:ClearAllPoints()
    if direction=="UP"then popup:SetPoint("BOTTOMLEFT",main,"TOPLEFT",0,0)
    elseif direction=="DOWN"then popup:SetPoint("TOPLEFT",main,"BOTTOMLEFT",0,0)
    elseif direction=="RIGHT"then popup:SetPoint("TOPLEFT",main,"TOPRIGHT",0,0)
    else popup:SetPoint("TOPRIGHT",main,"TOPLEFT",0,0)end
    popup:SetSize(columns*(size+gap)-gap,rows*(size+gap)-gap)
    for index,button in ipairs(popup.items)do
        if index<=count then
            local column,row
            if direction=="UP"or direction=="DOWN"then
                column=math.floor((index-1)/rows);row=(index-1)%rows
            else column=(index-1)%columns;row=math.floor((index-1)/columns)end
            button:ClearAllPoints();button:SetSize(size,size)
            if direction=="UP"then button:SetPoint("BOTTOMLEFT",popup,"BOTTOMLEFT",column*(size+gap),row*(size+gap))
            elseif direction=="LEFT"then button:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-column*(size+gap),-row*(size+gap))
            else button:SetPoint("TOPLEFT",popup,"TOPLEFT",column*(size+gap),-row*(size+gap))end
        end
    end
    main.flyoutDirection=direction
    if main.arrow then
        local edges={UP="TOP",DOWN="BOTTOM",LEFT="LEFT",RIGHT="RIGHT"}
        main.arrow:ClearAllPoints()
        main.arrow:SetPoint("CENTER",main,edges[direction],0,0)
        main.arrow:SetRotation(direction=="DOWN"and math.pi or direction=="LEFT"and math.pi/2 or direction=="RIGHT"and -math.pi/2 or 0)
    end
end
function F.Create(parent,name,icon)
    local main=CreateFrame("Button",name,parent,"SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")
    Style(main,icon);main:RegisterForClicks("AnyUp","AnyDown")
    main:SetAttribute("type1","item");main:SetAttribute("type2",nil)
    local popup=CreateFrame("Frame",nil,main,"SecureHandlerEnterLeaveTemplate")
    popup.items={};popup:SetFrameStrata("DIALOG");popup:SetClampedToScreen(true);popup:EnableMouse(true);popup:Hide()
    main.flyout=popup;main:SetFrameRef("flyout",popup);popup:SetFrameRef("main",main);popup:SetFrameRef("flyout",popup)
    main:SetAttribute("_onenter",[[
        if self:GetAttribute("flyoutEnabled") then
            local popup=self:GetFrameRef("flyout")
            popup:Show();popup:RegisterAutoHide(.3);popup:AddToAutoHide(self)
        end
    ]])
    main:SetAttribute("_onleave",leave);popup:SetAttribute("_onleave",leave)
    -- Re-evaluate screen edges on hover out of combat, including after /eui moves.
    main:HookScript("OnEnter",function()F.Position(main)end)
    mains[#mains+1]=main
    return main
end
function F.ShowTooltip(button)
    GameTooltip:Show()
    local main=button.belMain or button
    local popup=main.flyout
    if not popup or not popup:IsShown()then return end
    local left,right,bottom,top=popup:GetLeft(),popup:GetRight(),popup:GetBottom(),popup:GetTop()
    if not left or not right or not bottom or not top then return end
    local scale=popup:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local width,height=UIParent:GetWidth()/scale,UIParent:GetHeight()/scale
    local direction=main.flyoutDirection
    GameTooltip:ClearAllPoints()
    if direction=="UP"or direction=="DOWN"then
        -- Stay beside the entire expanded grid, including any extra columns.
        if width-right>=left then GameTooltip:SetPoint("TOPLEFT",popup,"TOPRIGHT",8,0)
        else GameTooltip:SetPoint("TOPRIGHT",popup,"TOPLEFT",-8,0)end
    else
        if height-top>=bottom then GameTooltip:SetPoint("BOTTOMLEFT",popup,"TOPLEFT",0,8)
        else GameTooltip:SetPoint("TOPLEFT",popup,"BOTTOMLEFT",0,-8)end
    end
end
function F.SetItems(main,list,automatic,tooltip,onSelect,enabled)
    if InCombatLockdown()then return end
    local popup=main.flyout;popup:Hide();main.onSelect=onSelect
    main.autoItemID=automatic and automatic.id;main.autoIcon=automatic and automatic.icon
    main:SetAttribute("autoitem",automatic and "item:"..automatic.id or nil)
    main:SetAttribute("flyoutEnabled",enabled and #list>0 or false)
    main.flyoutCount=#list+1
    for index=1,main.flyoutCount do
        local button=popup.items[index]
        if not button then
            button=CreateFrame("Button",nil,popup,"SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")
            Style(button);button:RegisterForClicks("AnyUp","AnyDown")
            button:SetFrameRef("flyout",popup);button:SetAttribute("_onleave",leave)
            button:SetAttribute("type2",nil)
            main:WrapScript(button,"OnClick","return nil, true",[[
                local popup=self:GetParent()
                local main=popup:GetFrameRef("main")
                if not down then
                    if self:GetAttribute("automatic") then
                        main:SetAttribute("item1",main:GetAttribute("autoitem"))
                    elseif button=="RightButton" then
                        main:SetAttribute("item1",self:GetAttribute("item1"))
                    end
                    popup:Hide()
                end
            ]])
            button:HookScript("PostClick",function(self,key,down)
                if down then return end
                if self.automatic then main.onSelect(nil)
                elseif key=="RightButton"then main.onSelect(self.itemID)end
            end)
            button:HookScript("OnEnter",function(self)
                if self.automatic then
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(ns.L("Automatic selection"))
                    GameTooltip:AddLine(ns.L("Click to restore automatic selection for this category."),1,.82,.3,true);F.ShowTooltip(self)
                else tooltip(self)end
            end)
            button:HookScript("OnLeave",function()GameTooltip:Hide()end)
            popup.items[index]=button
        end
        local entry=list[index-1]
        button.automatic=index==1;button:SetAttribute("automatic",button.automatic)
        button.belMain=main;button.category=main.category;button.itemID=entry and entry.id
        button:SetAttribute("type1",entry and "item"or nil)
        button:SetAttribute("item1",entry and "item:"..entry.id or nil)
        button.icon:SetTexture(entry and entry.icon or "Interface\\Buttons\\UI-RefreshButton")
        if button.automatic then
            if not button.autoLabel then
                button.autoLabel=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");button.autoLabel:SetPoint("CENTER")
                button.autoLabel:SetText(ns.L("Auto"))
            end
            button.autoLabel:Show()
        elseif button.autoLabel then button.autoLabel:Hide()end
        button:Show()
    end
    for index=main.flyoutCount+1,#popup.items do
        local button=popup.items[index];button:SetAttribute("item1",nil);button.itemID=nil;button:Hide()
    end
end
function F.VisitItems(fn)
    for _,main in ipairs(mains)do
        fn(main)
        for _,button in ipairs(main.flyout.items)do if not button.automatic and button.itemID then fn(button)end end
    end
end
function F.PositionAll()for _,main in ipairs(mains)do F.Position(main)end end
function F.CloseAll()
    if InCombatLockdown()then return end
    for _,main in ipairs(mains)do main.flyout:Hide()end
end
