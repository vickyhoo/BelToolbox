-- Replace only the visual; EUI retains ownership of resting state and offsets.
local _,ns=...
local record
local function Wanted()return ns.GetEnhancements().animatedRestIndicator~=false end
local function Sync(r)
    if r.syncing then return end
    r.syncing=true
    local enabled=Wanted()
    r.native:SetAlpha(enabled and 0 or r.alpha)
    r.frame:SetShown(enabled and r.native:IsShown()
        and _G.EllesmereUIDB and EllesmereUIDB.showRestedIndicator==true and IsResting() or false)
    r.syncing=nil
end
function ns.RefreshRestIndicator()
    local pf=_G.EllesmereUIUnitFrames_Player
    local native=pf and pf._restIndicator
    if record and record.native==native then Sync(record);return end
    if InCombatLockdown()then return end
    if record then
        record.syncing=true;record.native:SetAlpha(record.alpha);record.frame:Hide()
        record.retired=true;record.syncing=nil;record=nil
    end
    if not native or not pf._restHolder or not Wanted()then return end
    local frame=CreateFrame("Frame",nil,pf._restHolder)
    frame:Hide();frame:SetSize(16,21)
    -- Anchoring to the original region follows EUI's live X/Y controls.
    frame:SetPoint("TOPLEFT",native,"TOPLEFT",0,0)
    local icon=frame:CreateTexture(nil,"OVERLAY")
    icon:SetDrawLayer("OVERLAY",7)
    icon:SetPoint("CENTER",frame,"CENTER",0,5)
    icon:SetSize(24,32)
    icon:SetAtlas("UI-HUD-UnitFrame-Player-Rest-Flipbook")
    icon:SetDesaturated(true);icon:SetVertexColor(1,1,1,1)
    local anim=frame:CreateAnimationGroup()
    anim:SetLooping("REPEAT")
    if anim.SetToFinalAlpha then anim:SetToFinalAlpha(true)end
    local flip=anim:CreateAnimation("FlipBook")
    flip:SetTarget(icon);flip:SetDuration(1.875);flip:SetOrder(1)
    if flip.SetSmoothing then flip:SetSmoothing("NONE")end
    flip:SetFlipBookRows(7);flip:SetFlipBookColumns(6);flip:SetFlipBookFrames(42)
    flip:SetFlipBookFrameWidth(0);flip:SetFlipBookFrameHeight(0)
    frame:SetScript("OnShow",function()anim:Play()end)
    frame:SetScript("OnHide",function()anim:Stop()end)
    local r={native=native,frame=frame,alpha=native:GetAlpha()}
    record=r
    for _,method in ipairs({"Show","Hide","SetShown"})do
        hooksecurefunc(native,method,function()if not r.retired then Sync(r)end end)
    end
    hooksecurefunc(native,"SetAlpha",function(_,alpha)
        if r.syncing or r.retired then return end
        r.alpha=alpha;Sync(r)
    end)
    Sync(r)
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_UPDATE_RESTING","PLAYER_REGEN_ENABLED","ADDON_LOADED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,addon)
    if event=="ADDON_LOADED"and addon~="EllesmereUIUnitFrames"then return end
    ns.RefreshRestIndicator()
    if event=="PLAYER_LOGIN"or event=="PLAYER_ENTERING_WORLD"or event=="ADDON_LOADED"then
        -- Unit-frame spawning can be deferred until after the login dispatch.
        for _,delay in ipairs({0,1,3})do C_Timer.After(delay,ns.RefreshRestIndicator)end
    end
end)
