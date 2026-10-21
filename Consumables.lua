-- Original, event-driven consumable bar. Only inventory data and documented
-- item/spell APIs are used; no third-party implementation or artwork is bundled.
local _,ns=...
local L,T=ns.L,ns.Toolbars
local root,popup,dirty,queued
local buttons,lists={},{}
local categories={
    {key="food",label="Food",icon=133906},{key="drink",label="Drink",icon=132794},
    {key="healing",label="Healing potion",icon=134829},{key="mana",label="Mana potion",icon=134852},
    {key="stone",label="Healthstone",icon=135230},{key="gem",label="Mana gem",icon=134134},
    {key="bandage",label="Bandage",icon=133682},
}
ns.ConsumableCategories=categories
local C={};ns.Consumables=C
function C.Settings()return T.Settings("consumables")end
local function Safe(value)return not(issecretvalue and issecretvalue(value))end
local function API(name,...)local fn=C_Item and C_Item[name]or _G[name];if fn then return fn(...)end end
local specials={}
for _,id in ipairs({5512,5511,5509,5510,9421,19004,19005,19006,19007,19008,19009,19010,19011,19012,19013})do specials[id]="stone"end
for _,id in ipairs({5514,5513,8007,8008})do specials[id]="gem"end
local conjured={}
for _,id in ipairs({5349,1113,1114,1487,8075,8076,22895,5350,2288,2136,3772,8077,8078,8079})do conjured[id]=true end
local plain={}
for _,id in ipairs({117,2287,3770,3771,4599,8952,4540,4541,4542,4544,4601,8950,159,1179,1205,1708,1645,8766})do plain[id]=true end
local references={{433,"food"},{430,"drink"},{441,"healing"},{437,"mana"},{746,"bandage"}}
function C.Classify(id)
    if specials[id]then return specials[id]end
    local spell=API("GetItemSpell",id)
    if not Safe(spell)then return end
    for _,entry in ipairs(references)do
        local name=C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(entry[1])
        if name and spell==name then return entry[2]end
    end
    local _,_,_,_,_,class,subclass=API("GetItemInfoInstant",id)
    if Safe(class)and Safe(subclass)and class==0 and subclass==7 then return "bandage"end
end
local function Character()
    local name,realm=UnitFullName("player")
    return (name or UnitName("player")).."-"..(realm and realm~=""and realm or GetRealmName())
end
local function Choices()
    local db=C.Settings();db.choices=db.choices or {}
    local key=Character();db.choices[key]=db.choices[key]or {};return db.choices[key]
end
local function Count(id)
    local n=id and API("GetItemCount",id,false,false,false)or 0
    return Safe(n)and type(n)=="number"and n or 0
end
local function DefaultPosition()return {point="CENTER",relPoint="CENTER",x=0,y=-205}end
function C.Scan()
    lists={};for _,category in ipairs(categories)do lists[category.key]={}end
    local seen={}
    local level=UnitLevel("player")
    for bag=0,NUM_BAG_SLOTS or 4 do
        for slot=1,C_Container.GetContainerNumSlots(bag)do
            local id=C_Container.GetContainerItemID(bag,slot)
            if Safe(id)and id and not seen[id]then
                seen[id]=true
                local cat=C.Classify(id)
                if cat then
                    local name,_,_,itemLevel,minLevel,_,_,_,_,icon=API("GetItemInfo",id)
                    if name and Safe(minLevel)and Safe(itemLevel)and (minLevel or 0)<=level then
                        local _,spellID=API("GetItemSpell",id)
                        local description=spellID and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID)
                        local wellFed=C_Spell.GetSpellName and C_Spell.GetSpellName(19705)
                        local buff=type(description)=="string"and wellFed and description:find(wellFed,1,true)
                        lists[cat][#lists[cat]+1]={id=id,name=name,icon=icon,level=minLevel or 0,rank=itemLevel or 0,
                            temporary=conjured[id]or false,manual=(cat=="food"or cat=="drink")and (buff or not(conjured[id]or plain[id]))or false}
                    elseif C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id)end
                elseif C_Item and C_Item.RequestLoadItemDataByID and not API("GetItemInfo",id)then C_Item.RequestLoadItemDataByID(id)end
            end
        end
    end
    for _,list in pairs(lists)do table.sort(list,function(a,b)
        if a.temporary~=b.temporary then return a.temporary end
        if a.level~=b.level then return a.level>b.level end
        if a.rank~=b.rank then return a.rank>b.rank end
        return a.id<b.id
    end)end
    return lists
