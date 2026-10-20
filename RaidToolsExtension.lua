-- Version-guarded bridge to the installed EUI compact raid tools; EUI source files remain untouched.
local _,ns=...
local L=ns.L
local shell,resetButton,resetBG,queued,pending
local hooks=setmetatable({},{__mode="k"})
function ns.GetRaidExtensionSettings()
    local db=ns.GetSettings();db.raidToolsExtension=db.raidToolsExtension or {};return db.raidToolsExtension
end
local function Profile()
    local getter=_G._EUI_RaidTools_DB
    local db=type(getter)=="function"and getter()
    return db and db.profile and db.profile.raidTools
end
local function Compact()
    local p=Profile();return p and p.mode~="never"and p.showAs=="compact"
end
function ns.GetRaidCompactColor()
    local color=ns.GetRaidExtensionSettings().color or {0,0,0,.62}
    local values={}
    for i=1,4 do values[i]=math.max(0,math.min(1,tonumber(color[i])or(i==4 and .62 or 0)))end
    return unpack(values)
end
local markerIcons=setmetatable({},{__mode="k"})
function ns.GetRaidMarkerOpacity(hasTarget)
    local db=ns.GetRaidExtensionSettings()
    local value=tonumber(db[hasTarget and "markerAlphaTarget"or "markerAlphaNoTarget"])
    if value==nil then value=hasTarget and .9 or .3 end
    return math.max(0,math.min(1,value))
end
local function PaintMarkerOpacity()
    local active=Compact()and ns.GetRaidExtensionSettings().customMarkerOpacity~=false
    local target=false;if UnitExists then target=UnitExists("target")end
    if issecretvalue and issecretvalue(target)then return end
    local alpha=ns.GetRaidMarkerOpacity(target)
    for icon,record in pairs(markerIcons)do
        record.painting=true
        if active then
            -- Permission dimming remains authoritative; only the icon is changed, never its secure button.
            local base=record.button._baseAlpha or .8
            icon:SetAlpha(base<.8 and math.min(alpha,base)or alpha)
        elseif record.overridden then icon:SetAlpha(record.nativeAlpha)end
        record.painting=nil;record.overridden=active
    end
end
local function DiscoverMarkerIcons(frame,depth)
    if depth>4 or not frame.GetChildren then return end
    for _,child in ipairs({frame:GetChildren()})do
        if child._worldID and child.icon and not markerIcons[child.icon]then
            local icon=child.icon
            local record={button=child,nativeAlpha=icon:GetAlpha()}
            markerIcons[icon]=record
            hooksecurefunc(icon,"SetAlpha",function(_,alpha)
                if record.painting then return end
                record.nativeAlpha=alpha
                PaintMarkerOpacity()
            end)
        end
        DiscoverMarkerIcons(child,depth+1)
    end
end
local function Paint()
    local texture=shell and shell._bgOverlay
    local record=texture and hooks[texture]
    if not record then return end
    local custom=Compact()and ns.GetRaidExtensionSettings().customBackground~=false
    record.painting=true
    if custom then texture:SetColorTexture(ns.GetRaidCompactColor())
    elseif record.overridden then texture:SetColorTexture(unpack(record.original))end
    record.painting=nil;record.overridden=custom
    if resetBG then
        if custom then resetBG:SetColorTexture(ns.GetRaidCompactColor())
        else resetBG:SetColorTexture(unpack(record.original))end
    end
end
local function Queue()
    if queued then return end
    queued=true;C_Timer.After(0,function()queued=nil;ns.RefreshRaidToolsExtension()end)
end
local function Attach()
    local frame=_G.EllesmereUIRaidToolsGroup
    if not frame or not frame._bgOverlay then return end
    shell=frame
    if not hooks[frame]then
        hooks[frame]=true
        frame:HookScript("OnShow",Queue)
        local texture=frame._bgOverlay
        local record={original={0,0,0,.62}}
        hooks[texture]=record
        if texture.GetColorTexture then
            local r,g,b,a=texture:GetColorTexture()
            if type(r)=="number"and type(a)=="number"then record.original={r,g,b,a}end
        end
        hooksecurefunc(texture,"SetColorTexture",function(_,r,g,b,a)
            if record.painting then return end
            record.original={r,g,b,a or 1}
            Paint()
        end)
    end
    DiscoverMarkerIcons(frame,0)
    if not resetButton and Compact()then
        resetButton=CreateFrame("Button","BelToolboxEUIRaidReset",frame,"SecureActionButtonTemplate")
        resetButton:SetWidth(38)
        resetButton:SetPoint("TOPLEFT",frame,"TOPRIGHT",4,0)
        resetButton:SetPoint("BOTTOMLEFT",frame,"BOTTOMRIGHT",4,0)
        resetButton:RegisterForClicks("AnyUp","AnyDown")
        resetButton:SetAttribute("useOnKeyDown",false)
        resetButton:SetAttribute("type1","macro")
        resetButton:SetAttribute("macrotext1","/stopmacro [combat]\n/run ResetInstances()")
        resetBG=resetButton:CreateTexture(nil,"BACKGROUND");resetBG:SetAllPoints()
        resetButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        local font=resetButton:CreateFontString(nil,"OVERLAY")
        local EUI=_G.EllesmereUI
        local path=EUI and EUI.GetFontPath and EUI.GetFontPath("extras")or STANDARD_TEXT_FONT
        font:SetFont(path or "Fonts\\FRIZQT__.TTF",11,"")
        font:SetPoint("CENTER");font:SetText(L("Reset short"));font:SetAlpha(.8)
        ns.Toolbars.Tooltip(resetButton,L("Reset instances"),{
            "|cffffffff"..L("Left click:").."|r |cff5ed7ff"..L("Reset instances").."|r",
            L("Cannot reset instances in combat. Game reset restrictions apply."),
        })
        resetButton:HookScript("OnEnter",function()font:SetAlpha(1)end)
        resetButton:HookScript("OnLeave",function()font:SetAlpha(.8)end)
    end
end
function ns.RefreshRaidToolsExtension()
    if InCombatLockdown()then pending=true;return end
    pending=nil;Attach();Paint();PaintMarkerOpacity()
    if resetButton then resetButton:SetShown(Compact()and ns.GetRaidExtensionSettings().resetButton~=false)end
end
if type(_G._EUI_RaidTools_Apply)=="function"then hooksecurefunc("_EUI_RaidTools_Apply",Queue)end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","GROUP_ROSTER_UPDATE","PLAYER_TARGET_CHANGED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_TARGET_CHANGED"then PaintMarkerOpacity();return end
    if event~="PLAYER_REGEN_ENABLED"or pending then Queue()end
end)

