-- Native quest-object sparkles require both the loot effect and disabled outlines.
local _,ns=...
local wanted={
    outlineModeShowLootEffectWhenDisabled="1",
    graphicsOutlineMode="0", OutlineEngineMode="0",
    raidGraphicsOutlineMode="0", RAIDOutlineEngineMode="0",
}
local applying,queued
local function Read(name)
    local get=_G.C_CVar and C_CVar.GetCVar or _G.GetCVar
    if type(get)~="function"then return end
    local ok,value=pcall(get,name)
    if ok and value~=nil then return tostring(value)end
end
local function Write(name,value)
    local set=_G.C_CVar and C_CVar.SetCVar or _G.SetCVar
    if type(set)~="function"then return false end
    local ok=pcall(set,name,value)
    return ok and Read(name)==value
end
function ns.RefreshLootSparkles()
    if applying or InCombatLockdown()then return end
    local db=ns.GetEnhancements()
    -- Preserve the baseline recorded by releases which managed only the loot flag.
    if db.lootSparklesOriginal~=nil then
        db.lootSparklesCVars=db.lootSparklesCVars or {}
        if db.lootSparklesCVars.outlineModeShowLootEffectWhenDisabled==nil then
            db.lootSparklesCVars.outlineModeShowLootEffectWhenDisabled=tostring(db.lootSparklesOriginal)
        end
        db.lootSparklesOriginal=nil
    end
    applying=true
    local originals=db.lootSparklesCVars or {}
    for name,value in pairs(wanted)do
        local current=Read(name)
        if db.lootSparkles~=false then
            if current~=nil then
                if originals[name]==nil then originals[name]=current end
                if current~=value then Write(name,value)end
            end
        elseif originals[name]~=nil and current~=nil then
            local original=tostring(originals[name])
            -- Respect later external choices; retain failed restorations for retry.
            if current~=value or current==original or Write(name,original)then originals[name]=nil end
        end
    end
    db.lootSparklesCVars=next(originals)and originals or nil
    applying=nil
end
local watched={graphicsquality=true,raidgraphicsquality=true}
for name in pairs(wanted)do watched[name:lower()]=true end
local function Schedule()
    if queued then return end
    queued=true
    C_Timer.After(1,function()queued=nil;ns.RefreshLootSparkles()end)
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","CVAR_UPDATE"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,name)
    if applying then return end
    if event=="CVAR_UPDATE"then
        if ns.GetEnhancements().lootSparkles==false or type(name)~="string"or not watched[name:lower()]then return end
        Schedule()
    else
        ns.RefreshLootSparkles()
        if event=="PLAYER_LOGIN"then C_Timer.After(5,ns.RefreshLootSparkles)end
    end
end)