end
function C.Resolve(list,chosen)
    for _,entry in ipairs(list)do if entry.id==chosen and Count(entry.id)>0 then return entry,true end end
    for _,entry in ipairs(list)do if not entry.manual and Count(entry.id)>0 then return entry,false end end
end
local function UpdateVisuals()
    local cooldowns={}
    if root and not(C_Item and C_Item.GetItemCooldown)and not _G.GetItemCooldown then
        for bag=0,NUM_BAG_SLOTS or 4 do
            for slot=1,C_Container.GetContainerNumSlots(bag)do
                local id=C_Container.GetContainerItemID(bag,slot)
                if Safe(id)and id then
                    local start,duration=C_Container.GetContainerItemCooldown(bag,slot)
                    if Safe(start)and Safe(duration)and type(start)=="number"and type(duration)=="number"then cooldowns[id]={start,duration}end
                end
            end
        end
    end
    for _,button in pairs(buttons)do
        local count=Count(button.itemID)
        button.count:SetText(count>0 and tostring(count)or "")
        button.icon:SetDesaturated(count==0)
        if button.itemID then
            local start,duration,enabled=API("GetItemCooldown",button.itemID)
            if cooldowns[button.itemID]then start,duration=unpack(cooldowns[button.itemID])end
            if Safe(start)and Safe(duration)and type(start)=="number"and type(duration)=="number"then
                button.cooldown:SetCooldown(start,duration)
            else button.cooldown:Clear()end
        else button.cooldown:Clear()end
    end
