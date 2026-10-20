local _,ns=...
local popups=setmetatable({}, {__mode="k"})
local installed
local events,ClassEvents
local names,shortNames,guids={},{},{}
local nameCount=0
local diagnostics={enabled=false,snapshots={}}
local function Settings()
    local db=ns.GetSettings();db.chatCopy=db.chatCopy or {};return db.chatCopy
end
local function Enabled()
    local db=Settings()
    if db.enabled~=nil then return db.enabled end
    -- Migrate the previous version's all-off state to a fully native window.
    return not (db.resizable==false and db.channelColors==false and db.classNames==false)
end
ns.IsChatCopyEnabled=Enabled
local function Readable(value)return not (issecretvalue and issecretvalue(value))end
local function Text(value)return Readable(value)and type(value)=="string"and value~=""end
local function AddClass(name,class)
    if not Text(name)or not Text(class)or not (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])then return end
    name=name:lower()
    if not names[name]then
        nameCount=nameCount+1
        if nameCount>1024 then names,shortNames,guids={},{},{};nameCount=1 end
    end
    names[name]=class
    local short=name:match("^([^%-]+)")
    if shortNames[short]==nil then shortNames[short]=class
    elseif shortNames[short]~=class then shortNames[short]=false end
end
local function CaptureSender(sender,guid)
    if not Text(sender)or not Text(guid)or not GetPlayerInfoByGUID then return end
    local class=guids[guid]
    if not class then
        local ok,_,value=pcall(GetPlayerInfoByGUID,guid)
        if ok and Text(value)then class=value;guids[guid]=class end
    end
    AddClass(sender,class)
