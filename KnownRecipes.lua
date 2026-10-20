-- Recipes are identified by item class and the client's own localized learned-spell text.
local _,ns=...
local cache,pending={},setmetatable({},{__mode="k"})
local changed=setmetatable({},{__mode="k"})
local requested={}
local overlays=setmetatable({},{__mode="k"})
ns.KnownRecipeOverlays=overlays
local tip,queued
local function Safe(value)return not (issecretvalue and issecretvalue(value))end
function ns.IsKnownRecipe(item)
    if not item or not Safe(item)then return false end
    local instant=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not instant then return false end
    local id,_,_,_,_,class=instant(item)
    if not id or not Safe(id)or class~=9 then return false end
    if cache[id]~=nil then return cache[id]end
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not info(id)then
        requested[id]=true
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id)end
        return false
    end
    local known=false
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local data=C_TooltipInfo.GetItemByID(id)
        if not data or not data.lines then return false end
        for _,line in ipairs(data.lines)do if Safe(line.leftText)and line.leftText==ITEM_SPELL_KNOWN then known=true;break end end
    else
        tip=tip or CreateFrame("GameTooltip","BelToolboxRecipeScan",UIParent,"GameTooltipTemplate")
        tip:SetOwner(UIParent,"ANCHOR_NONE");tip:SetHyperlink("item:"..id)
        for i=2,tip:NumLines()do
            local line=_G["BelToolboxRecipeScanTextLeft"..i]
            if line and line:GetText()==ITEM_SPELL_KNOWN then known=true;break end
        end
        tip:Hide()
    end
    cache[id]=known;return known
end
local function ItemOf(button)
    if button.GetBagID and button.GetID and C_Container then
        local bag,slot=button:GetBagID(),button:GetID()
        if type(bag)=="number"and type(slot)=="number"and slot>0 then return C_Container.GetContainerItemLink(bag,slot)end
    end
    if button.link or button.itemLink or button.itemID then return button.link or button.itemLink or button.itemID end
    return button.link or button.itemLink or button.itemID
end
local function Paint(button,item)
    if not button or button.IsForbidden and button:IsForbidden()then return end
    local icon=button.icon or button.Icon or button.IconTexture or(button.GetName and button:GetName()and _G[button:GetName().."IconTexture"])
    if not icon or not button.CreateTexture then return end
    local known=ns.GetEnhancements().knownRecipes~=false and ns.IsKnownRecipe(item)
    local record=overlays[button]
    if known and not record then
        local parent=button._textOverlay or button
        local overlay=parent:CreateTexture(nil,"OVERLAY")
        overlay:SetAllPoints(icon);overlay:SetColorTexture(0,.9,.15,.32)
        local check=parent:CreateTexture(nil,"OVERLAY",nil,2)
        check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready");check:SetSize(13,13);check:SetPoint("TOPRIGHT",icon,"TOPRIGHT",1,1)
        record={tint=overlay,check=check};overlays[button]=record
    end
    if record then record.tint:SetShown(known);record.check:SetShown(known)end
    pending[button]=item or true
end
ns.PaintKnownRecipe=Paint
local function QueueButton(button)
    if type(button)~="table"and type(button)~="userdata"then return end
    pending[button]=true
    changed[button]=true
    if queued then return end
    queued=true
    C_Timer.After(0,function()
        queued=nil
        for b in pairs(changed)do
            changed[b]=nil
            if b.IsShown and b:IsShown()then Paint(b,ItemOf(b)or(pending[b]~=true and pending[b]or nil))end
        end
    end)
