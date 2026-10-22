local _, ns = ...
local L,T=ns.L,ns.Toolbars
local root,buttons
local function Settings()return T.Settings("chatBar")end
local function ChatFrame()return SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME or ChatFrame1 end
local function Open(text)
    if ChatFrame_OpenChat then ChatFrame_OpenChat(text or "",ChatFrame())end
end
local function Notice(key)
    print(L("Bel Toolbox")..": "..L(key))
end
local function Load(name)
    if InCombatLockdown()then Notice("This action is unavailable in combat.");return false end
    if C_AddOns and C_AddOns.LoadAddOn then return C_AddOns.LoadAddOn(name)end
    return LoadAddOn and LoadAddOn(name)
end
local function Macro()
    if InCombatLockdown()then Notice("This action is unavailable in combat.");return end
    if not MacroFrame then Load("Blizzard_MacroUI")end
    if MacroFrame and MacroFrame:IsShown()then MacroFrame:Hide()
    elseif ShowMacroFrame then ShowMacroFrame()elseif MacroFrame then MacroFrame:Show()end
end
local function Journal(right)
    if InCombatLockdown()then Notice("This action is unavailable in combat.");return end
    if right then
        if ToggleLootHistoryFrame then ToggleLootHistoryFrame()
        elseif SlashCmdList.LOOT then SlashCmdList.LOOT("")end
        return
    end
    Load("DungeonsForever")
    if _G.DF_NS and type(_G.DF_NS.Open)=="function"then _G.DF_NS.Open()
    elseif SlashCmdList.DUNGEONSFOREVER then SlashCmdList.DUNGEONSFOREVER("")
    else Notice("DungeonsForever is not available.")end
end
local function GoldLedger()
    if InCombatLockdown()then Notice("This action is unavailable in combat.");return end
    for _,entry in ipairs({{"BGLite","BIAOGE"},{"BGNext","BGNEXT"},{"BiaoGe","BIAOGE"},{"BGLite_Skye","BIAOGE"},{"BiaoGeX","BIAOGE"}})do
        if Load(entry[1])and SlashCmdList[entry[2]]then SlashCmdList[entry[2]]("");return end
    end
    Notice("Install a supported gold ledger addon to use this shortcut.")
end
local definitions={
    {key="say",label="Say short",title="Say",chat="/say ",color={1,1,1}},
    {key="yell",label="Yell short",title="Yell",chat="/yell ",color={1,.2,.2}},
    {key="guild",label="Guild short",title="Guild",chat="/g ",right="/o ",color={.2,1,.2},tip="Right-click: officer chat."},
    {key="party",label="Party short",title="Party",chat="/p ",color={.3,.8,1}},
    {key="raid",label="Raid short",title="Raid",chat="/raid ",right="/rw ",color={1,.5,.1},raid=true,tip="Right-click: raid warning."},
    {key="general",label="General short",title="General channel",channel="General"},
    {key="trade",label="Trade short",title="Trade channel",channel="Trade"},
    {key="lfg",label="LookingForGroup short",title="LookingForGroup channel",channel="LookingForGroup",color={.1,1,.1}},
    {key="world",label="World short",title="World channel",channel="World",color={.1,1,.1}},
    {key="roll",label="Roll short",title="Roll 1-100",run=function()if RandomRoll then RandomRoll(1,100)end end,color={.8,.4,1}},
    {key="macro",label="Macros short",title="Macros",run=Macro,color={.4,.8,1}},
    {key="combatlog",label="Log short",title="Combat logging",run=function()
        if SlashCmdList.COMBATLOG then SlashCmdList.COMBATLOG("")
        elseif LoggingCombat then local enabled=LoggingCombat();LoggingCombat(not enabled);Notice(enabled and "Combat logging disabled."or "Combat logging enabled.")end
    end,color={.3,1,.4}},
    {key="journal",label="Journal short",title="Dungeon journal",run=function(_,right)Journal(right)end,tip="Left-click: DungeonsForever. Right-click: loot history.",color={.4,.8,1}},
    {key="goldLedger",label="Gold short",title="Gold ledger",run=GoldLedger,color={1,.85,.1}},
}
ns.ChatBarButtons=definitions
local function FindChannel(key)
    local list={GetChannelList()}
    local search=L(key.." channel"):lower()
    for i=1,#list,3 do
        local id,name,disabled=list[i],list[i+1],list[i+2]
        if type(id)=="number"and type(name)=="string"and name:lower():find(search,1,true)then
            return id,name,disabled
        end
    end
