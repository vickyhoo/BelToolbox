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
            visible[#visible+1]=Button(d.key,L(d.title),L(d.label),d.color,action,tip)
        end
    end
    T.Layout(root,visible,"chatBar");T.Position(root,"chatBar",DefaultPosition)
    root:SetShown(db.enabled~=false);root.RegisterBelMover()

end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","CHANNEL_UI_UPDATE","CHAT_MSG_CHANNEL_NOTICE","PLAYER_REGEN_ENABLED"})do events:RegisterEvent(event)end
local queued
-- Channel notices can arrive in bursts; refresh the toolbar once per frame.
events:SetScript("OnEvent",function()
    if queued then return end
    queued=true
    C_Timer.After(0,function()queued=nil;ns.RefreshChatBar()end)
end)

