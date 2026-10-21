-- Original, event-driven consumable bar. Only inventory data and documented
-- item/spell APIs are used; no third-party implementation or artwork is bundled.
local _,ns=...
local L,T=ns.L,ns.Toolbars
local F=ns.ConsumableFlyouts
local root,dirty,queued
local buttons,lists={},{}
local categories={
    {key="food",label="Food",icon=133906},{key="drink",label="Drink",icon=132794},
    {key="healing",label="Healing potion",icon=134829},{key="mana",label="Mana potion",icon=134852},
    {key="stone",label="Healthstone",icon=135230},{key="gem",label="Mana gem",icon=134134},
    {key="bandage",label="Bandage",icon=133682},
    {key="flask",label="Flasks",icon=134828},
    {key="elixir",label="Elixirs",icon=134842},
    {key="protection",label="Resistance potions",icon=134804},
}
ns.ConsumableCategories=categories
local C={};ns.Consumables=C
function C.Settings()return T.Settings("consumables")end
local function Safe(value)return not(issecretvalue and issecretvalue(value))end
local function API(name,...)local fn=C_Item and C_Item[name]or _G[name];if fn then return fn(...)end end
local specials={}
for _,id in ipairs({5512,5511,5509,5510,9421,19004,19005,19006,19007,19008,19009,19010,19011,19012,19013})do specials[id]="stone"end
for _,id in ipairs({5514,5513,8007,8008})do specials[id]="gem"end
-- Known classic items also cover older client records with a generic subclass.
for _,id in ipairs({13510,13511,13512,13513,13506})do specials[id]="flask"end
for _,id in ipairs({13452,13454,9179,20007,13445,9206,9187,8951,9155,6373})do specials[id]="elixir"end
local resistanceItems={6049,13457,6050,13456,6052,13458,6048,13459,13461,6051,9036}
for _,id in ipairs(resistanceItems)do specials[id]="protection"end
-- Quest-reward cooked food can use a different Food spell / generic subclass.
specials[733]="food" -- Westfall Stew
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
    if Safe(class)and Safe(subclass)and class==0 then
        if subclass==3 then return "flask"end
        if subclass==2 then return "elixir"end
        if subclass==1 and spell then
            -- Names from the client's own use spells keep this locale-neutral
            -- and recognize other ranks sharing a known resistance effect.
            for _,reference in ipairs(resistanceItems)do
                local name=API("GetItemSpell",reference)
                if name and Safe(name)and spell==name then return "protection"end
            end
        end
        if subclass==7 then return "bandage"end
        -- Drinks are matched by their localized use spell above. Cooked/buff
        -- foods can have different use spells, but still belong in the picker.
        if subclass==5 then return "food"end
    end