end
local function Channel(key,right)
    local id,name,disabled=FindChannel(key)
    name=name or L(key=="World"and "World join channel"or key.." channel")
    if right then
        if id then
            if LeaveChannelByName then LeaveChannelByName(name)end
        else
            local chat=ChatFrame()
            if JoinPermanentChannel then JoinPermanentChannel(name,nil,chat and chat:GetID(),1)
            elseif JoinChannelByName then JoinChannelByName(name)end
            if ChatFrame_AddChannel and chat then ChatFrame_AddChannel(chat,name)end
        end
    elseif id and not disabled then Open("/"..id.." ")
    else print(L("Bel Toolbox")..": "..L("You are not in %s. Right-click to join.",name))end
end
ns.FindChatChannel=FindChannel
local chatTypes={say="SAY",yell="YELL",guild="GUILD",party="PARTY",raid="RAID"}
local function Color(data)
    local key=chatTypes[data.key]
    if data.channel then
        local id=FindChannel(data.channel)
        if id then key="CHANNEL"..id end
    end
    local info=key and ChatTypeInfo and ChatTypeInfo[key]
    if info and info.r and info.g and info.b then return info.r,info.g,info.b end
    return unpack(data.color or {.8,.65,.45})
end
function ns.GetChatBarStyle()
    local style=Settings().style
    return(style=="blocks"or style=="labeled")and style or "text"
end
function ns.GetChatButtonColor(key,kind)
    local saved=Settings().colors
    local custom=saved and saved[key]and saved[key][kind]
    if custom then return custom[1],custom[2],custom[3]end
    if kind=="text"and ns.GetChatBarStyle()~="text"then return 1,1,1 end
    for _,data in ipairs(definitions)do if data.key==key then return Color(data)end end
    return 1,1,1
end
function ns.SetChatButtonColor(key,kind,r,g,b)
    local db=Settings();db.colors=db.colors or {};db.colors[key]=db.colors[key]or {}
    db.colors[key][kind]={math.max(0,math.min(1,r)),math.max(0,math.min(1,g)),math.max(0,math.min(1,b))}
    ns.RefreshChatBar()
end
function ns.ResetChatButtonColors(key)
    local db=Settings();if db.colors then db.colors[key]=nil end
    ns.RefreshChatBar()
end
local function Style(button,data)
    local style=ns.GetChatBarStyle()
    local colored=style~="text"
    local r,g,b=ns.GetChatButtonColor(data.key,"block")
    if not button.block then
        button.border=button:CreateTexture(nil,"BACKGROUND")
        button.border:SetAllPoints()
        button.border:SetColorTexture(0,0,0,.9)
        button.block=button:CreateTexture(nil,"ARTWORK")
        button.block:SetPoint("TOPLEFT",1,-1);button.block:SetPoint("BOTTOMRIGHT",-1,1)
        button.shine=button:CreateTexture(nil,"ARTWORK",nil,1)
        button.shine:SetPoint("TOPLEFT",1,-1);button.shine:SetPoint("TOPRIGHT",-1,-1)
        button.shine:SetColorTexture(1,1,1,.16)
    end
    button.block:SetColorTexture(r,g,b,1)
    button.border:SetShown(colored);button.block:SetShown(colored);button.shine:SetShown(colored)
    button.label:SetShown(style~="blocks")
    button.label:SetTextColor(ns.GetChatButtonColor(data.key,"text"))
