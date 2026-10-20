local _, ns = ...
local L = ns.L
local launcher, favoriteButton, pendingRecipient, hookedSend, hookedMailAPI
local originalInsets
local contactMeta = {}
local sendPanelHooked, lastRosterRequest
local function RequestSocial()
    local now=time()
    if lastRosterRequest and now-lastRosterRequest<2 then return end
    lastRosterRequest=now
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
    elseif GuildRoster then GuildRoster() end
    if C_FriendList and C_FriendList.ShowFriends then C_FriendList.ShowFriends()
    elseif ShowFriends then ShowFriends() end
end
local function Contacts()
    local db=ns.GetSettings();db.mailContacts=db.mailContacts or {};return db.mailContacts
end
local function Realm()
    local normalized=GetNormalizedRealmName and GetNormalizedRealmName()
    if type(normalized)=="string" and normalized~="" then return normalized:gsub("%s","") end
    local realm=GetRealmName and GetRealmName()
    if type(realm)=="string" and realm~="" then return realm:gsub("%s","") end
    return "Forever"
end
local function IsForever() return EllesmereUI and EllesmereUI.IS_FOREVER == true end
local function NormalizeRecipient(text)
    if (issecretvalue and issecretvalue(text)) or type(text)~="string" then return end
    text=text:match("^%s*(.-)%s*$")
    if text==""or #text>120 or text:find("[|<>%c]")then return end
    if IsForever() then
        local first,suffix=text:match("^(.-)%s*%-+%s*(.-)$")
        if first then
            local record=ns.GetInventoryStore().characters[text]
            if record and record.realm==suffix and suffix~=Realm()then text=first.." "..suffix
            else text=first end
        end
        text=text:gsub("%s+"," "):match("^%s*(.-)%s*$")
        if text==""then return end
        return text
    end
    local name,realm=text:match("^([^%-]+)%-(.+)$")
    name=(name or text):match("^%s*(.-)%s*$");realm=(realm or Realm()):gsub("%s","")
    if name:find("%s")or realm=="" then return end
    return name.."-"..realm
end
local function PlayerKey()
    if not IsForever() then return NormalizeRecipient(UnitName("player")) end
    local name,second
    if UnitFullName then name,second=UnitFullName("player")end
    name=name or UnitName("player")
    if IsForever() and name and second and second~=""and second~=Realm()and not name:find(second,1,true)then name=name.." "..second end
    return NormalizeRecipient(name)
end
local function RecipientText(key)
    if IsForever() then return key end
    local name,realm=key:match("^([^%-]+)%-(.+)$")
    return realm==Realm()and name or key
end
local function IsFavorite(key)
    if not key then return false end
    for name in pairs(Contacts())do if NormalizeRecipient(name)==key then return true end end
    return false
end
local function ColorName(key)
    local record=contactMeta[key] or ns.GetInventoryStore().characters[key]
    if not record then
        for raw,data in pairs(ns.GetInventoryStore().characters)do if NormalizeRecipient(raw)==key then record=data;break end end
    end
    local r,g,b=ns.GetCharacterColor(record)
    return string.format("|cff%02x%02x%02x%s|r",math.floor(r*255+0.5),math.floor(g*255+0.5),math.floor(b*255+0.5),key)
end
local function Recent()
    local db=ns.GetSettings();db.mailRecent=db.mailRecent or {};return db.mailRecent
end
local function RememberSent(name)
    local key=NormalizeRecipient(name)
    if not key then return end
    local recent=Recent()
    for i=#recent,1,-1 do if NormalizeRecipient(recent[i].name)==key then table.remove(recent,i)end end
    table.insert(recent,1,{name=key,sentAt=time()})
    while #recent>20 do table.remove(recent)end
