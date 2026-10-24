-- Texture-only integration: never changes secure micro-button actions or visibility.
local _,ns=...
local files={menu="menu",guild="guild",social="social",char="player",spell="spellbook",
    talent="talents",ach="achievements",quest="quests",lfg="LFG",pvp="encounter",
    housing="home",journal="journal",pet="collections",shop="store",help="help",
    profession="professions",legacy="legacy"}
local textures=setmetatable({},{__mode="k"})
local installed,discovered
local function PaintColor(icon,r)
    if r.coloring then return end
    local settings=ns.GetEnhancements()
    local custom=icon._edbWow~=true and icon._edbWow~="wow"
    local color
    if custom and settings.belMicroMenuIcons~=false and settings.belMicroMenuClassColor==true then
        local _,class=UnitClass("player")
        color=C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
            or(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    end
    r.coloring=true
    if color then icon:SetVertexColor(color.r,color.g,color.b,1);r.classApplied=true
    elseif r.classApplied then icon:SetVertexColor(unpack(r.nativeColor));r.classApplied=false end
    r.coloring=nil
end
local function Migrate(block)
    if block and block.type=="micromenu"and block.settings and block.settings.iconStyle=="rs"then
        block.settings.iconStyle="custom"
    end
end
local function Paint(icon,r)
    if r.painting then return end
    -- Native portrait painting can bypass Lua SetTexture hooks altogether.
    -- When EUI selected Blizzard art, leave the freshly painted icon alone.
    if icon._edbWow==true or icon._edbWow=="wow"then r.applied=false;PaintColor(icon,r);return end
    local enabled=ns.GetEnhancements().belMicroMenuIcons~=false
    r.painting=true
    if enabled then
        icon:SetTexture(r.path);r.applied=true
    elseif r.applied then
        if r.nativeAtlas and icon.SetAtlas then icon:SetAtlas(r.nativeAtlas)
        else icon:SetTexture(r.native)end
        r.applied=false
    end
    r.painting=nil
    PaintColor(icon,r)
end
local function Inspect(button,key)
    if not button or (button.IsForbidden and button:IsForbidden())then return end
    for _,region in ipairs({button:GetRegions()})do
        -- EUI marks only its actual icon with this style cache.
        local style=type(region._edbWow)
        if region.IsObjectType and region:IsObjectType("Texture")and(style=="string"or style=="boolean")then
            local r=textures[region]
            if not r then
                r={native=region:GetTexture(),nativeAtlas=region.GetAtlas and region:GetAtlas(),
                    nativeColor=region.GetVertexColor and {region:GetVertexColor()}or {1,1,1,1},
                    path="Interface\\AddOns\\BelToolbox\\Media\\MicroMenu\\"..files[key]..".png"}
                textures[region]=r
                hooksecurefunc(region,"SetVertexColor",function(_,red,green,blue,alpha)
                    if r.coloring then return end
                    r.nativeColor={red,green,blue,alpha or 1};r.classApplied=false;PaintColor(region,r)
                end)
                hooksecurefunc(region,"SetTexture",function(_,path)
                    if r.painting then return end
                    r.native=path;r.nativeAtlas=nil;r.applied=false;Paint(region,r)
                end)
                if region.SetAtlas then
                    hooksecurefunc(region,"SetAtlas",function(_,atlas)
                        if r.painting then return end
                        r.nativeAtlas=atlas;r.applied=false;Paint(region,r)
                    end)
                end
            end
            Paint(region,r)
        end
    end
end
local function InspectInstance(inst)
    if inst._dead then return end
    Migrate(inst.cfg)
    for key in pairs(files)do Inspect(_G["EWB_MM_"..inst.key.."_"..key],key)end
end
function ns.RefreshMicroMenuIcons()
    local EUI=_G.EllesmereUI
    local data=EUI and EUI._ModuleNS and EUI._ModuleNS.EllesmereUIDataBars
    if not data or not data.BlockFactories or type(data.BlockFactories.micromenu)~="function"then return end
    local profile=type(data.GetProfile)=="function"and data.GetProfile()
    for _,bar in pairs(profile and profile.bars or {})do
        for _,block in pairs(bar.blocks or {})do Migrate(block)end
    end
    if installed~=data then
        installed=data
        local factory=data.BlockFactories.micromenu
        data.BlockFactories.micromenu=function(block,...)
            Migrate(block)
            local inst=factory(block,...)
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