end
local function CaptureRoster()
    if Settings().classNames==false then return end
    if UnitFullName and UnitClass then
        local units={"player"}
        if IsInRaid and IsInRaid()then
            for i=1,(GetNumGroupMembers and GetNumGroupMembers()or 0)do units[#units+1]="raid"..i end
        else for i=1,4 do units[#units+1]="party"..i end end
        for _,unit in ipairs(units)do
            local exists=not UnitExists or UnitExists(unit)
            if Readable(exists)and exists then
                local name,realm=UnitFullName(unit);local _,class=UnitClass(unit)
                if Text(name)then AddClass(Text(realm)and (name.."-"..realm)or name,class)end
            end
        end
    end
    if GetNumGuildMembers and GetGuildRosterInfo then
        local count=GetNumGuildMembers()
        if Readable(count)and type(count)=="number"then
            for i=1,count do
                local name,_,_,_,_,_,_,_,_,_,class=GetGuildRosterInfo(i)
                AddClass(name,class)
            end
        end
    end
end
local function Color(r,g,b)
    if not (Readable(r)and Readable(g)and Readable(b))or type(r)~="number"or type(g)~="number"or type(b)~="number"then return "|cffffffff"end
    local function Byte(v)return math.floor(math.max(0,math.min(1,v))*255+.5)end
    return string.format("|cff%02x%02x%02x",Byte(r),Byte(g),Byte(b))
end
local function PlayerKey(target)return (target:match("^([^:]+)")or ""):lower()end
local function LearnColors(text,colors)
    -- Blizzard/EUI already know many more senders than our session cache.
    -- Reuse their formatted player-link colors, including history from login.
    for target,label in text:gmatch("|Hplayer:([^|]-)|h(.-)|h")do
        local color=label:match("(|c%x%x%x%x%x%x%x%x)")
        if color then colors[PlayerKey(target)]=color end
    end
    for color,target in text:gmatch("(|c%x%x%x%x%x%x%x%x)|Hplayer:([^|]-)|h")do
        colors[PlayerKey(target)]=color
    end
end
local function Clean(text,colors)
    text=text:gsub("|H([^:|]+):([^|]-)|h(.-)|h",function(kind,target,label)
        if kind=="player"and Settings().classNames~=false then
            -- Preserve native inline colors rather than replacing them.
            if label:find("|c",1,true)then return label end
            local native=colors and colors[PlayerKey(target)]
            if native then return native..label.."|r"end
            local name=target:match("^([^:]+)")
            local key=name and name:lower()
            local class=key and names[key]
            if key and not key:find("-",1,true)then class=shortNames[key]end
            local color=class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
            if color then return Color(color.r,color.g,color.b)..label:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","").."|r"end
        end
        return label
    end)
    return text:gsub("|T.-|t",""):gsub("|A.-|a",""):gsub("|K.-|k",""):gsub("|n","\n")
end
local function Plain(text)return text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("||","|")end
local function ActiveSource(chatNS)
    local selected=GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    local frame=selected or ChatFrame1
    local win=chatNS._chatWins and chatNS._chatWins[frame]
    local engine=win and not (chatNS._clHosted and frame==ChatFrame2)
    return engine and win.smf or frame,engine and "engine"or "native"
end
local function Split(text)
    local result={}
    if Text(text)then for line in (text.."\n"):gmatch("(.-)\n")do result[#result+1]=line end end
    return result
end
local function Shape(text)
    if not Text(text)then return "-"end
    local codes={}
    for token in text:gmatch("|c%x%x%x%x%x%x%x%x")do codes[#codes+1]=token end
    local _,resets=text:gsub("|r","")
    local _,pipes=text:gsub("||","")
    local _,named=text:gsub("|cn[%w_]+:","")
    local labels={}
    for target,label in text:gmatch("|Hplayer:([^|]-)|h(.-)|h")do
        labels[#labels+1]=PlayerKey(target).."="..label
        if #labels==2 then break end
    end
    -- Only control codes and player-link labels: never capture message bodies.
    local result="bytes="..#text.." colors="..table.concat(codes,",").." resets="..resets.." escaped="..pipes.." named="..named.." links="..table.concat(labels,",")
    if #result>900 then result="bytes="..#text.." (oversized control sequence omitted)"end
    return result:gsub("|","[PIPE]")
end
local function DebugSnapshot(popup,record)
    if not diagnostics.enabled then return end
    local db=Settings()
    local source,kind=ActiveSource(record.chatNS)
    local native=Split(record.original)
    local output=Split(popup._editBox._readOnlyText)
    local snapshot={"enabled="..tostring(Enabled()).." channel="..tostring(db.channelColors~=false).." class="..tostring(db.classNames~=false).." source="..kind.." native-lines="..#native.." output-lines="..#output}
    if source and type(source.GetNumMessages)=="function"and type(source.GetMessageInfo)=="function"then
        local ok,count=pcall(source.GetNumMessages,source)
        if ok and Readable(count)and type(count)=="number"then
            snapshot[1]=snapshot[1].." source-lines="..count
            local samples={}
            for i=1,count do
                local success,text,r,g,b=pcall(source.GetMessageInfo,source,i)
                if success and Text(text)and text:find("|Hplayer:",1,true)then
                    samples[#samples+1]={i=i,text=Shape(text),rgb=Color(r,g,b):gsub("|","[PIPE]")}
                end
            end
            for j,sample in ipairs(samples)do
                if j<=2 or j>#samples-3 then
                    snapshot[#snapshot+1]="row="..sample.i.." RGB="..sample.rgb.." raw "..sample.text
                    snapshot[#snapshot+1]="native "..Shape(native[sample.i])
                    snapshot[#snapshot+1]="output "..Shape(output[sample.i])
                end
            end
        end
    end
    local log=diagnostics.snapshots;log[#log+1]=snapshot
    if #log>4 then table.remove(log,1)end
end
local function ColoredLines(chatNS)
    local source=ActiveSource(chatNS)
    if not source or type(source.GetNumMessages)~="function"or type(source.GetMessageInfo)~="function"then return end
    local ok,count=pcall(source.GetNumMessages,source)
    if not ok or not Readable(count)or type(count)~="number"then return end
    local lines,raw,colors={},{},{}
    for i=1,count do
        local success,text,r,g,b=pcall(source.GetMessageInfo,source,i)
        if success and Readable(text)and type(text)=="string"then
            raw[#raw+1]={text,r,g,b};LearnColors(text,colors)
        end
    end
    for _,message in ipairs(raw)do
            local text,r,g,b=(unpack or table.unpack)(message)
            -- Keep hyperlink display text and inline colors; remove UI-only
            -- textures and protected-name placeholders, as EUI's copy view does.
            text=Clean(text,colors)
            if Settings().channelColors~=false then
                local color=Color(r,g,b)
                text=color..text:gsub("|r",color).."|r"
            end
            lines[#lines+1]=text
    end
    if #lines>0 then return lines end
end
local function Filter(popup,record)
    if not Enabled()then return end
    local query=record.search:GetText()or ""
    query=query:match("^%s*(.-)%s*$"):lower()
    local result={}
    for _,line in ipairs(record.lines or {})do
        if query==""or Plain(line):lower():find(query,1,true)then result[#result+1]=line end
    end
    local text=table.concat(result,"\n")
    popup._editBox._readOnlyText=text
    popup._textBox:SetText(text)
    record.count:SetText(ns.L("%d / %d messages",#result,#(record.lines or {})))
end
local function Stop(popup,record)
    if not record.resizing and not record.moving then return end
    local resized=record.resizing
    record.resizing=nil
    record.moving=nil
    popup:StopMovingOrSizing()
    local db=Settings();db.width,db.height=popup:GetWidth(),popup:GetHeight()
    local x,y=popup:GetCenter()
    if x and y then db.x,db.y=x,y end
    -- Rebuild the template's scroll range at the final width/height.
    local text=popup._editBox._readOnlyText
    if resized and type(text)=="string"then popup._textBox:SetText(text)end
end
local function Configure(popup,record)
    local db=Settings()
    local active=Enabled()
    local enabled=active and db.resizable~=false
    Stop(popup,record)
    record.searchToken=(record.searchToken or 0)+1
    local searchable=active and db.searchable~=false
    record.drag:SetShown(active)
    record.drag:EnableMouse(enabled)
    popup:SetMovable(enabled)
    record.search:SetShown(searchable);record.label:SetShown(searchable);record.count:SetShown(searchable)
    if not searchable then
        record.syncing=true;record.search:SetText("");record.search:ClearFocus();record.syncing=nil
    end
    popup._textBox:ClearAllPoints()
    popup._textBox:SetPoint("TOPLEFT",popup,"TOPLEFT",20,active and (searchable and -66 or -34)or -20)
    popup._textBox:SetPoint("BOTTOMRIGHT",popup,"BOTTOMRIGHT",-20,60)
    popup:SetResizable(enabled)
    record.grip:SetShown(enabled)
    if not enabled then
        Stop(popup,record);popup:SetSize(record.width,record.height)
    else
        local maxW=math.max(400,UIParent:GetWidth()*.95)
        local maxH=math.max(280,UIParent:GetHeight()*.95)
        if popup.SetResizeBounds then popup:SetResizeBounds(400,280,maxW,maxH)end
        local w=type(db.width)=="number"and db.width or record.width
        local h=type(db.height)=="number"and db.height or record.height
        popup:SetSize(math.max(400,math.min(maxW,w)),math.max(280,math.min(maxH,h)))
    end
    if not active then
        popup:ClearAllPoints();popup:SetPoint("CENTER",UIParent,"CENTER",0,60)
        popup._editBox._readOnlyText=record.original
        popup._textBox:SetText(record.original or "")
        DebugSnapshot(popup,record)
        return
    end
    if enabled and type(db.x)=="number"and type(db.y)=="number"then
        popup:ClearAllPoints();popup:SetPoint("CENTER",UIParent,"BOTTOMLEFT",db.x,db.y)
    end
    CaptureRoster()
    record.lines=ColoredLines(record.chatNS)
    if not record.lines then
        record.lines={}
        for line in ((record.original or "").."\n"):gmatch("(.-)\n")do record.lines[#record.lines+1]=line end
    end
    Filter(popup,record)
    DebugSnapshot(popup,record)
end
local function Extend(dimmer,chatNS)
    local popup=dimmer and dimmer._popup
    if not popup or not popup._editBox or not popup._textBox then return end
    local record=popups[popup]
    if not record then
        record={width=popup:GetWidth(),height=popup:GetHeight(),chatNS=chatNS};popups[popup]=record
        popup:SetMovable(true);popup:SetClampedToScreen(true)
        local drag=CreateFrame("Frame",nil,popup)
        record.drag=drag
        drag:SetPoint("TOPLEFT",popup,"TOPLEFT",4,-2);drag:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-4,-2);drag:SetHeight(26)
        drag:EnableMouse(true);drag:RegisterForDrag("LeftButton")
        drag:SetScript("OnDragStart",function()
            if not Enabled()or Settings().resizable==false then return end
            record.moving=true;popup:StartMoving()
        end)
        drag:SetScript("OnDragStop",function()Stop(popup,record)end)
        local title=drag:CreateFontString(nil,"OVERLAY","GameFontNormal")
        title:SetPoint("CENTER");title:SetText(ns.L("Copy Chat"))
        local label=popup:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        record.label=label
        label:SetPoint("TOPLEFT",popup,"TOPLEFT",20,-40);label:SetText(ns.L("Search messages"))
        local count=popup:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        record.count=count;count:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-20,-40);count:SetWidth(94);count:SetJustifyH("RIGHT")
        local search=CreateFrame("EditBox",nil,popup,"InputBoxTemplate")
        record.search=search
        search:SetAutoFocus(false);search:SetHeight(22)
        search:SetPoint("LEFT",label,"RIGHT",10,0);search:SetPoint("RIGHT",count,"LEFT",-12,0)
        search:SetTextInsets(4,22,0,0)
        if ns.skin and ns.skin.EditBox then ns.skin.EditBox(search)end
        local clear=CreateFrame("Button",nil,search)
        clear:SetSize(20,20);clear:SetPoint("RIGHT",search,"RIGHT",0,0)
        local cross=clear:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        cross:SetPoint("CENTER");cross:SetText("×")
        clear:SetScript("OnClick",function()search:SetText("");search:ClearFocus()end)
        search:SetScript("OnTextChanged",function()
            if record.syncing or not Enabled()or Settings().searchable==false then return end
            record.searchToken=(record.searchToken or 0)+1
            local token=record.searchToken
            C_Timer.After(.15,function()if token==record.searchToken then Filter(popup,record)end end)
        end)
        search:SetScript("OnEscapePressed",function()search:SetText("");search:ClearFocus()end)
        search:SetScript("OnEnterPressed",function()Filter(popup,record);search:ClearFocus()end)
        popup._textBox:ClearAllPoints()
        popup._textBox:SetPoint("TOPLEFT",popup,"TOPLEFT",20,-66)
        popup._textBox:SetPoint("BOTTOMRIGHT",popup,"BOTTOMRIGHT",-20,60)
        local grip=CreateFrame("Button",nil,popup)
        record.grip=grip
        grip:SetSize(24,24);grip:SetPoint("BOTTOMRIGHT",popup,"BOTTOMRIGHT",-2,2)
        grip:SetFrameLevel(popup:GetFrameLevel()+10)
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        grip:SetScript("OnMouseDown",function(_,button)
            if button~="LeftButton"or not Enabled()or Settings().resizable==false then return end
            record.resizing=true;popup:StartSizing("BOTTOMRIGHT")
        end)
        grip:SetScript("OnMouseUp",function()Stop(popup,record)end)
        grip:SetScript("OnHide",function()Stop(popup,record)end)
        popup:HookScript("OnHide",function()
            Stop(popup,record);record.searchToken=(record.searchToken or 0)+1;search:ClearFocus()
        end)
    end
    -- HostPopup is called after EUI writes the unmodified copy buffer.
    record.original=popup._editBox._readOnlyText
    record.syncing=true;record.search:SetText("");record.syncing=nil
    Configure(popup,record)
end
function ns.RefreshChatCopy()
    if ClassEvents then ClassEvents()end
    for popup,record in pairs(popups)do Configure(popup,record)end
end
local function Install()
    local eui=EllesmereUI
    local chatNS=eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIChat
    local chat=chatNS and chatNS.ECHAT
    if not chat or installed==chat or type(chat.HostPopup)~="function"then return end
    installed=chat
    hooksecurefunc(chat,"HostPopup",function(dimmer)Extend(dimmer,chatNS)end)
end
events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN");events:RegisterEvent("ADDON_LOADED")
local messageEvents={"CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_CHANNEL","CHAT_MSG_GUILD","CHAT_MSG_OFFICER","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER"}
ClassEvents=function()
    for _,event in ipairs(messageEvents)do
        if Enabled()and Settings().classNames~=false then events:RegisterEvent(event)else events:UnregisterEvent(event)end
    end
end
events:SetScript("OnEvent",function(_,event,...)
    if event:match("^CHAT_MSG_")then
        local _,sender,_,_,_,_,_,_,_,_,_,guid=...
        CaptureSender(sender,guid);return
    end
    local name=...
    if event=="ADDON_LOADED"and name~="EllesmereUIChat"then return end
    ClassEvents()
    Install()
end)
Install()

SLASH_BELCHATDEBUG1="/belchatdebug"
SlashCmdList.BELCHATDEBUG=function(command)
    command=(command or ""):lower():match("^%s*(.-)%s*$")
    local function Print(text)print(ns.L("Bel Toolbox")..": "..text)end
    if command=="on"then
        diagnostics.enabled=true;diagnostics.snapshots={}
        Print(ns.L("Chat copy diagnostics enabled. Open the copy window with enhancements on and off, then run /belchatdebug."));return
    elseif command=="off"then
        diagnostics.enabled=false;diagnostics.snapshots={}
        Print(ns.L("Chat copy diagnostics disabled."));return
    end
    Print("chat-copy debug 0.17.2 active="..tostring(diagnostics.enabled).." snapshots="..#diagnostics.snapshots)
    for i,snapshot in ipairs(diagnostics.snapshots)do
        Print("snapshot "..i)
        for _,line in ipairs(snapshot)do Print(line)end
    end
    if #diagnostics.snapshots==0 then Print(ns.L("Use /belchatdebug on before opening the copy window."))end
end