end
local function Lists()
    local result={alts={},favorites={},recent={}}
    local player=UnitName("player");local myself=NormalizeRecipient(player)
    for key,record in pairs(ns.GetInventoryStore().characters)do
        local canonical=NormalizeRecipient(key)
        if canonical and canonical~=myself and record.faction==UnitFactionGroup("player")then
            result.alts[#result.alts+1]=canonical
        end
    end
    local seen={}
    for name in pairs(Contacts())do local key=NormalizeRecipient(name);if key and not seen[key]then result.favorites[#result.favorites+1]=key;seen[key]=true end end
    seen={}
    for _,entry in ipairs(Recent())do
        local key=NormalizeRecipient(entry.name)
        if key and not seen[key]then result.recent[#result.recent+1]=key;seen[key]=true end
    end
    table.sort(result.alts);table.sort(result.favorites)
    return result
end
local function FillRecipient(key)
    if not SendMailNameEditBox or not SendMailFrame or not SendMailFrame:IsShown()then
        print("Bel Toolbox: "..L("Open a mailbox and select Send Mail first."));return
    end
    SendMailNameEditBox:SetText(RecipientText(key));SendMailNameEditBox:ClearFocus()
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetFocus()end
end
local function CurrentRecipient()
    return SendMailNameEditBox and NormalizeRecipient(SendMailNameEditBox:GetText())
end
local function RefreshFavorite()
    if favoriteButton then favoriteButton.icon:SetVertexColor(IsFavorite(CurrentRecipient())and 1 or 0.65,IsFavorite(CurrentRecipient())and 0.82 or 0.65,IsFavorite(CurrentRecipient())and 0 or 0.65)end
end
local function RemoveFavorite(key)
    for name in pairs(Contacts())do if NormalizeRecipient(name)==key then Contacts()[name]=nil end end
    RefreshFavorite()
end
local function SaveCurrent()
    local key=CurrentRecipient()
    if not key then print("Bel Toolbox: "..L("Enter a recipient before adding a contact."));return end
    local remove=IsFavorite(key)
    for name in pairs(Contacts())do if NormalizeRecipient(name)==key then Contacts()[name]=nil end end
    if not remove then Contacts()[key]=true end
    RefreshFavorite()
end
local function ClassToken(value)
    if type(value)=="number" and GetClassInfo then return select(2,GetClassInfo(value)) end
    if type(value)~="string" then return end
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[value] then return value end
    if GetClassInfo then for id=1,20 do local name,token=GetClassInfo(id);if name==value then return token end end end
end
local function AddSocial(list,seen,name,class)
    local key=NormalizeRecipient(name)
    if not key or key==PlayerKey() or seen[key] then return end
    seen[key]=true;list[#list+1]=key
    contactMeta[key]={class=ClassToken(class)}
end
local function SocialLists()
    RequestSocial()
    local lists={guild={},friends={},players={}}
    local seen={}
    if GetNumGuildMembers and GetGuildRosterInfo then
        for index=1,(GetNumGuildMembers()or 0)do
            local name,_,_,level,className,_,_,_,_,_,classFile=GetGuildRosterInfo(index)
            AddSocial(lists.guild,seen,name,classFile or className)
        end
    end
    seen={}
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        for index=1,C_FriendList.GetNumFriends()do
            local info=C_FriendList.GetFriendInfoByIndex(index)
            if info then AddSocial(lists.friends,seen,info.name,info.className)end
        end
    end
    -- Keep the legacy fallback even when the newer namespace is present but empty.
    if GetNumFriends and GetFriendInfo then
        for index=1,(GetNumFriends()or 0)do
            local name,_,class=GetFriendInfo(index)
            AddSocial(lists.friends,seen,name,class)
        end
    end
    local function AddBattleNet(game)
        if not game or not game.characterName then return end
        local client=game.clientProgram
        if client and client~="WoW" and client~=BNET_CLIENT_WOW then return end
        local realm=game.realmName
        if (not realm or realm=="")and game.playerGuid and GetPlayerInfoByGUID then
            local _,_,_,_,_,_,resolvedRealm=GetPlayerInfoByGUID(game.playerGuid)
            realm=resolvedRealm
        end
        -- Mirrors Kerzo's character-name fallback; the native mail system resolves the recipient.
        local name=game.characterName
        if not IsForever()and realm and realm~=""then name=name.."-"..realm end
        AddSocial(lists.friends,seen,name,game.className)
    end
    if BNGetNumFriends then
        for index=1,(BNGetNumFriends()or 0)do
            if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
                local account=C_BattleNet.GetFriendAccountInfo(index)
                AddBattleNet(account and account.gameAccountInfo)
                if C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo then
                    for gameIndex=1,(C_BattleNet.GetFriendNumGameAccounts(index)or 0)do
                        AddBattleNet(C_BattleNet.GetFriendGameAccountInfo(index,gameIndex))
                    end
                end
            elseif BNGetFriendInfo then
                local _,_,_,name,_,client,online=BNGetFriendInfo(index)
                if online then AddBattleNet({characterName=name,clientProgram=client})end
            end
        end
    end
    local friendSeen=seen
    seen={}
    if C_RecentAllies and C_RecentAllies.GetRecentAllies then
        local ok,entries=pcall(C_RecentAllies.GetRecentAllies)
        if ok and type(entries)=="table"then
            for _,entry in pairs(entries)do
                if type(entry)=="table"then
                    local data=entry.characterData or entry
                    local name=data.fullName or (data.name and data.realmName and data.name.."-"..data.realmName)
                    AddSocial(lists.players,seen,name,data.classID)
                    if entry.stateData and entry.stateData.isConvertedLegacyFriend then AddSocial(lists.friends,friendSeen,name,data.classID)end
                end
            end
        end
    end
    local db=ns.GetSettings()
    local records=db.mailGroupRecent and db.mailGroupRecent[PlayerKey()]or{}
    for _,entry in ipairs(records)do AddSocial(lists.players,seen,entry.name,entry.class)end
    table.sort(lists.guild);table.sort(lists.friends)
    return lists
end
local function RecordGroup()
    if not IsInGroup or not IsInGroup()then return end
    local db=ns.GetSettings();db.mailGroupRecent=db.mailGroupRecent or{}
    local owner=PlayerKey();if not owner then return end
    local records=db.mailGroupRecent[owner]or{};db.mailGroupRecent[owner]=records
    local raid=IsInRaid and IsInRaid()
    local count=raid and GetNumGroupMembers()or (GetNumSubgroupMembers and GetNumSubgroupMembers()or math.max(0,GetNumGroupMembers()-1))
    for index=1,count do
        local unit=(raid and "raid"or"party")..index
        local name,realm=UnitFullName(unit)
        if not name then name,realm=UnitName(unit)end
        if issecretvalue and (issecretvalue(name)or issecretvalue(realm))then name=nil;realm=nil end
        local fullName=name
        if name and IsForever()then
            if realm and realm~=""and realm~=Realm()and not name:find(realm,1,true)then fullName=name.." "..realm end
        elseif name then fullName=name.."-"..((realm and realm~="")and realm or Realm())end
        local key=fullName and NormalizeRecipient(fullName)
        if key and key~=owner then
            for i=#records,1,-1 do if records[i].name==key then table.remove(records,i)end end
            local _,class=UnitClass(unit)
            table.insert(records,1,{name=key,class=class,seenAt=time()})
        end
    end
    while #records>40 do table.remove(records)end
end
function ns.OpenContacts()
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(launcher or UIParent,function(_,root)
        if root.SetScrollMode then root:SetScrollMode(380)end
        root:CreateTitle(L("Mail Contacts"))
        local lists=Lists()
        local social=SocialLists()
        lists.guild,lists.friends,lists.players=social.guild,social.friends,social.players
        for _,section in ipairs({{key="alts",label="My alts"},{key="guild",label="Guild members"},{key="friends",label="Friends"},{key="players",label="Recent players / groups"},{key="favorites",label="Favorites"},{key="recent",label="Recent recipients"}})do
            local submenu=root:CreateButton(L(section.label))
            if submenu.SetScrollMode then submenu:SetScrollMode(340)end
            local names=lists[section.key]
            if #names==0 then submenu:CreateTitle(L(section.key=="alts"and "Log in to each alt once to list it here."or"No entries yet"))end
            for _,name in ipairs(names)do
                local key=name
                if section.key=="favorites"then
                    local actions=submenu:CreateButton(ColorName(key))
                    actions:CreateButton(L("Use this recipient"),function()FillRecipient(key)end)
                    actions:CreateButton(L("Delete favorite"),function()RemoveFavorite(key)end)
                else submenu:CreateButton(ColorName(key),function()FillRecipient(key)end)end
            end
        end
        root:CreateDivider()
        root:CreateButton(L(IsFavorite(CurrentRecipient())and "Remove current recipient from contacts"or"Add current recipient to contacts"),SaveCurrent)
    end)
end
local function IconButton(name,parent,icon)
    local button=CreateFrame("Button",name,parent)
    button:SetSize(20,20)
    button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetAllPoints();button.icon:SetTexture(icon)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:SetFrameLevel(parent:GetFrameLevel()+10)
    return button
end
local function InstallLauncher()
    if not SendMailNameEditBox then return end
    local edit=SendMailNameEditBox
    local host=MailFrame or edit:GetParent()
    if not launcher then
        launcher=IconButton("BelToolboxMailContactsButton",host,"Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-arrow-left.png")
        launcher.icon:SetRotation(math.pi/2)
        launcher:SetPoint("RIGHT",edit,"RIGHT",-3,0)
        launcher:SetScript("OnClick",ns.OpenContacts)
        launcher:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(L("My alts / Favorites / Recent recipients"));GameTooltip:Show()
        end)
        launcher:SetScript("OnLeave",function()GameTooltip:Hide()end)
        favoriteButton=IconButton("BelToolboxMailFavoriteButton",host,"Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        favoriteButton:SetPoint("RIGHT",launcher,"LEFT",-2,0)
        favoriteButton:SetScript("OnClick",SaveCurrent)
        favoriteButton:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(L(IsFavorite(CurrentRecipient())and "Remove current recipient from contacts"or"Add current recipient to contacts"));GameTooltip:Show()
        end)
        favoriteButton:SetScript("OnLeave",function()GameTooltip:Hide()end)
        edit:HookScript("OnTextChanged",RefreshFavorite)
    end
    if not originalInsets then originalInsets={edit:GetTextInsets()}end
    if SendMailFrame and not sendPanelHooked then
        sendPanelHooked=true
        SendMailFrame:HookScript("OnShow",function()InstallLauncher()end)
        SendMailFrame:HookScript("OnHide",function()
            launcher:Hide();favoriteButton:Hide();GameTooltip:Hide()
            if MenuUtil and MenuUtil.CloseContextMenu then MenuUtil.CloseContextMenu(launcher)end
        end)
    end
    local enabled=ns.GetSettings().mailContactsEnabled~=false and SendMailFrame and SendMailFrame:IsShown()
    launcher:SetShown(enabled);favoriteButton:SetShown(enabled)
    -- Keep native recipient width intact: both controls live in the mail title bar.
    launcher:ClearAllPoints();launcher:SetPoint("TOPRIGHT",host,"TOPRIGHT",-35,-6)
    edit:SetTextInsets(originalInsets[1],originalInsets[2],originalInsets[3],originalInsets[4])
    RefreshFavorite()
end
local function HookSend()
    if not hookedSend and type(SendMail)=="function"then
        hooksecurefunc("SendMail",function(recipient)pendingRecipient=NormalizeRecipient(recipient)end);hookedSend=true
    end
    if not hookedMailAPI and C_Mail and type(C_Mail.SendMail)=="function"then
        hooksecurefunc(C_Mail,"SendMail",function(recipient)pendingRecipient=NormalizeRecipient(recipient)end);hookedMailAPI=true
    end
end
function ns.RefreshMailContacts()InstallLauncher()end
SLASH_BELCONTACTS1="/belcontacts"
SlashCmdList.BELCONTACTS=function()ns.OpenContacts()end
local events=CreateFrame("Frame")
for _,event in ipairs({"MAIL_SHOW","ADDON_LOADED","MAIL_SEND_SUCCESS","MAIL_FAILED","GROUP_ROSTER_UPDATE","PLAYER_ENTERING_WORLD"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event)
    if event=="GROUP_ROSTER_UPDATE"or event=="PLAYER_ENTERING_WORLD"then
        RecordGroup()
        C_Timer.After(0.5,RecordGroup);C_Timer.After(2,RecordGroup)
    elseif event=="MAIL_SEND_SUCCESS"then
        if pendingRecipient then RememberSent(pendingRecipient);pendingRecipient=nil end
    elseif event=="MAIL_FAILED"then pendingRecipient=nil
    else
        InstallLauncher();HookSend()
        if event=="MAIL_SHOW"then RecordGroup()end
        if event=="MAIL_SHOW"then
            RequestSocial()
        end
    end
end)
SLASH_BELMAILDEBUG1="/belmaildebug"
SlashCmdList.BELMAILDEBUG=function()
    lastRosterRequest=nil;RequestSocial()
    C_Timer.After(1,function()
        local guild=GetNumGuildMembers and GetNumGuildMembers()or 0
        local friends=C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends()or 0
        local bnet=BNGetNumFriends and BNGetNumFriends()or 0
        local ok,lists=pcall(SocialLists)
        print("Bel Toolbox: "..L("Mail diagnostic: realm=%s, short name=%s",Realm(),NormalizeRecipient("Test")and"OK"or"FAIL"))
        print("Bel Toolbox: "..L("Raw guild=%d, friends=%d, Battle.net=%d",guild,friends,bnet))
        if ok then print("Bel Toolbox: "..L("Menu guild=%d, friends=%d, recent=%d",#lists.guild,#lists.friends,#lists.players))
        else print("Bel Toolbox: "..tostring(lists))end
    end)
end