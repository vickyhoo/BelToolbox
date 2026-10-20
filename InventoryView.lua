local _, ns = ...
local L = ns.L
local EUI = _G.EllesmereUI
local skin, view, launcher
local fonts, controls = {}, {}
local W,H,SIDE,COLS,SIZE,STEP = 790,540,174,12,42,46
local function Font(text,size)
    local path = EUI and EUI.GetFontPath and EUI.GetFontPath("bags") or STANDARD_TEXT_FONT
    text:SetFont(path,size or 12,"")
end
local function Label(parent,x,y,width,size)
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    label:SetPoint("TOPLEFT",x,y);label:SetWidth(width);label:SetJustifyH("LEFT");Font(label,size)
    fonts[#fonts+1]=label
    return label
end
local function Fill(frame,r,g,b,a,layer)
    local texture=frame:CreateTexture(nil,layer or "BACKGROUND")
    texture:SetAllPoints();texture:SetColorTexture(r,g,b,a)
    return texture
end
local function Plate(frame,r,g,b,a)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(r,g,b,a);frame:SetBackdropBorderColor(0.16,0.16,0.16,1)
end
local function SkinControl(frame,kind)
    controls[#controls+1]={frame=frame,kind=kind}
    if skin and skin[kind] then skin[kind](frame)end
end
local function Button(parent,text,x,y,width,callback)
    local button=CreateFrame("Button",nil,parent,"BackdropTemplate")
    button:SetSize(width,26);button:SetPoint("TOPLEFT",x,y)
    Plate(button,0.05,0.05,0.05,0.8)
    button.label=Label(button,8,-6,width-16,12);button.label:SetText(text)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(1,1,1,0.09)
    button:SetScript("OnClick",callback)
    SkinControl(button,"Button")
    return button
end
local function Records()return ns.GetInventoryStore().characters end
local function Keys()
    local result={};for key in pairs(Records())do result[#result+1]=key end;table.sort(result);return result
end
local function Count(items,id)return items and items[id] and items[id].count or 0 end
local function Stamp(value)return value and date("%m-%d %H:%M",value)or L("Not recorded")end
local function ItemData(id,entry)
    local name,_,quality,_,_,kind = C_Item.GetItemInfo(entry.link or id)
    local _,instantKind,_,_,icon,classID = C_Item.GetItemInfoInstant(id)
    return { id=id,entry=entry,name=name or (entry.link and entry.link:match("%[(.-)%]"))or L("Item #%d",id),
        quality=quality or 1,kind=kind or instantKind or L("Other items"),classID=classID or -1,icon=icon or 134400 }
end
local function Collect(record,source,query)
    local items={}
    if source~="bank"then for id,entry in pairs(record.bags or {})do items[id]=entry end end
    if source~="bags"then for id,entry in pairs(record.bank or {})do items[id]=items[id]or entry end end
    local groups,order={},{}
    query=(query or""):lower()
    for id,entry in pairs(items)do
        local item=ItemData(id,entry)
        if query==""or item.name:lower():find(query,1,true)or tostring(id)==query then
            item.count=(source~="bank"and Count(record.bags,id)or 0)+(source~="bags"and Count(record.bank,id)or 0)
            if not groups[item.classID]then groups[item.classID]={name=item.kind,items={}};order[#order+1]=item.classID end
            local list=groups[item.classID].items;list[#list+1]=item
        end
    end
    table.sort(order)
    for _,group in pairs(groups)do table.sort(group.items,function(a,b)if a.name==b.name then return a.id<b.id end return a.name<b.name end)end
    return groups,order
end
local function Title(index)
    if view.headers[index]then return view.headers[index]end
    local frame=CreateFrame("Frame",nil,view.content)
    frame:SetSize(562,24)
    frame.text=Label(frame,0,-4,460,12);frame.text:SetTextColor(0.75,0.75,0.75)
    local line=frame:CreateTexture(nil,"ARTWORK");line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT",0,1);line:SetPoint("BOTTOMRIGHT",0,1);line:SetColorTexture(0.7,0.7,0.7,0.18)
    view.headers[index]=frame;return frame
end
local function Slot(index)
    if view.slots[index]then return view.slots[index]end
    local button=CreateFrame("Button",nil,view.content,"BackdropTemplate")
    button:SetSize(SIZE,SIZE);Plate(button,0.03,0.03,0.03,0.7)
    button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("TOPLEFT",1,-1);button.icon:SetPoint("BOTTOMRIGHT",-1,1)
    button.icon:SetTexCoord(0.07,0.93,0.07,0.93)
    button.count=button:CreateFontString(nil,"OVERLAY","NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT",-2,2)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:SetScript("OnEnter",function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(self.item.entry.link or"item:"..self.item.id)
        GameTooltip:AddLine(" ")
        local record=Records()[view.key]
        GameTooltip:AddLine(view.key,ns.GetCharacterColor(record))
        GameTooltip:AddLine(L("Bags %d / Bank %s",Count(record.bags,self.item.id),record.bankAt and tostring(Count(record.bank,self.item.id))or"?"),1,1,1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function()GameTooltip:Hide()end)
    button:SetScript("OnClick",function(self)
        if self.item and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.item.entry.link or"item:"..self.item.id)end
    end)
    view.slots[index]=button;return button
end
local function ScrollToTop()view.scroll:SetVerticalScroll(0)end
local function SelectSource(source)
    view.source=source;view.category=nil;ScrollToTop();view:Refresh()
end
local function BuildCharacterMenu()
    local menu=CreateFrame("Frame",nil,view,"BackdropTemplate")
    menu:SetPoint("TOPLEFT",view.characters,"BOTTOMLEFT",0,-3);menu:SetSize(285,235);menu:SetFrameLevel(view:GetFrameLevel()+30)
    Plate(menu,0.04,0.04,0.04,1)
    local scroll=CreateFrame("ScrollFrame",nil,menu,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",6,-6);scroll:SetPoint("BOTTOMRIGHT",-28,6)
    local content=CreateFrame("Frame",nil,scroll);content:SetWidth(250);content:SetHeight(1);scroll:SetScrollChild(content)
    menu.rows={};menu:Hide()
    if skin then skin.Panel(menu);if scroll.ScrollBar then skin.ScrollBar(scroll.ScrollBar)end end
    function menu:Refresh()
        local keys=Keys()
        for _,row in ipairs(self.rows)do row:Hide()end
        for index,key in ipairs(keys)do
            local row=self.rows[index]
            if not row then
                row=Button(content,"",0,-(index-1)*28,250,function(self)
                    view.key=self.key;view.category=nil;ScrollToTop();view:Refresh();menu:Hide()
                end)
                self.rows[index]=row
            end
            row.key=key;row.label:SetText(key);row.label:SetTextColor(ns.GetCharacterColor(Records()[key]));row:Show()
        end
        content:SetHeight(math.max(1,#keys*28))
    end
    return menu
end
local function Build()
    view=CreateFrame("Frame","BelToolboxInventory",UIParent,"BackdropTemplate")
    view:SetSize(W,H);view:SetPoint("CENTER");view:SetFrameStrata("DIALOG");view:SetToplevel(true);view:SetClampedToScreen(true)
    Plate(view,0.08,0.075,0.065,0.97)
    view:SetMovable(true);view:EnableMouse(true);view:RegisterForDrag("LeftButton")
    view:SetScript("OnDragStart",view.StartMoving);view:SetScript("OnDragStop",view.StopMovingOrSizing)
    view.source="bank";view.slots={};view.headers={};view.categories={}
    local header=CreateFrame("Frame",nil,view);header:SetPoint("TOPLEFT",1,-1);header:SetPoint("TOPRIGHT",-1,-1);header:SetHeight(37);Fill(header,0,0,0,0.5)
    Label(header,10,-11,168,13):SetText(L("Offline Bank"))
    view.characters=Button(header,"",180,-5,285,function()
        if not view.menu then view.menu=BuildCharacterMenu()end
        if view.menu:IsShown()then view.menu:Hide()else view.menu:Refresh();view.menu:Show()end
    end)
    view.characters.label:SetWidth(245)
    view.characters.arrow=view.characters:CreateTexture(nil,"OVERLAY")
    view.characters.arrow:SetSize(12,12)
    view.characters.arrow:SetPoint("RIGHT",view.characters,"RIGHT",-10,0)
    view.characters.arrow:SetTexture("Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-arrow-left.png")
    view.characters.arrow:SetRotation(math.pi/2)
    view.characters.arrow:SetVertexColor(0.8,0.8,0.8)
    local close=CreateFrame("Button",nil,header,"UIPanelCloseButton");close:SetSize(25,25);close:SetPoint("RIGHT",-4,0);close:SetScript("OnClick",function()view:Hide()end);SkinControl(close,"CloseButton")
    view.search=CreateFrame("EditBox",nil,header,"BackdropTemplate")
    view.search:SetSize(215,24);view.search:SetPoint("RIGHT",-37,0);view.search:SetAutoFocus(false);view.search:SetTextInsets(6,6,0,0)
    Font(view.search,12);Plate(view.search,0.02,0.02,0.02,0.95);SkinControl(view.search,"EditBox")
    local placeholder=Label(view.search,6,-5,190,12);placeholder:SetText(L("Search items..."));placeholder:SetTextColor(0.45,0.45,0.45)
    view.search:SetScript("OnTextChanged",function(self)placeholder:SetShown((self:GetText()or"")=="");view.category=nil;ScrollToTop();view:Refresh()end)
    view.search:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    local sidebar=CreateFrame("Frame",nil,view);sidebar:SetPoint("TOPLEFT",1,-39);sidebar:SetPoint("BOTTOMLEFT",1,36);sidebar:SetWidth(SIDE);Fill(sidebar,0,0,0,0.25)
    Label(sidebar,9,-10,156,11):SetText(L("Storage"))
    view.sources={}
    for index,source in ipairs({"bank","bags","all"})do
        local key=source
        local labels={bank="Bank",bags="Bags",all="All"}
        local button=Button(sidebar,L(labels[source]),6,-34-(index-1)*31,162,function()SelectSource(key)end)
        view.sources[source]=button
    end
    Label(sidebar,9,-136,156,11):SetText(L("Item categories"))
    local categoryScroll=CreateFrame("ScrollFrame",nil,sidebar,"UIPanelScrollFrameTemplate")
    categoryScroll:SetPoint("TOPLEFT",5,-159);categoryScroll:SetPoint("BOTTOMRIGHT",-23,4)
    view.categoryContent=CreateFrame("Frame",nil,categoryScroll);view.categoryContent:SetSize(138,1);categoryScroll:SetScrollChild(view.categoryContent)
    if categoryScroll.ScrollBar then SkinControl(categoryScroll.ScrollBar,"ScrollBar")end
    view.scroll=CreateFrame("ScrollFrame",nil,view,"UIPanelScrollFrameTemplate")
    view.scroll:SetPoint("TOPLEFT",SIDE+14,-67);view.scroll:SetPoint("BOTTOMRIGHT",-29,66)
    view.content=CreateFrame("Frame",nil,view.scroll);view.content:SetSize(562,1);view.scroll:SetScrollChild(view.content)
    if view.scroll.ScrollBar then SkinControl(view.scroll.ScrollBar,"ScrollBar")end
    view.status=Label(view,SIDE+14,-47,560,11);view.status:SetTextColor(0.65,0.65,0.65)
    local footer=CreateFrame("Frame",nil,view);footer:SetPoint("BOTTOMLEFT",1,1);footer:SetPoint("BOTTOMRIGHT",-1,1);footer:SetHeight(34);Fill(footer,0,0,0,0.5)
    view.timestamps=Label(footer,10,-11,760,11);view.timestamps:SetTextColor(0.65,0.65,0.65)
    view.summary=Label(view,SIDE+14,-H+59,560,11)
    tinsert(UISpecialFrames,"BelToolboxInventory")
    view:SetScript("OnHide",function()if view.menu then view.menu:Hide()end;GameTooltip:Hide()end)
    function view:Refresh()
        local record=Records()[self.key]
        if not record then return end
        self.characters.label:SetText(self.key)
        self.characters.label:SetTextColor(ns.GetCharacterColor(record))
        self.timestamps:SetText(L("Bags updated: %s   |   Bank updated: %s",Stamp(record.bagsAt),Stamp(record.bankAt)))
        self.status:SetText(self.source=="bank"and not record.bankAt and L("Open this character's bank once to record its contents.")or L("Offline snapshot - view only"))
        local groups,order=Collect(record,self.source,self.search:GetText())
        for source,button in pairs(self.sources)do button.label:SetTextColor(source==self.source and 1 or 0.7,source==self.source and 0.82 or 0.7,source==self.source and 0.4 or 0.7)end
        for _,button in ipairs(self.categories)do button:Hide()end
        for index,classID in ipairs(order)do
            local button=self.categories[index]
            if not button then
                button=Button(self.categoryContent,"",0,-(index-1)*29,138,function(self)
                    if view.category==self.classID then view.category=nil else view.category=self.classID end
                    ScrollToTop();view:Refresh()
                end)
                self.categories[index]=button
            end
            button.classID=classID;button.label:SetText(groups[classID].name.." ("..#groups[classID].items..")");button:Show()
        end
        self.categoryContent:SetHeight(math.max(1,#order*29))
        for _,slot in ipairs(self.slots)do slot:Hide()end
        for _,heading in ipairs(self.headers)do heading:Hide()end
        local y,index,section,total=0,0,0,0
        for _,classID in ipairs(order)do
            if not self.category or self.category==classID then
                local group=groups[classID];section=section+1
                local title=Title(section);title:ClearAllPoints();title:SetPoint("TOPLEFT",0,-y);title.text:SetText(group.name.." ("..#group.items..")");title:Show();y=y+27
                for position,item in ipairs(group.items)do
                    index=index+1;total=total+item.count
                    local slot=Slot(index);slot.item=item;slot:ClearAllPoints()
                    slot:SetPoint("TOPLEFT",((position-1)%COLS)*STEP,-y-math.floor((position-1)/COLS)*STEP)
                    slot.icon:SetTexture(item.icon);slot.count:SetText(item.count>1 and tostring(item.count)or"")
                    local r,g,b=0.22,0.22,0.22
                    if item.quality>1 then r,g,b=C_Item.GetItemQualityColor(item.quality)end
                    slot:SetBackdropBorderColor(r,g,b,1);slot:Show()
                end
                y=y+math.ceil(#group.items/COLS)*STEP+10
            end
        end
        self.content:SetHeight(math.max(1,y))
        self.summary:SetText(index==0 and L("No matching items")or L("%d item types / %d items - identical items are combined",index,total))
    end
    if skin then skin.Shell(view,{bottomBar=34})end
    view:Hide()
end
function ns.OpenInventoryGrid(key)
    if not ns.IsInventoryEnabled() then return end
    if not view then Build()end
    local keys=Keys();view.key=key and Records()[key]and key or view.key or keys[1]
    view.category=nil;view.search:SetText("");ScrollToTop();view:Show();view:Refresh();view:Raise()
end
function ns.RefreshInventoryView()if view and view:IsShown()then view:Refresh()end end
local attached
local function AttachButton()
    local bag=_G.EUI_MainBagFrame
    if not bag then return end
    if not attached then attached=true;bag:HookScript("OnShow",function()AttachButton()end)end
    if launcher then launcher:SetShown(ns.IsInventoryEnabled());return end
    if not ns.IsInventoryEnabled() then return end
    local header=bag.Header
    if not header then return end
    launcher=Button(header,L("Offline Bank"),0,0,88,function()ns.OpenInventory()end)
    launcher:ClearAllPoints()
    if header.itemCount then launcher:SetPoint("LEFT",header.itemCount,"RIGHT",10,0)
    else launcher:SetPoint("LEFT",header,"LEFT",172,0)end
    launcher:SetSize(88,23);launcher:SetFrameLevel(header:GetFrameLevel()+5)
    launcher:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:SetText(L("Offline Bank"));GameTooltip:AddLine(L("Browse saved bags and banks for your characters."),1,1,1,true);GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave",function()GameTooltip:Hide()end)
end
function ns.RefreshInventoryFeature()
    AttachButton()
    if view and not ns.IsInventoryEnabled() then view:Hide() end
    if ns.IsInventoryEnabled() and ns.RequestInventorySnapshot then ns.RequestInventorySnapshot() end
end
if EUI and EUI.RegisterSkin then
    EUI.RegisterSkin("BelToolbox",function(S)
        skin=S;ns.skin=S
        if ns.RefreshMerchantSkin then ns.RefreshMerchantSkin(S)end
        if view then S.Shell(view,{bottomBar=34})end
        for _,entry in ipairs(controls)do if S[entry.kind]then S[entry.kind](entry.frame)end end
    end)
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN");events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function()AttachButton()end)