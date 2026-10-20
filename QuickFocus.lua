local _,ns=...
local button,marker,dirty
local frames=setmetatable({},{__mode="k"})
local candidates=setmetatable({},{__mode="k"})
local scanNeeded=true
local activeModifier,activeMouse,activeText
function ns.GetFocusSettings()
    local db=ns.GetSettings();db.quickFocus=db.quickFocus or {};return db.quickFocus
end
local function Restore()
    for frame,record in pairs(frames)do
        for key,value in pairs(record.applied)do
            if frame:GetAttribute(key)==value then frame:SetAttribute(key,record.original[key])end
        end
    end
    wipe(frames)
end
local function ApplyFrame(frame,modifier,mouse,text)
    if not frame or frames[frame] then return end
    if frame==button or frame==marker then return end
    if frame.IsForbidden and frame:IsForbidden()then return end
    if not frame.GetAttribute or not frame.SetAttribute or not frame.RegisterForClicks then return end
    local unit=frame:GetAttribute("unit")
    if (issecretvalue and issecretvalue(unit))or type(unit)~="string"or unit==""then return end
    local clickType=frame:GetAttribute("type1")or frame:GetAttribute("type")
    if clickType~="target"and not(ClickCastFrames and ClickCastFrames[frame])then return end
    local record={original={},applied={}}
    -- A click-casting conflict is limited to the chosen modifier/button; originals are restored on disable.
    for key,value in pairs({[modifier.."-type"..mouse]="macro",[modifier.."-macrotext"..mouse]=text})do
        record.original[key]=frame:GetAttribute(key);record.applied[key]=value;frame:SetAttribute(key,value)
    end
    frames[frame]=record
    candidates[frame]=true
end
local function AddPlate(plate)
    if not plate or not activeModifier then return end
    ApplyFrame(plate,activeModifier,activeMouse,activeText)
    ApplyFrame(plate.UnitFrame or plate.unitFrame,activeModifier,activeMouse,activeText)
end
function ns.RefreshQuickFocus()
    if InCombatLockdown()then dirty=true;return end
    dirty=nil
    if not button then
        button=CreateFrame("Button","BelToolboxQuickFocus",UIParent,"SecureActionButtonTemplate")
        button:RegisterForClicks("AnyUp","AnyDown");button:SetAttribute("useOnKeyDown",false)
        marker=CreateFrame("Button","BelToolboxFocusMarker",UIParent,"SecureActionButtonTemplate")
        marker:RegisterForClicks("AnyDown");marker:SetAttribute("useOnKeyDown",true)
    end
    ClearOverrideBindings(button);Restore()
    activeModifier,activeMouse,activeText=nil,nil,nil
    local db=ns.GetFocusSettings()
    if db.enabled==false then button:SetAttribute("type",nil);marker:SetAttribute("type",nil);return end
    local id=tonumber(db.marker)or 3
    id=math.floor(math.max(1,math.min(8,id)))
    marker:SetAttribute("type","raidtarget");marker:SetAttribute("unit","focus")
    marker:SetAttribute("marker",id);marker:SetAttribute("action",db.overwrite and "set"or "set-unmarked")
    local text="/clearfocus [@mouseover,noexists]\n/focus [@mouseover,exists][@target,exists]"
    if db.markEnabled~=false then text=text.."\n/click BelToolboxFocusMarker LeftButton true"end
    button:SetAttribute("type","macro");button:SetAttribute("macrotext",text)
    local valid={['SHIFT-BUTTON1']=true,['CTRL-BUTTON1']=true,['ALT-BUTTON1']=true,['ALT-F']=true,['SHIFT-F']=true}
    local binding=valid[db.binding]and db.binding or "SHIFT-BUTTON1"
    SetOverrideBindingClick(button,true,binding,"BelToolboxQuickFocus","LeftButton")
    local modifier,mouse=binding:match("^(%u+)%-BUTTON(%d)$")
    if modifier then
        activeModifier,activeMouse,activeText=modifier:lower(),mouse,text
        if scanNeeded and EnumerateFrames then
            local frame=EnumerateFrames()
            while frame do
                ApplyFrame(frame,activeModifier,mouse,text)
                frame=EnumerateFrames(frame)
            end
            scanNeeded=nil
        else
            for frame in pairs(candidates)do ApplyFrame(frame,activeModifier,mouse,text)end
        end
        for frame in pairs(ClickCastFrames or {})do ApplyFrame(frame,activeModifier,mouse,text)end
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _,plate in ipairs(C_NamePlate.GetNamePlates()or {})do AddPlate(plate)end
        end
    end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","ADDON_LOADED","NAME_PLATE_UNIT_ADDED","GROUP_ROSTER_UPDATE"})do events:RegisterEvent(event)end
local queued,loggedIn
local function Queue()
    if queued then return end
    queued=true;C_Timer.After(0,function()queued=nil;ns.RefreshQuickFocus()end)
end
events:SetScript("OnEvent",function(_,event,value)
    if event=="PLAYER_LOGIN"then loggedIn=true end
    if not loggedIn then return end
    if event=="NAME_PLATE_UNIT_ADDED"then
        if InCombatLockdown()then dirty=true
        elseif C_NamePlate and C_NamePlate.GetNamePlateForUnit then AddPlate(C_NamePlate.GetNamePlateForUnit(value))end
        return
    elseif event=="ADDON_LOADED"then
        local relevant={EllesmereUIUnitFrames=true,EllesmereUIRaidFrames=true,Blizzard_CompactRaidFrames=true,Blizzard_NamePlates=true}
        if not relevant[value]then return end
        scanNeeded=true;Queue()
    elseif event=="PLAYER_REGEN_ENABLED"then if dirty then Queue()end
    else Queue()end
end)