end
local function Pick(button)
    if InCombatLockdown()or ns.IsToolbarBindingMode()then return end
    C.Scan()
    if not popup then
        popup=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");popup:SetFrameStrata("TOOLTIP")
        popup:SetSize(285,320);popup:SetClampedToScreen(true);popup:EnableMouse(true)
        popup:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        popup:SetBackdropColor(.06,.07,.09,.98);popup:SetBackdropBorderColor(.5,.5,.5,1)
        popup.rows={}
        for i=1,11 do
            local row=CreateFrame("Button",nil,popup);row:SetSize(269,24);row:SetPoint("TOPLEFT",8,-8-(i-1)*26)
            row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");row.text:SetAllPoints();row.text:SetJustifyH("LEFT")
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row:SetScript("OnClick",function(self)
                if InCombatLockdown()then return end
                Choices()[popup.category]=self.itemID;popup:Hide();ns.RefreshConsumables()
            end)
            popup.rows[i]=row
        end
        local function Nav(text,x,step)
            local b=CreateFrame("Button",nil,popup,"UIPanelButtonTemplate");b:SetSize(75,22);b:SetPoint("BOTTOMLEFT",x,5);b:SetText(text)
            b:SetScript("OnClick",function()popup.page=math.max(1,popup.page+step);popup:Paint()end)
        end
        Nav("<",8,-1);Nav(">",92,1)
        local close=CreateFrame("Button",nil,popup,"UIPanelButtonTemplate");close:SetSize(75,22);close:SetPoint("BOTTOMRIGHT",-8,5);close:SetText(CLOSE)
        close:SetScript("OnClick",function()popup:Hide()end)
        function popup:Paint()
            local list=lists[self.category]or {};self.page=math.min(self.page,math.max(1,math.ceil(#list/10)))
            self.rows[1].itemID=nil;self.rows[1].text:SetText(L("Automatic selection"));self.rows[1]:Show()
            for i=2,11 do
                local entry=list[(self.page-1)*10+i-1];local row=self.rows[i]
                row:SetShown(entry~=nil)
                if entry then row.itemID=entry.id;row.text:SetText(entry.name.."  x"..Count(entry.id))end
            end
        end
    end
    popup.category=button.category.key;popup.page=1;popup:ClearAllPoints();popup:SetPoint("BOTTOMLEFT",button,"TOPLEFT",0,5);popup:Paint();popup:Show()
end
local function Tooltip(button)
    GameTooltip:SetOwner(button,"ANCHOR_TOP")
    if button.itemID then GameTooltip:SetItemByID(button.itemID)else GameTooltip:SetText(L(button.category.label))end
    GameTooltip:AddLine(L("Left-click to use. Right-click to choose an item."),1,.82,.3,true)
    GameTooltip:AddLine(L(button.manual and "Manual selection"or "Automatic selection"),.4,.8,1,true)
    GameTooltip:AddLine(L("In combat, item changes wait until combat ends."),.7,.7,.7,true)
    GameTooltip:Show()
end
local function Create()
    root=CreateFrame("Frame","BelToolboxConsumables",UIParent);root:SetFrameStrata("MEDIUM")
    T.Mover(root,"consumables","Consumables",955,DefaultPosition)
    for _,category in ipairs(categories)do
        local button=T.Button(root,"BelToolboxConsume"..category.key,true,nil,category.icon)
        button.category=category;buttons[category.key]=button
        button:RegisterForClicks("AnyUp","AnyDown")
        button:SetAttribute("type1","item");button:SetAttribute("type2",nil)
        button.count=button:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall");button.count:SetPoint("BOTTOMRIGHT",-1,1)
        button.hotkey=button:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall");button.hotkey:SetPoint("TOPRIGHT",-1,-1)
        button.cooldown=CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate");button.cooldown:SetAllPoints(button)
        button:SetScript("OnEnter",Tooltip);button:SetScript("OnLeave",function()GameTooltip:Hide()end)
        button:SetScript("PostClick",function(self,key,down)if key=="RightButton"and not down then Pick(self)end end)
        ns.RegisterToolbarBinding(button,L(category.label))
    end
end
function ns.RefreshConsumables()
    if InCombatLockdown()then dirty=true;UpdateVisuals();return end
    dirty=nil
    local db=C.Settings()
    if db.enabled~=true then
        if root then
            for _,button in pairs(buttons)do button:SetAttribute("item1",nil);button.itemID=nil end
            root:Hide()
        end
        if popup then popup:Hide()end
        return
    end
    if not root then Create()end
    C.Scan();local choices=Choices();local visible={}
    for _,category in ipairs(categories)do
        local button=buttons[category.key];local chosen,manual=C.Resolve(lists[category.key],choices[category.key])
        button.itemID=chosen and chosen.id;button.manual=manual
        local enabled=not db.categories or db.categories[category.key]~=false
        button:SetAttribute("item1",enabled and chosen and "item:"..chosen.id or nil)
        button.icon:SetTexture(chosen and chosen.icon or category.icon)
        if enabled then visible[#visible+1]=button else button:Hide()end
    end
    T.Layout(root,visible,"consumables");T.Position(root,"consumables",DefaultPosition)
    root:SetFrameStrata(ns.IsToolbarBindingMode()and "DIALOG"or "MEDIUM")
    root:SetShown(#visible>0);root.RegisterBelMover();UpdateVisuals();ns.UpdateToolbarBindings()
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","BAG_UPDATE_DELAYED","SPELL_UPDATE_COOLDOWN","BAG_UPDATE_COOLDOWN","ITEM_DATA_LOAD_RESULT","PLAYER_LEVEL_UP"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,_,success)
    if event=="SPELL_UPDATE_COOLDOWN"or event=="BAG_UPDATE_COOLDOWN"then if root and root:IsShown()then UpdateVisuals()end;return end
    if event=="PLAYER_REGEN_DISABLED"then if popup then popup:Hide()end;return end
    if event=="ITEM_DATA_LOAD_RESULT"and not success then return end
    if C.Settings().enabled~=true and not root then return end
    if queued then return end
    queued=true;C_Timer.After(0,function()queued=nil;ns.RefreshConsumables()end)
end)
