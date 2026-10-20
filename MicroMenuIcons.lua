-- Texture-only integration: never changes secure micro-button actions or visibility.
local _,ns=...
local files={menu="menu",guild="guild",social="social",char="player",spell="spellbook",
    talent="talents",ach="achievements",quest="quests",lfg="LFG",pvp="encounter",
    housing="home",journal="journal",pet="collections",shop="store",help="help",
    profession="professions",legacy="legacy"}
local textures=setmetatable({},{__mode="k"})
local installed,discovered
local function Paint(icon,r)
    if r.painting then return end
    local enabled=ns.GetEnhancements().belMicroMenuIcons~=false and icon._edbWow~="wow"
    r.painting=true
    icon:SetTexture(enabled and r.path or r.native)
    r.painting=nil
end
local function Inspect(button,key)
    if not button or (button.IsForbidden and button:IsForbidden())then return end
    for _,region in ipairs({button:GetRegions()})do
        -- EUI marks only its actual icon with this style cache.
        if region.IsObjectType and region:IsObjectType("Texture")and type(region._edbWow)=="string"then
            local r=textures[region]
            if not r then
                r={native=region:GetTexture(),path="Interface\\AddOns\\BelToolbox\\Media\\MicroMenu\\"..files[key]..".png"}
                textures[region]=r
                hooksecurefunc(region,"SetTexture",function(_,path)
                    if r.painting then return end
                    r.native=path;Paint(region,r)
                end)
            end
            Paint(region,r)
        end
    end
end
local function InspectInstance(inst)
    if inst._dead then return end
    for key in pairs(files)do Inspect(_G["EWB_MM_"..inst.key.."_"..key],key)end
end
function ns.RefreshMicroMenuIcons()
    local EUI=_G.EllesmereUI
    local data=EUI and EUI._ModuleNS and EUI._ModuleNS.EllesmereUIDataBars
    if not data or not data.BlockFactories or type(data.BlockFactories.micromenu)~="function"then return end
    if installed~=data then
        installed=data
        local factory=data.BlockFactories.micromenu
        data.BlockFactories.micromenu=function(...)
            local inst=factory(...)
            if inst and inst.key then
                for _,method in ipairs({"Refresh","Enable"})do
                    if type(inst[method])=="function"then hooksecurefunc(inst,method,function()InspectInstance(inst)end)end
                end
                InspectInstance(inst)
            end
            return inst
        end
    end
    -- Also discover instances already created before the extension loaded.
    if discovered~=data and type(EnumerateFrames)=="function"then
        local frame=EnumerateFrames()
        while frame do
            if not(frame.IsForbidden and frame:IsForbidden())then
                local name=frame:GetName()
                local key=type(name)=="string"and name:match("^EWB_MM_.+_([%a]+)$")
                if key and files[key]then Inspect(frame,key)end
            end
            frame=EnumerateFrames(frame)
        end
        discovered=data
    end
    for icon,r in pairs(textures)do Paint(icon,r)end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,addon)
    if event=="ADDON_LOADED"and addon~="EllesmereUIDataBars"then return end
    ns.RefreshMicroMenuIcons()
    C_Timer.After(0,ns.RefreshMicroMenuIcons)
end)
ns.RefreshMicroMenuIcons()
