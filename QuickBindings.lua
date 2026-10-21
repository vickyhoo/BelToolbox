-- Hardware-input capture for our buttons while EUI's native binding editor is open.
-- No dependency on EUI's private action-bar tables or protected RunBinding path.
local _,ns=...
local buttons,host,capture={},nil,nil
local L=ns.L
local function Active()
    return host and host:IsShown() and not InCombatLockdown()
        and not (_G.EllesmereUI and EllesmereUI.PadGamepadUI and EllesmereUI.PadGamepadUI())
end
local function Command(button)return "CLICK "..button:GetName()..":LeftButton"end
function ns.UpdateToolbarBindings()
    for button in pairs(buttons)do
        if button.hotkey then
            local key=GetBindingKey(Command(button))
            button.hotkey:SetText(key and (GetBindingText and GetBindingText(key,"KEY_",true)or key)or "")
        end
    end
end
local function StopCapture()
    if capture then capture.button=nil;capture:Hide()end
end
local function Bind(input)
    local button=capture and capture.button
    if not Active()or not button then StopCapture();return end
    if input=="LSHIFT"or input=="RSHIFT"or input=="LCTRL"or input=="RCTRL"or input=="LALT"or input=="RALT"then return end
    if input=="LeftButton"or input=="RightButton"then return end
    input=input:gsub("^Button","BUTTON")
    local command=Command(button)
    if input=="ESCAPE"then
        local key1,key2=GetBindingKey(command)
        if key1 then SetBinding(key1)end
        if key2 then SetBinding(key2)end
    else
        local key=(IsAltKeyDown()and "ALT-"or "")..(IsControlKeyDown()and "CTRL-"or "")..(IsShiftKeyDown()and "SHIFT-"or "")..input
        -- Adding a second key does not silently discard the first one. The
        -- native binding editor resolves conflicts and owns Save/Cancel.
        SetBindingClick(key,button:GetName(),"LeftButton")
    end
    if host.SetOutputText then host:SetOutputText(L("Consumable binding changed. Use the binding window to save or cancel."))end
    ns.UpdateToolbarBindings()
end
local function Capture(button)
    if not Active()then return end
    if not capture then
        capture=CreateFrame("Frame",nil,UIParent)
        capture:SetFrameStrata("TOOLTIP");capture:EnableKeyboard(true);capture:EnableMouse(true);capture:EnableMouseWheel(true)
        capture:SetPropagateKeyboardInput(false)
        capture:SetScript("OnKeyDown",function(_,key)Bind(key)end)
        capture:SetScript("OnMouseDown",function(_,key)Bind(key)end)
        capture:SetScript("OnMouseWheel",function(_,delta)Bind(delta>0 and "MOUSEWHEELUP"or "MOUSEWHEELDOWN")end)
        capture:SetScript("OnLeave",StopCapture)
        local highlight=capture:CreateTexture(nil,"OVERLAY")
        highlight:SetAllPoints();highlight:SetColorTexture(.2,.8,1,.28)
    end
    capture.button=button;capture:ClearAllPoints();capture:SetAllPoints(button);capture:Show()
    GameTooltip:SetOwner(button,"ANCHOR_TOP")
    GameTooltip:SetText(button.belBindingLabel)
    GameTooltip:AddLine(L("Press a key or mouse wheel to bind. Escape clears this button. Save or cancel in EUI's binding window."),1,.82,.3,true)
    GameTooltip:Show()
end
function ns.RegisterToolbarBinding(button,label)
    if buttons[button]then return end
    buttons[button]=true;button.belBindingLabel=label
    button.commandName=Command(button)
    _G["BINDING_NAME_"..Command(button)]=L("Bel Toolbox")..": "..label
    button:HookScript("OnEnter",function()Capture(button)end)
end
function ns.IsToolbarBindingMode()return Active()end
local function Attach()
    if host or not _G.QuickKeybindFrame then return end
    host=QuickKeybindFrame
    host:HookScript("OnShow",function()if ns.RefreshConsumables then ns.RefreshConsumables()end end)
    host:HookScript("OnHide",function()
        StopCapture();GameTooltip:Hide()
        if ns.RefreshConsumables then ns.RefreshConsumables()end
        ns.UpdateToolbarBindings()
    end)
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","UPDATE_BINDINGS","PLAYER_REGEN_DISABLED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_DISABLED"then StopCapture();return end
    Attach();ns.UpdateToolbarBindings()
end)
