-- Corner resizing shares EUI Shifter's saved scale/position, avoiding competing layout owners.
local _,ns=...
local map,grip,positioner,gesture
local controller=CreateFrame("Frame")
local wait=0
local function Windowed()
    return map and map:IsShown()and not(map.IsMaximized and map:IsMaximized())
end
local function Enabled()
    return ns.GetEnhancements().mapCornerResize~=false and ns.IsWindowMovementEnabled()
end
local function Cursor()
    local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
    return x/scale,y/scale
end
local function Stop()
    gesture=nil
end
local function Sync()
    if grip and not InCombatLockdown()then
        local shown=Enabled()and Windowed()
        grip:SetAttribute("bel-visible",shown);grip:SetShown(shown)
    end
    if gesture and (not Enabled()or not Windowed()or InCombatLockdown())then Stop()end
end
local function Resize()
    local g=gesture
    if not g then return end
    if InCombatLockdown()or not Windowed()or not Enabled()or not IsMouseButtonDown("LeftButton")then Stop();return end
    local cx,cy=Cursor()
    local delta=((cx-g.cx)*g.width+(g.cy-cy)*g.height)/(g.width*g.width+g.height*g.height)
    local maxScale=math.min(2,(UIParent:GetWidth()-g.x)/g.width,(UIParent:GetHeight()-g.top)/g.height)
    local scale=math.max(.5,math.min(math.max(.5,maxScale),g.scale+delta))
    if math.abs(scale-map:GetScale())<.001 then return end
    local x,y=g.x/(scale*g.ratio),-g.top/(scale*g.ratio)
    EllesmereUIDB=EllesmereUIDB or {}
    EllesmereUIDB.shifterScales=EllesmereUIDB.shifterScales or {}
    EllesmereUIDB.shifterPositions=EllesmereUIDB.shifterPositions or {}
    -- Write the shared destination first: Shifter's guarded hooks see the same destination.
    EllesmereUIDB.shifterScales.WorldMapFrame=scale
    EllesmereUIDB.shifterPositions.WorldMapFrame={point="TOPLEFT",relPoint="TOPLEFT",x=x,y=y}
    positioner:SetFrameRef("map",map)
    positioner:SetAttribute("scale",scale);positioner:SetAttribute("x",x);positioner:SetAttribute("y",y)
    positioner:Execute([[
        local f=self:GetFrameRef("map")
        if f then
            f:SetScale(self:GetAttribute("scale"))
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT",f:GetParent(),"TOPLEFT",self:GetAttribute("x"),self:GetAttribute("y"))
        end
    ]])
end
local function Start(_,mouse)
    if mouse~="LeftButton"or not Enabled()or not Windowed()or InCombatLockdown()then return end
    local scale=map:GetScale()
    local ratio=map:GetEffectiveScale()/scale/UIParent:GetEffectiveScale()
    local width,height=map:GetWidth()*ratio,map:GetHeight()*ratio
    if width<=0 or height<=0 then return end
    local x=map:GetLeft()*scale*ratio
    local top=UIParent:GetHeight()-map:GetTop()*scale*ratio
    x=math.max(0,math.min(x,UIParent:GetWidth()-width*.5))
    top=math.max(0,math.min(top,UIParent:GetHeight()-height*.5))
    local cx,cy=Cursor()
    gesture={scale=scale,ratio=ratio,width=width,height=height,x=x,top=top,cx=cx,cy=cy}
end
function ns.RefreshMapResize()
    if InCombatLockdown()then return end
    if not map then
        map=_G.WorldMapFrame
        if not map then return end
        positioner=CreateFrame("Frame",nil,UIParent,"SecureHandlerBaseTemplate")
        grip=CreateFrame("Button","BelToolboxMapResizeHandle",map,"SecureHandlerStateTemplate")
        grip:SetSize(26,26);grip:SetPoint("BOTTOMRIGHT",map,"BOTTOMRIGHT",1,-1)
        grip:SetFrameLevel(map:GetFrameLevel()+50)
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        ns.Toolbars.Tooltip(grip,ns.L("Resize map window"),ns.L("Drag the bottom-right corner to resize. Windowed mode only. The size is saved with EUI window settings."))
        grip:SetAttribute("_onstate-combat",[[
            if newstate=="combat" then self:Hide()
            elseif self:GetAttribute("bel-visible") then self:Show() end
        ]])
        RegisterStateDriver(grip,"combat","[combat] combat; peace")
        grip:SetScript("OnMouseDown",Start);grip:SetScript("OnMouseUp",Stop)
        grip:SetScript("OnHide",Stop)
        local function Arm()
            wait=0;Sync()
            controller:SetScript("OnUpdate",function(_,dt)
                if gesture then Resize()end
                wait=wait+dt
                if wait>=.1 then wait=0;Sync()end
            end)
        end
        map:HookScript("OnShow",Arm)
        map:HookScript("OnHide",function()Stop();if not InCombatLockdown()then grip:Hide()end;controller:SetScript("OnUpdate",nil)end)
        if map:IsShown()then Arm()end
    end
    Sync()
end
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"})do controller:RegisterEvent(event)end
controller:SetScript("OnEvent",function(_,event,addon)
    if event=="PLAYER_REGEN_DISABLED"then Stop();return end
    if event=="ADDON_LOADED"and addon~="Blizzard_WorldMap"then return end
    ns.RefreshMapResize()
end)