end
local hooked={}
function ns.RefreshKnownRecipes(invalidate)
    if invalidate~=false then wipe(cache)end
    for _,name in ipairs({"SetItemButtonTexture","MerchantFrame_UpdateMerchantInfo"})do
        if not hooked[name]and type(_G[name])=="function"then
            hooked[name]=true
            if name=="SetItemButtonTexture"then hooksecurefunc(name,QueueButton)
            else hooksecurefunc(name,function()ns.RefreshKnownRecipeSurfaces()end)end
        end
    end
    for _,mixin in ipairs({ItemButtonMixin or {},ContainerFrameItemButtonMixin or {}})do
        if type(mixin.SetItemButtonTexture)=="function"and not hooked[mixin]then
            hooked[mixin]=true;hooksecurefunc(mixin,"SetItemButtonTexture",QueueButton)
        end
    end
    local bags=_G.EUI_Bags
    if bags and bags.RegisterItemOverlayIcon and not hooked[bags]then
        hooked[bags]=true
        bags.RegisterItemOverlayIcon("BelToolboxKnownRecipes",function(button,data)
            Paint(button,data.itemLink or(data.info and data.info.itemID))
        end)
        if bags:IsShown()and bags.RefreshInventory and not InCombatLockdown()then bags:RefreshInventory()end
    end
    ns.RefreshKnownRecipeSurfaces()
    for b in pairs(pending)do if b.IsShown and b:IsShown()then Paint(b,ItemOf(b)or(pending[b]~=true and pending[b]or nil))end end
end
function ns.RefreshKnownRecipeSurfaces()
    if MerchantFrame and MerchantFrame:IsShown()and MerchantFrame.selectedTab~=2 then
        for i=1,MERCHANT_ITEMS_PER_PAGE or 10 do
            local b=_G["MerchantItem"..i.."ItemButton"]
            if b and b:IsShown()then Paint(b,b.link or GetMerchantItemLink(((MerchantFrame.page or 1)-1)*(MERCHANT_ITEMS_PER_PAGE or 10)+i))end
        end
    end
    local bank=_G.GuildBankFrame
    if bank and bank.Update and not hooked[bank]then
        hooked[bank]=true;hooksecurefunc(bank,"Update",ns.RefreshKnownRecipeSurfaces)
    end
    if bank and bank:IsShown()and bank.mode=="bank"and bank.Columns and GetGuildBankItemLink then
        local tab=GetCurrentGuildBankTab()
        for column,group in ipairs(bank.Columns)do
            for index,button in ipairs(group.Buttons or {})do
                Paint(button,GetGuildBankItemLink(tab,(column-1)*(NUM_SLOTS_PER_GUILDBANK_GROUP or 14)+index))
            end
        end
    end
    local scroll=AuctionHouseFrame and AuctionHouseFrame.BrowseResultsFrame and AuctionHouseFrame.BrowseResultsFrame.ItemList and AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox
    if scroll then
        if not hooked[scroll]then hooked[scroll]=true;hooksecurefunc(scroll,"Update",ns.RefreshKnownRecipeSurfaces)end
        for _,row in ipairs(scroll:GetFrames()or {})do
            for _,cell in ipairs(row.cells or {})do
                local key=cell.rowData and cell.rowData.itemKey
                if cell.Icon then Paint(cell,key and key.itemID)end
            end
        end
    end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","BAG_UPDATE_DELAYED","SPELLS_CHANGED","SKILL_LINES_CHANGED","GET_ITEM_INFO_RECEIVED","MERCHANT_SHOW","AUCTION_HOUSE_SHOW","GUILDBANKBAGSLOTS_CHANGED"})do events:RegisterEvent(event)end
local scheduled,invalidateAll
events:SetScript("OnEvent",function(_,event,itemID)
    if event=="GET_ITEM_INFO_RECEIVED"then
        if not requested[itemID]then return end
        requested[itemID]=nil;cache[itemID]=nil
    elseif event=="ADDON_LOADED"then
        local relevant={EllesmereUIBags=true,Blizzard_ContainerUI=true,Blizzard_AuctionHouseUI=true,Blizzard_GuildBankUI=true,Blizzard_MerchantUI=true}
        if not relevant[itemID]then return end
    elseif event=="PLAYER_LOGIN"or event=="SPELLS_CHANGED"or event=="SKILL_LINES_CHANGED"then
        invalidateAll=true
    end
    if scheduled then return end
    scheduled=true;C_Timer.After(.1,function()
        scheduled=nil;local invalidate=invalidateAll or false;invalidateAll=nil
        ns.RefreshKnownRecipes(invalidate)
    end)
end)
