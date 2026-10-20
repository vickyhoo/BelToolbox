local _,ns=...
local popups=setmetatable({}, {__mode="k"})
local installed
local function Settings()
    local db=ns.GetSettings();db.chatCopy=db.chatCopy or {};return db.chatCopy
end
local function Readable(value)return not (issecretvalue and issecretvalue(value))end
local function Color(r,g,b)
    if not (Readable(r)and Readable(g)and Readable(b))or type(r)~="number"or type(g)~="number"or type(b)~="number"then return "|cffffffff"end
    local function Byte(v)return math.floor(math.max(0,math.min(1,v))*255+.5)end
    return string.format("|cff%02x%02x%02x",Byte(r),Byte(g),Byte(b))
end
local function ColoredText(chatNS)
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
            text=text:gsub("|H.-|h(.-)|h","%1"):gsub("|T.-|t",""):gsub("|A.-|a",""):gsub("|K.-|k",""):gsub("|n","\n")
            local color=Color(r,g,b)
            text=text:gsub("|r",color)
            lines[#lines+1]=color..text.."|r"
        end
    end
    if #lines>0 then return table.concat(lines,"\n")end
end
local function Stop(popup,record)
    if not record.resizing then return end
    record.resizing=nil
    popup:StopMovingOrSizing()
    local db=Settings();db.width,db.height=popup:GetWidth(),popup:GetHeight()
    -- Rebuild the template's scroll range at the final width/height.
    local text=popup._editBox._readOnlyText
    if type(text)=="string"then popup._textBox:SetText(text)end
end
local function Configure(popup,record)
    local db=Settings()
    local enabled=db.resizable~=false
    popup:SetResizable(enabled)
    record.grip:SetShown(enabled)
    if not enabled then
        Stop(popup,record);popup:SetSize(record.width,record.height)
    else
        local maxW=math.max(360,UIParent:GetWidth()*.95)
        local maxH=math.max(240,UIParent:GetHeight()*.95)
        if popup.SetResizeBounds then popup:SetResizeBounds(360,240,maxW,maxH)end
        local w=type(db.width)=="number"and db.width or record.width
        local h=type(db.height)=="number"and db.height or record.height
        popup:SetSize(math.max(360,math.min(maxW,w)),math.max(240,math.min(maxH,h)))
    end
    local text=db.channelColors~=false and ColoredText(record.chatNS)or nil
    text=text or record.original
    if type(text)=="string"then
        popup._editBox._readOnlyText=text
        popup._textBox:SetText(text)
    end
end
local function Extend(dimmer,chatNS)
    local popup=dimmer and dimmer._popup
    if not popup or not popup._editBox or not popup._textBox then return end
    local record=popups[popup]
    if not record then
        record={width=popup:GetWidth(),height=popup:GetHeight(),chatNS=chatNS};popups[popup]=record
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
        popup:HookScript("OnHide",function()Stop(popup,record)end)
    end
    -- HostPopup is called after EUI writes the unmodified copy buffer.
    record.original=popup._editBox._readOnlyText
    Configure(popup,record)
end
function ns.RefreshChatCopy()
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
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN");events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED"and name~="EllesmereUIChat"then return end
    Install()
end)
Install()
