-- Reuse the installed EUI window controller: it provides secure movement for protected panels.
local _,ns=...
function ns.GetEnhancements()
    local db=ns.GetSettings();db.enhancements=db.enhancements or {};return db.enhancements
end
function ns.IsWindowMovementEnabled()
    return _G.EllesmereUIDB and EllesmereUIDB.shifterEnabled==true or false
end
function ns.SetWindowMovement(value)
    ns.GetEnhancements().windowMovement=value
    if InCombatLockdown()then return end
    local EUI=_G.EllesmereUI
    if not EUI or not EUI._InitShifter then return end
    EllesmereUIDB=EllesmereUIDB or {};EllesmereUIDB.shifterEnabled=value
    if value then EUI._InitShifter()
    elseif EUI._ShutdownShifter then EUI._ShutdownShifter()end
    if ns.RefreshMapResize then ns.RefreshMapResize()end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED"})do events:RegisterEvent(event)end
local pending
local apply=ns.SetWindowMovement
ns.SetWindowMovement=function(value)
    if InCombatLockdown()then pending=value;ns.GetEnhancements().windowMovement=value;return end
    pending=nil;apply(value)
end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN"then
        if ns.GetEnhancements().windowMovement==nil then ns.SetWindowMovement(true)end
    elseif pending~=nil then ns.SetWindowMovement(pending)end
end)
