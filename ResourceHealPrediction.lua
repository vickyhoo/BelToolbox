-- Extend only EUI's resource health bar. Health amounts stay in native APIs:
-- the fill-edge anchor and the parent's clip handle current health/overheal.
local _, ns = ...
local events = CreateFrame("Frame")
local overlay, host, calculator, module, active
local lastHost, lastConfig, applied
local updateEvents = {"UNIT_HEAL_PREDICTION", "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_MAX_HEALTH_MODIFIERS_CHANGED"}

local function Paint()
    if not active then return end
    UnitGetDetailedHealPrediction("player", "player", calculator)
    local total = calculator:GetIncomingHeals()
    -- These may be secret numbers. Never compare or calculate with them.
    overlay:SetMinMaxValues(0, UnitHealthMax("player"))
    overlay:SetValue(total)
end

local function SetActive(value)
    if active ~= value then
        active = value
        for _, event in ipairs(updateEvents) do
            if value then events:RegisterUnitEvent(event, "player")
            else events:UnregisterEvent(event) end
        end
    end
    if overlay then overlay:SetShown(value) end
end

local function Layout()
    if not active then return end
    local sb = host._sb
    local fill = sb:GetStatusBarTexture()
    local vertical = sb:GetOrientation() == "VERTICAL"
    local reverse = sb:GetReverseFill()
    local a, b, c, d
    if vertical then
        if reverse then a,b,c,d="TOPLEFT","BOTTOMLEFT","TOPRIGHT","BOTTOMRIGHT"
        else a,b,c,d="BOTTOMLEFT","TOPLEFT","BOTTOMRIGHT","TOPRIGHT" end
    elseif reverse then a,b,c,d="TOPRIGHT","TOPLEFT","BOTTOMRIGHT","BOTTOMLEFT"
    else a,b,c,d="TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT" end
    overlay:ClearAllPoints()
    overlay:SetPoint(a, fill, b)
    overlay:SetPoint(c, fill, d)
    overlay:SetSize(sb:GetWidth(), sb:GetHeight())
    overlay:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    overlay:SetReverseFill(reverse)
    overlay:SetRotatesTexture(vertical)
    overlay:SetFrameLevel(sb:GetFrameLevel() + 1)
    -- Follow the bar texture, including EUI's stock bar shape mask.
    local path = fill:GetTexture() or "Interface\\Buttons\\WHITE8X8"
    if overlay.path ~= path then overlay:SetStatusBarTexture(path); overlay.path = path end
    -- Retexturing can reset a StatusBar's tint.
    overlay:SetStatusBarColor(.25, 1, .45, .6)
    local texture = overlay:GetStatusBarTexture()
    if overlay.mask and (overlay.mask ~= host._blizzBarMask or overlay.fill ~= texture) then
        overlay.fill:RemoveMaskTexture(overlay.mask)
        overlay.mask = nil
    end
    if host._blizzBarMask and not overlay.mask then
        texture:AddMaskTexture(host._blizzBarMask)
        overlay.mask = host._blizzBarMask
    end
    overlay.fill = texture
end

local function Apply(bar, cfg)
    local enabled = ns.GetEnhancements().resourceHealPrediction == true
    if not (enabled and bar and bar._sb and cfg and cfg.enabled ~= false
        and CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction) then
        SetActive(false)
        return
    end
    if host ~= bar then
        if overlay then overlay:Hide() end
        host = bar
        overlay = CreateFrame("StatusBar", nil, bar._sb)
        overlay:EnableMouse(false)
        overlay:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        overlay:SetStatusBarColor(.25, 1, .45, .6)
        overlay:SetMinMaxValues(0, 1)
        overlay:SetValue(0)
        local current = bar
        bar._sb:HookScript("OnSizeChanged", function()
            if host == current then Layout() end
        end)
        bar:HookScript("OnShow", function()
            if host == current then Layout(); Paint() end
        end)
    end
    if not calculator then
        calculator = CreateUnitHealPredictionCalculator()
        -- Clamp against maximum health; the parent clips at the missing-health
        -- edge without Lua reading secret current-health values (as in EUI UF).
        local modes = Enum and Enum.UnitIncomingHealClampMode
        if modes and calculator.SetIncomingHealClampMode then
            calculator:SetIncomingHealClampMode(modes.MaximumHealth)
        end
        modes = Enum and Enum.UnitHealAbsorbClampMode
        if modes and calculator.SetHealAbsorbClampMode then
            calculator:SetHealAbsorbClampMode(modes.MaximumHealth)
        end
        modes = Enum and Enum.UnitHealAbsorbMode
        if modes and calculator.SetHealAbsorbMode then
            calculator:SetHealAbsorbMode(modes.ReducedByIncomingHeals)
        end
    end
    SetActive(true)
    Layout()
    if module.ERB_RoundBar then module.ERB_RoundBar(bar, cfg) end
    Paint()
end

function ns.RefreshResourceHealPrediction()
    local eui = _G.EllesmereUI
    local current = eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIResourceBars
    if not current or type(current.HealthIndicatorsApply) ~= "function" then
        SetActive(false)
        return
    end
    if module ~= current then
        module = current
        hooksecurefunc(current, "HealthIndicatorsApply", function(bar, cfg)
            applied = true
            lastHost, lastConfig = bar, cfg
            Apply(bar, cfg)
        end)
    end
    if applied then Apply(lastHost, lastConfig)
    else
        local cfg = _G._ERB_ResolveHealthCfg and _G._ERB_ResolveHealthCfg()
        Apply(_G.ERB_HealthBar, cfg)
    end
end

for _, event in ipairs({"PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_ENTERING_WORLD"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "EllesmereUIResourceBars" then ns.RefreshResourceHealPrediction() end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ns.RefreshResourceHealPrediction()
    else Paint() end
end)
