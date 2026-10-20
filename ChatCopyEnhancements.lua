local _,ns=...
local popups=setmetatable({}, {__mode="k"})
local installed
local events,ClassEvents
local names,shortNames,guids={},{},{}
local nameCount=0
local function Settings()
    local db=ns.GetSettings();db.chatCopy=db.chatCopy or {};return db.chatCopy
end
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
    if not Text(sender)or not Text(guid)or not guid:match("^Player%-")or not GetPlayerInfoByGUID then return end
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
local function Clean(text)
    text=text:gsub("|H([^:|]+):([^|]-)|h(.-)|h",function(kind,target,label)
        if kind=="player"and Settings().classNames~=false then
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
local function ColoredLines(chatNS)
    local selected=GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    local frame=selected or ChatFrame1
    local win=chatNS._chatWins and chatNS._chatWins[frame]
    local source=win and win.smf or frame
    if chatNS._clHosted and frame==ChatFrame2 then source=frame end
    if not source or type(source.GetNumMessages)~="function"or type(source.GetMessageInfo)~="function"then return end
    local ok,count=pcall(source.GetNumMessages,source)
    if not ok or not Readable(count)or type(count)~="number"then return end
    local lines={}
    for i=1,count do
        local success,text,r,g,b=pcall(source.GetMessageInfo,source,i)
        if success and Readable(text)and type(text)=="string"then
            -- Keep hyperlink display text and inline colors; remove UI-only
            -- textures and protected-name placeholders, as EUI's copy view does.
            text=Clean(text)
            local color=Settings().channelColors~=false and Color(r,g,b)or "|cffffffff"
            text=text:gsub("|r",color)
            lines[#lines+1]=color..text.."|r"
        end
    end
    if #lines>0 then return lines end
end
local function Filter(popup,record)
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
    local enabled=db.resizable~=false
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
    if type(db.x)=="number"and type(db.y)=="number"then
        popup:ClearAllPoints();popup:SetPoint("CENTER",UIParent,"BOTTOMLEFT",db.x,db.y)
    end
    CaptureRoster()
    record.lines=ColoredLines(record.chatNS)
    if not record.lines then
        record.lines={}
        for line in ((record.original or "").."\n"):gmatch("(.-)\n")do record.lines[#record.lines+1]=line end
    end
    Filter(popup,record)
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
        drag:SetScript("OnDragStart",function()record.moving=true;popup:StartMoving()end)
        drag:SetScript("OnDragStop",function()Stop(popup,record)end)
        local title=drag:CreateFontString(nil,"OVERLAY","GameFontNormal")
        title:SetPoint("CENTER");title:SetText(ns.L("Copy Chat"))
        local label=popup:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
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
            if record.syncing then return end
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
            if button~="LeftButton"or Settings().resizable==false then return end
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
        if Settings().classNames~=false then events:RegisterEvent(event)else events:UnregisterEvent(event)end
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
