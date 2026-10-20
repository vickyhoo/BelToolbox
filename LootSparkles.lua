-- Enable the client's native loot sparkle effect without changing character outlines.
local _,ns=...
local cvar="outlineModeShowLootEffectWhenDisabled"
local applying,queued
local function Read()
    local get=_G.C_CVar and C_CVar.GetCVar or _G.GetCVar
    if type(get)~="function"then return end
    local ok,value=pcall(get,cvar)
    if ok and value~=nil then return tostring(value)end
end
local function Write(value)
    local set=_G.C_CVar and C_CVar.SetCVar or _G.SetCVar
    if type(set)~="function"then return false end
    local ok=pcall(set,cvar,value)
    return ok and Read()==value
end
function ns.RefreshLootSparkles()
    if applying or InCombatLockdown()then return end
    local db=ns.GetEnhancements()
    local current=Read()
    if current==nil then return end
    applying=true
    if db.lootSparkles~=false then
        if db.lootSparklesOriginal==nil then db.lootSparklesOriginal=current end
        if current~="1"then Write("1")end
    elseif db.lootSparklesOriginal~=nil then
        local original=tostring(db.lootSparklesOriginal)
        -- Preserve a later external change; retry an unsuccessful restoration next refresh.
        if current~="1"or current==original or Write(original)then db.lootSparklesOriginal=nil end
    end
    applying=nil
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","CVAR_UPDATE"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,name)
    if applying then return end
    if event=="CVAR_UPDATE"then
        if ns.GetEnhancements().lootSparkles==false or type(name)~="string"then return end
        name=name:lower()
        if name~=cvar:lower()and name~="graphicsquality"and name~="raidgraphicsquality"then return end
        if queued then return end
        queued=true
        C_Timer.After(0,function()queued=nil;ns.RefreshLootSparkles()end)
    else ns.RefreshLootSparkles()end
end)
