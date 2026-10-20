local _, ns = ...
local L = ns.L
local _, class = UnitClass("player")
local root, dirty
local SavePosition
local RegisterMageUnlock
local groups = {}
local function Settings()
    local db = ns.GetSettings()
    db.mage = db.mage or {}
    return db.mage
end
ns.GetMageSettings = Settings
function ns.GetMageDirection()
    local db = Settings()
    if db.direction == "UP" or db.direction == "DOWN" or db.direction == "LEFT" or db.direction == "RIGHT" then return db.direction end
    return db.horizontal and (db.reverse and "LEFT" or "RIGHT") or (db.reverse and "DOWN" or "UP")
end
local categories = {
    { key="teleport", label="Teleports", rune=17031, icon=135744,
      spells={3561,3562,3565,3567,3563,3566,32271,32272,33690,35715,49359,49358,53140} },
    { key="portal", label="Portals", rune=17032, icon=135748,
      spells={10059,11416,11419,11417,11418,11420,32266,32267,33691,35717,49360,49361,53142} },
}
categories[#categories+1] = { key="gem", label="Mana Gems", icon=134132, highest=true, spells={759,3552,10053,10054,27101} }
categories[#categories+1] = { key="water", label="Conjure Water", icon=132794, highest=true, spells={5504,5505,5506,6127,10138,10139,10140,37420,27090} }
categories[#categories+1] = { key="food", label="Conjure Food", icon=133968, highest=true, spells={587,597,990,6129,10144,10145,28612,33717} }
local function Known(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
    return IsSpellKnown and IsSpellKnown(id)
end
local function SpellBinding(id)
    local info = C_Spell.GetSpellInfo(id)
    local rank
    if C_Spell.GetSpellSubtext then rank = C_Spell.GetSpellSubtext(id)
    elseif Spell and Spell.CreateFromSpellID then rank = Spell:CreateFromSpellID(id):GetSpellSubtext() end
    if info and rank and rank ~= "" then return info.name .. "(" .. rank .. ")" end
    return id
end
local function Count(id)
    local api = C_Item and C_Item.GetItemCount or GetItemCount
    local count = api and api(id)
    if count == nil or (issecretvalue and issecretvalue(count)) then return nil end
    return count
end
local function UpdateCounts()
    for _, group in ipairs(groups) do
        local count = group.data.rune and Count(group.data.rune)
        group.main.count:SetText(group.data.rune and (count == nil and "?" or tostring(count)) or "")
    end
end
local function Style(button, icon)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(); background:SetColorTexture(0.12, 0.14, 0.17, 1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1); button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexture(icon)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
end
local function MakeGroup(index, data)
    local main = CreateFrame("Button", "BelToolboxMage" .. data.key, root, "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")
    Style(main, data.icon)
    main:RegisterForClicks("AnyUp", "AnyDown")
    main:SetAttribute("type", "spell")
    main:SetAttribute("shift-type1", "none")
    main:SetAttribute("shift-type2", "none")
    local arrow = main:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    arrow:SetSize(14, 14)
    arrow:SetVertexColor(1, 0.82, 0)
    main.arrow = arrow
    local popup = CreateFrame("Frame", nil, main, "SecureHandlerEnterLeaveTemplate")
    popup:SetFrameStrata("DIALOG"); popup:EnableMouse(true); popup:Hide()
    main:SetFrameRef("flyout", popup)
    popup:SetFrameRef("main", main)
    popup:SetFrameRef("flyout", popup)
    -- A fresh auto-hide registration waits until a driver tick sees the mouse
    -- inside. Re-registering on leave resets it; a fast fly-by may never arm it.
    -- Secure leave checks also cover exits occurring entirely between ticks.
    local leave = [[
        local popup = self:GetFrameRef("flyout")
        if popup:IsShown() and not popup:GetFrameRef("main"):IsUnderMouse()
            and not popup:IsUnderMouse(true) then popup:Hide() end
    ]]
    main:SetAttribute("_onenter", [[
        local popup = self:GetFrameRef("flyout")
        popup:Show()
        popup:RegisterAutoHide(0.3)
        popup:AddToAutoHide(self)
    ]])
    main:SetAttribute("_onleave", leave)
    popup:SetAttribute("_onleave", leave)
    main:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.activeSpell then GameTooltip:SetSpellByID(self.activeSpell) else GameTooltip:SetText(L(data.label)) end
        if data.rune then
            local count = Count(data.rune)
            GameTooltip:AddLine(L("Reagents: %s", count == nil and "?" or tostring(count)), 1, 1, 1)
        end
        GameTooltip:AddLine(L("Hover to expand. Click to cast. Shift-drag to move."), 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    main:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local function EnableDrag(button)
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function()
            if IsShiftKeyDown() and not InCombatLockdown() then
                root:StartMoving()
                button._belDragging = true
            end
        end)
        button:SetScript("OnDragStop", function()
            if button._belDragging and not InCombatLockdown() then SavePosition() end
            button._belDragging = nil
        end)
    end
    EnableDrag(main)
    local group = { main=main, popup=popup, buttons={}, data=data }
    for i, id in ipairs(data.spells) do
        local button = CreateFrame("Button", nil, popup, "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate")
        button:SetFrameRef("flyout", popup)
        button:SetAttribute("_onleave", leave)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetAttribute("shift-type1", "none")
        button:SetAttribute("shift-type2", "none")
        EnableDrag(button)
        Style(button, C_Spell.GetSpellTexture(id))
        button:SetAttribute("type", "spell"); button:SetAttribute("spell", SpellBinding(id))
        button:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(id); GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
        main:WrapScript(button, "OnClick", "return nil, true", [[
            if not IsShiftKeyDown() then
                local popup = self:GetParent()
                popup:GetFrameRef("main"):SetAttribute("spell", self:GetAttribute("spell"))
                if not down then popup:Hide() end
            end
        ]])
        button:HookScript("OnClick", function()
            if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return end
            local db=Settings(); db.lastSpells=db.lastSpells or {}; db.lastSpells[data.key]=id
            main.activeSpell=id
            main.icon:SetTexture(C_Spell.GetSpellTexture(id))
        end)
        group.buttons[i] = button
    end
    groups[index] = group
end
local function ApplyPosition()
    if not root or InCombatLockdown() then return end
    local db=Settings()
    root:ClearAllPoints()
    if db.position then
        local p=db.position
        root:SetPoint(p.point,UIParent,p.relPoint,p.x,p.y)
    elseif db.x and db.y then root:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",db.x,db.y)
    else root:SetPoint("CENTER",UIParent,"CENTER",0,-160)end
end
SavePosition = function()
    root:StopMovingOrSizing()
    Settings().position=nil
    local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    Settings().x = root:GetLeft() * scale
    Settings().y = root:GetBottom() * scale
end
function ns.RefreshMageBar()
    if class ~= "MAGE" then return end
    if InCombatLockdown() then dirty=true; return end
    dirty = nil
    local db = Settings()
    if not root then
        root = CreateFrame("Frame", "BelToolboxMageBar", UIParent)
        root:SetClampedToScreen(true); root:SetMovable(true)
        for index, data in ipairs(categories) do MakeGroup(index, data) end
    end
    local size = db.large and 40 or 32
    ApplyPosition()
    local visibleGroups = 0
    for index, group in ipairs(groups) do
        group.main:SetSize(size,size); group.main:ClearAllPoints()
        group.main:SetPoint("LEFT", root, "LEFT", visibleGroups*(size+4), 0)
        group.popup:Hide(); group.popup:ClearAllPoints()
        local direction = ns.GetMageDirection()
        local horizontal = direction == "LEFT" or direction == "RIGHT"
        local reverse = direction == "LEFT" or direction == "DOWN"
        local arrow = group.main.arrow
        arrow:ClearAllPoints()
        local rotations = { UP=0, DOWN=math.pi, LEFT=math.pi/2, RIGHT=-math.pi/2 }
        local edges = { UP="TOP", DOWN="BOTTOM", LEFT="LEFT", RIGHT="RIGHT" }
        arrow:SetPoint("CENTER", group.main, edges[direction], 0, 0)
        arrow:SetRotation(rotations[direction])
        if horizontal then
            group.popup:SetPoint(reverse and "TOPRIGHT" or "TOPLEFT", group.main, reverse and "TOPLEFT" or "TOPRIGHT", 0, 0)
        else
            group.popup:SetPoint(reverse and "TOPLEFT" or "BOTTOMLEFT", group.main, reverse and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
        end
        local count = 0
        local defaultSpell
        local lastSpell = db.lastSpells and db.lastSpells[group.data.key]
        local remembered
        for i, id in ipairs(group.data.spells) do
            local button = group.buttons[i]
            button:Hide(); button:ClearAllPoints(); button:SetSize(size,size)
            if Known(id) then
                button:SetAttribute("spell", SpellBinding(id))
                if not defaultSpell or group.data.highest then defaultSpell=id end
                if id == lastSpell then remembered=id end
                -- Put the 2px visual gap INSIDE the popup's mouse region so
                -- leaving main for the first spell never closes the flyout.
                local offset = 2+count*(size+2)
                if horizontal then button:SetPoint(reverse and "TOPRIGHT" or "TOPLEFT",group.popup,reverse and "TOPRIGHT" or "TOPLEFT",reverse and -offset or offset,0)
                else button:SetPoint(reverse and "TOPLEFT" or "BOTTOMLEFT",group.popup,reverse and "TOPLEFT" or "BOTTOMLEFT",0,reverse and -offset or offset) end
                button:Show(); count=count+1
            end
        end
        group.popup:SetSize(horizontal and math.max(1,count*(size+2)) or size, horizontal and size or math.max(1,count*(size+2)))
        local activeSpell = remembered or defaultSpell
        group.main.activeSpell = activeSpell
        group.main:SetAttribute("spell", activeSpell and SpellBinding(activeSpell))
        if activeSpell then group.main.icon:SetTexture(C_Spell.GetSpellTexture(activeSpell)) end
        group.main:SetShown(count>0)
        if count>0 then visibleGroups=visibleGroups+1 end
    end
    root:SetSize(math.max(size, visibleGroups*(size+4)-4), size)
    UpdateCounts()
    root:SetShown(db.enabled ~= false and visibleGroups>0)
    RegisterMageUnlock()
end
local unlockRegistered
RegisterMageUnlock=function()
    local EUI=_G.EllesmereUI
    if unlockRegistered or not root or not EUI or not EUI.MakeUnlockElement or not EUI.RegisterUnlockElements then return end
    local element=EUI.MakeUnlockElement({
        key="BelToolboxMageBar",label=L("Mage Bar"),group=L("Bel Toolbox"),order=950,
        noResize=true,ownsPosition=true,noAnchorTarget=true,noAnchorTo=true,noSizeMatchTarget=true,
        getFrame=function()return root end,
        getSize=function()return root:GetWidth(),root:GetHeight()end,
        isHidden=function()return Settings().enabled==false or not root:IsShown()end,
        loadPos=function()
            local db=Settings()
            if db.position then return {point=db.position.point,relPoint=db.position.relPoint,x=db.position.x,y=db.position.y}end
            if db.x and db.y then return {point="BOTTOMLEFT",relPoint="BOTTOMLEFT",x=db.x,y=db.y}end
            return {point="CENTER",relPoint="CENTER",x=0,y=-160}
        end,
        savePos=function(_,point,relPoint,x,y)
            if not point then return end
            Settings().position={point=point,relPoint=relPoint,x=x,y=y}
            Settings().x=nil;Settings().y=nil
            ApplyPosition()
        end,
        clearPos=function()Settings().position=nil;Settings().x=nil;Settings().y=nil;ApplyPosition()end,
        applyPos=ApplyPosition,
    })
    EUI:RegisterUnlockElements({element},"BelToolbox")
    unlockRegistered=true
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN","SPELLS_CHANGED","PLAYER_REGEN_ENABLED","BAG_UPDATE_DELAYED","UNIT_SPELLCAST_SUCCEEDED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit,castGUID,spellID)
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        if unit~="player" or (issecretvalue and issecretvalue(spellID)) then return end
        for _, data in ipairs(categories) do
            for _, id in ipairs(data.spells) do
                if id==spellID then
                    local db=Settings(); db.lastSpells=db.lastSpells or {}; db.lastSpells[data.key]=id
                    ns.RefreshMageBar()
                    return
                end
            end
        end
    elseif event=="BAG_UPDATE_DELAYED" then UpdateCounts()
    elseif event=="PLAYER_REGEN_ENABLED" then if dirty then ns.RefreshMageBar() end
    else ns.RefreshMageBar() end
end)