end
local function Layout(visible)
    local db=Settings();local style=ns.GetChatBarStyle();local size=T.Size("chatBar")
    local colored=style~="text"
    local width=colored and math.max(24,math.min(100,tonumber(db.blockWidth)or 48))or size
    local height=style=="blocks"and math.max(10,math.floor(size*.6))or size
    local gap=math.max(0,math.min(16,tonumber(db.spacing)or(colored and 6 or 2)))
    local vertical=db.vertical==true;local offset=0
    for _,button in ipairs(visible)do
        button:ClearAllPoints();button:SetSize(width,height)
        button.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",math.max(12,size-6),"OUTLINE")
        button.shine:SetHeight(math.max(2,math.floor(height*.35)))
        if vertical then button:SetPoint("TOPLEFT",root,"TOPLEFT",0,-offset)
        else button:SetPoint("TOPLEFT",root,"TOPLEFT",offset,0)end
        offset=offset+(vertical and height or width)+gap;button:Show()
    end
    root:SetSize(vertical and width or math.max(width,offset-gap),vertical and math.max(height,offset-gap)or height)
end
local function DefaultPosition()
    local chat=ChatFrame1
    if chat and chat:GetLeft()and chat:GetTop()then
        local scale=chat:GetEffectiveScale()/UIParent:GetEffectiveScale()
        return {point="BOTTOMLEFT",relPoint="BOTTOMLEFT",x=chat:GetLeft()*scale,y=chat:GetTop()*scale+28}
    end
    return {point="BOTTOMLEFT",relPoint="BOTTOMLEFT",x=30,y=260}
end
local function Button(key,title,label,color,action,tip)
    local b=buttons[key]
    if not b then b=T.Button(root,nil,false,label);buttons[key]=b;b:RegisterForClicks("LeftButtonUp","RightButtonUp")end
    b.label:SetText(label)
    b.label:SetTextColor(unpack(color or {.8,.65,.45}))
    b:SetScript("OnClick",function(self,mouse)
        action(self,mouse=="RightButton")
    end)
    T.Tooltip(b,title,tip and L(tip))
    return b
end
function ns.RefreshChatBar()
    if not root then
        root=CreateFrame("Frame","BelToolboxChatBar",UIParent)
        root:SetFrameStrata("LOW");buttons={}
        T.Mover(root,"chatBar","Chat Bar",951,DefaultPosition)
    end
    for _,b in pairs(buttons)do b:Hide()end
    local db=Settings();db.buttons=db.buttons or {}
    local visible={}
    for _,d in ipairs(definitions)do
        local channelsEnabled=not d.channel or db.buttons.channels~=false
        if db.buttons[d.key]~=false and channelsEnabled and(not d.raid or IsInRaid())then
            local action=d.run or function(_,right)
                if d.channel then Channel(d.channel,right)else Open(right and d.right or d.chat)end
            end
            local tip=d.channel and "Left-click: chat. Right-click: join or leave this channel."or d.tip
            local button=Button(d.key,L(d.title),L(d.label),d.color,action,tip)
            Style(button,d);visible[#visible+1]=button
        end
    end
    Layout(visible);T.Position(root,"chatBar",DefaultPosition)
    root:SetShown(db.enabled~=false);root.RegisterBelMover()

end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","CHANNEL_UI_UPDATE","CHAT_MSG_CHANNEL_NOTICE","UPDATE_CHAT_COLOR","PLAYER_REGEN_ENABLED"})do events:RegisterEvent(event)end
local queued
-- Channel notices can arrive in bursts; refresh the toolbar once per frame.
events:SetScript("OnEvent",function()
    if queued then return end
    queued=true
    C_Timer.After(0,function()queued=nil;ns.RefreshChatBar()end)
end)