end
function C.Ordered()
    local result,seen={},{}
    local byKey={};for _,category in ipairs(categories)do byKey[category.key]=category end
    for _,key in ipairs(C.Settings().order or {})do
        if byKey[key]and not seen[key]then result[#result+1]=byKey[key];seen[key]=true end
    end
    for _,category in ipairs(categories)do if not seen[category.key]then result[#result+1]=category end end
    return result
end
function C.GetOrder(key)
    for index,category in ipairs(C.Ordered())do if category.key==key then return index end end
end
function C.SetOrder(key,index)
    local ordered=C.Ordered();local previous=C.GetOrder(key)
    if not previous then return end
    local category=table.remove(ordered,previous)
    table.insert(ordered,math.max(1,math.min(#ordered+1,tonumber(index)or previous)),category)
    local order={};for _,entry in ipairs(ordered)do order[#order+1]=entry.key end
    C.Settings().order=order;ns.RefreshConsumables()
end
function C.Layout(visible)
    local db=C.Settings();local size=T.Size("consumables")
    local gap=math.max(0,math.min(16,tonumber(db.spacing)or 2))
    local perLine=math.max(1,math.min(#categories,math.floor(tonumber(db.perLine)or 7)))
    local rows,columns=1,1
    for index,button in ipairs(visible)do
        local along=(index-1)%perLine;local across=math.floor((index-1)/perLine)
        local column=along
        local row=across
        button:ClearAllPoints();button:SetSize(size,size)
        button:SetPoint("TOPLEFT",root,"TOPLEFT",column*(size+gap),-row*(size+gap));button:Show()
        columns=math.max(columns,column+1);rows=math.max(rows,row+1)
    end
    root:SetSize(columns*(size+gap)-gap,rows*(size+gap)-gap)
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
                if cat and Count(id)>0 then
                    local name,_,_,itemLevel,minLevel,_,_,_,_,icon=API("GetItemInfo",id)
                    if name and Safe(minLevel)and Safe(itemLevel)and (minLevel or 0)<=level then
                        local _,spellID=API("GetItemSpell",id)
                        local description=spellID and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID)
                        local wellFed=C_Spell.GetSpellName and C_Spell.GetSpellName(19705)
                        local buff=type(description)=="string"and wellFed and description:find(wellFed,1,true)
                        lists[cat][#lists[cat]+1]={id=id,name=name,icon=icon,level=minLevel or 0,rank=itemLevel or 0,
                            temporary=conjured[id]or false,manual=cat=="flask"or cat=="elixir"or cat=="protection"
                                or (cat=="food"or cat=="drink")and (buff or not(conjured[id]or plain[id]))or false}
                    elseif not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id)end
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
    F.VisitItems(function(button)
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
    end)
end
local function Tooltip(button)
    GameTooltip:SetOwner(button,"ANCHOR_TOP")
    if button.itemID then GameTooltip:SetItemByID(button.itemID)else GameTooltip:SetText(L(button.category.label))end
    GameTooltip:AddLine(L("Hover to expand. Left-click an item to use it; right-click to set the default."),1,.82,.3,true)
    if button.flyout then GameTooltip:AddLine(L(button.manual and "Manual selection"or "Automatic selection"),.4,.8,1,true)end
    local available=#(lists[button.category.key]or {})
    if not button.itemID and available>0 then
        GameTooltip:AddLine(L("%d choices available. Hover to select; buff consumables require a manual choice.",available),1,.82,.3,true)
    end
    GameTooltip:AddLine(L("Bag changes update the choices after combat; existing choices remain usable."),.7,.7,.7,true)
    if button.flyout then GameTooltip:AddLine(L("Use the Auto button in the flyout to restore automatic selection."),.4,.8,1,true)end
    GameTooltip:Show()
end
local function Create()
    root=CreateFrame("Frame","BelToolboxConsumables",UIParent);root:SetFrameStrata("MEDIUM")
    root._belAfterPosition=F.PositionAll
    T.Mover(root,"consumables","Consumables",955,DefaultPosition)
    for _,category in ipairs(categories)do
        local button=F.Create(root,"BelToolboxConsume"..category.key,category.icon)
        button.category=category;buttons[category.key]=button
        button:RegisterForClicks("AnyUp","AnyDown")
        button:SetAttribute("type1","item");button:SetAttribute("type2",nil)
        button.hotkey=button:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall");button.hotkey:SetPoint("TOPRIGHT",-1,-1)
        button.arrow=button:CreateTexture(nil,"OVERLAY");button.arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
        button.arrow:SetSize(12,12);button.arrow:SetPoint("BOTTOMLEFT",0,0);button.arrow:SetVertexColor(1,.82,0)
        button:HookScript("OnEnter",Tooltip);button:HookScript("OnLeave",function()GameTooltip:Hide()end)
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
        F.CloseAll()
        return
    end
    if not root then Create()end
    C.Scan();local choices=Choices();local visible={}
    for _,category in ipairs(C.Ordered())do
        local button=buttons[category.key];local chosen,manual=C.Resolve(lists[category.key],choices[category.key])
        button.itemID=chosen and chosen.id;button.manual=manual
        local available=#lists[category.key]
        local enabled=(not db.categories or db.categories[category.key]~=false)
            and (not db.hideEmpty or available>0 or ns.IsToolbarBindingMode())
        button:SetAttribute("item1",enabled and chosen and "item:"..chosen.id or nil)
        button.icon:SetTexture(chosen and chosen.icon or available>0 and lists[category.key][1].icon or category.icon)
        button.arrow:SetShown(available>0)
        local automatic=C.Resolve(lists[category.key],nil)
        F.SetItems(button,lists[category.key],automatic,Tooltip,function(id)
            Choices()[category.key]=id
            if InCombatLockdown()then
                button.itemID=id or button.autoItemID;button.manual=id~=nil
                local icon=button.autoIcon or category.icon
                for _,entry in ipairs(lists[category.key])do if entry.id==button.itemID then icon=entry.icon;break end end
                button.icon:SetTexture(icon)
                UpdateVisuals()
            else ns.RefreshConsumables()end
        end,enabled and not ns.IsToolbarBindingMode())
        if enabled then visible[#visible+1]=button else button:Hide()end
    end
    C.Layout(visible);T.Position(root,"consumables",DefaultPosition)
    root:SetFrameStrata(ns.IsToolbarBindingMode()and "DIALOG"or "MEDIUM")
    root:SetShown(#visible>0);root.RegisterBelMover();UpdateVisuals();ns.UpdateToolbarBindings()
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","BAG_UPDATE_DELAYED","SPELL_UPDATE_COOLDOWN","BAG_UPDATE_COOLDOWN","ITEM_DATA_LOAD_RESULT","PLAYER_LEVEL_UP"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,_,success)
    if event=="SPELL_UPDATE_COOLDOWN"or event=="BAG_UPDATE_COOLDOWN"then if root and root:IsShown()then UpdateVisuals()end;return end
    if event=="PLAYER_REGEN_DISABLED"then return end
    if event=="ITEM_DATA_LOAD_RESULT"and not success then return end
    if C.Settings().enabled~=true and not root then return end
    if queued then return end
    queued=true;C_Timer.After(0,function()queued=nil;ns.RefreshConsumables()end)
end)
