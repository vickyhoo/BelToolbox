local _, ns = ...

local events = CreateFrame("Frame")
events:Hide()
local proxy, hookedRack, refreshQueued
local collected = false

local function CreateItemRackButton(rack, original)
    local button = CreateFrame("Button", "BelToolboxItemRackMinimapButton", Minimap)
    button:SetSize(33, 33)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexture("Interface\\AddOns\\ItemRackForever\\ItemRackIcon")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnEnter", function(self)
        original:GetScript("OnEnter")(self)
    end)
    button:SetScript("OnLeave", function(self)
        original:GetScript("OnLeave")(self)
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        original:GetScript("OnClick")(self, mouseButton)
        -- ItemRack's set menu is separate from the EUI flyout and normally uses HIGH.
        local menu = rack.MenuFrame
        if rack.menuDockedTo == self and menu and menu:IsShown() and not InCombatLockdown() then
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
        end
    end)
    return button
end

local function RefreshItemRackButton()
    local rack = _G.ItemRackForever
    local original = rack and rack.MinimapButton
    local db = _G.ItemRackForeverDB
    local rebuild = _G._EMM_FullRebuildMinimap
    if not (Minimap and original and db and rebuild and type(rack.MoveMinimap) == "function") then return end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local wanted = ns.GetEnhancements().collectItemRack == true and db.ShowMinimap == true
    if wanted then original:Hide() end
    if wanted == collected then return end

    collected = wanted
    if collected then
        proxy = proxy or CreateItemRackButton(rack, original)
        proxy:SetParent(Minimap)
        proxy:ClearAllPoints()
        proxy:SetPoint("CENTER", original, "CENTER")
        proxy:SetAlpha(1)
        proxy:Show()
    else
        -- Move it out of both EUI scan roots. A hidden parent also works while
        -- the flyout is open, when EUI intercepts Hide() on collected buttons.
        proxy:SetParent(events)
        proxy:ClearAllPoints()
        if rack.menuDockedTo == proxy and rack.MenuFrame then rack.MenuFrame:Hide() end
        rack.MoveMinimap()
    end
    rebuild()
end

function ns.RefreshItemRackButton()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = nil
        local rack = _G.ItemRackForever
        if rack and rack.MinimapButton and type(rack.MoveMinimap) == "function" and hookedRack ~= rack then
            hookedRack = rack
            hooksecurefunc(rack, "MoveMinimap", function()
                if collected or ns.GetEnhancements().collectItemRack == true then ns.RefreshItemRackButton() end
            end)
        end
        RefreshItemRackButton()
    end)
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon ~= "ItemRackForever" and addon ~= "EllesmereUIMinimap" then return end
    if event == "PLAYER_REGEN_ENABLED" then self:UnregisterEvent(event) end
    ns.RefreshItemRackButton()
end)
