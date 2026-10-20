local _, ns = ...
local L = ns.L
local bankOpen, queued
local bankSession=0
local hookedWindows=setmetatable({},{__mode="k"})
local currentKey
local function Store()
    local db = ns.GetSettings()
    db.inventory = db.inventory or { characters={} }
    db.inventory.characters = db.inventory.characters or {}
    return db.inventory
end
ns.GetInventoryStore = Store
function ns.IsInventoryEnabled() return ns.GetSettings().offlineInventoryEnabled ~= false end
function ns.GetCharacterColor(record)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and record and record.class and colors[record.class]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end
local function Identity()
    local name, realm = UnitFullName("player")
    realm = realm and realm ~= "" and realm or GetRealmName()
    return name .. "-" .. realm, name, realm
end
local function Character()
    local key, name, realm = Identity()
    currentKey = key
    local characters = Store().characters
    characters[key] = characters[key] or {}
    local record = characters[key]
    record.name, record.realm = name, realm
    record.faction = UnitFactionGroup("player")
    record.class = select(2, UnitClass("player"))
    return record
end
local function ScanBag(bag)
    local slots = C_Container.GetContainerNumSlots(bag)
    if not slots or slots <= 0 then return end
    local items = {}
    for slot=1,slots do
        local item = C_Container.GetContainerItemInfo(bag,slot)
        if item and item.itemID and not (issecretvalue and issecretvalue(item.itemID)) then
            local entry = items[item.itemID]
            if not entry then entry={count=0,link=item.hyperlink}; items[item.itemID]=entry end
            entry.count=entry.count+(item.stackCount or 1)
        end
    end
    return items
end
local function Merge(bags)
    local items={}
    for _, bag in pairs(bags) do
        for id, entry in pairs(bag) do
            local value=items[id]
            if not value then value={count=0,link=entry.link}; items[id]=value end
            value.count=value.count+entry.count
        end
    end
    return items
end
local function BankBags()
    local result={}
    for index=1,9 do
        local bag=Enum.BagIndex and Enum.BagIndex["CharacterBankTab_"..index]
        if bag then result[#result+1]=bag end
    end
    if #result==0 then
        result[1]=BANK_CONTAINER or -1
        for index=1,(NUM_BANKBAGSLOTS or 7) do result[#result+1]=(NUM_BAG_SLOTS or 4)+index end
        if REAGENTBANK_CONTAINER then result[#result+1]=REAGENTBANK_CONTAINER end
    end
    return result
end
local function Snapshot()
    local record=Character()
    local bags={}
    local last=Enum.BagIndex and Enum.BagIndex.ReagentBag or NUM_BAG_SLOTS or 4
    local backpack=ScanBag(0)
    for bag=0,last do bags[bag]=bag==0 and backpack or ScanBag(bag) or {} end
    if Enum.BagIndex and Enum.BagIndex.Keyring then bags.keyring=ScanBag(Enum.BagIndex.Keyring) or {} end
    -- At early login the backpack itself can still be unavailable. Keep the last snapshot until it is readable.
    if backpack then record.bags=Merge(bags); record.bagsAt=time()end
    if bankOpen and ns.IsInventoryEnabled() then
        local bankBags=record.bankBags or {}
        local readable=false
        for _,bag in ipairs(BankBags()) do
            local scanned=ScanBag(bag)
            if scanned then bankBags[bag]=scanned; readable=true end
        end
        if readable then
            record.bankBags=bankBags; record.bank=Merge(bankBags); record.bankAt=time()
        end
    end
    if ns.RefreshInventoryView then ns.RefreshInventoryView() end
end
local function Schedule()
    if queued then return end
    queued=true
    C_Timer.After(0.25,function() queued=nil; Snapshot() end)
end
ns.RequestInventorySnapshot = Schedule
local function Count(items,id) return items and items[id] and items[id].count or 0 end
local function Stamp(value) return value and date("%m-%d %H:%M",value) or L("Not recorded") end

-- Small native-style windows shared with the mail contact picker.
ns.ToolsUI = {}
function ns.ToolsUI.Label(parent,x,y,width,font)
    local text=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    text:SetPoint("TOPLEFT",x,y); text:SetWidth(width); text:SetJustifyH("LEFT")
    return text
end
function ns.ToolsUI.Button(parent,text,x,y,width,callback)
    local button=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    button:SetSize(width,24); button:SetPoint("TOPLEFT",x,y); button:SetText(text); button:SetScript("OnClick",callback)
    return button
end
function ns.ToolsUI.Window(name,title,width,height)
    local frame=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
    frame:SetSize(width,height); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(0.05,0.06,0.08,0.98); frame:SetBackdropBorderColor(0.29,0.8,1)
    frame:EnableMouse(true); frame:SetMovable(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
    ns.ToolsUI.Label(frame,14,-12,width-50,"GameFontNormalLarge"):SetText(title)
    local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",0,0)
    tinsert(UISpecialFrames,name)
    frame:Hide()
    return frame
end
function ns.OpenInventory()
    if not ns.IsInventoryEnabled() then return end
    if ns.OpenInventoryGrid then ns.OpenInventoryGrid(currentKey or Identity()) end
end
SLASH_BELBANK1="/belbank"
SlashCmdList.BELBANK=function()ns.OpenInventory()end
local function AddOwnedCounts(tooltip,data)
    if ns.GetSettings().ownedCounts==false or not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local id=data and data.id
    if (issecretvalue and issecretvalue(id))or type(id)~="number" then return end
    local name=tooltip.GetName and tooltip:GetName()
    if not name then return end
    local heading=L("Owned items (bank snapshots)")
    for line=1,tooltip:NumLines()do
        local fs=_G[name.."TextLeft"..line];local text=fs and fs:GetText()
        if text and not(issecretvalue and issecretvalue(text))and text==heading then return end
    end
    local keys={}
    for key,record in pairs(Store().characters)do
        if Count(record.bags,id)+Count(record.bank,id)>0 or key==currentKey then keys[#keys+1]=key end
    end
    if #keys==0 then return end
    table.sort(keys,function(a,b)if a==b then return false elseif a==currentKey then return true elseif b==currentKey then return false else return a<b end end)
    tooltip:AddLine(" ");tooltip:AddLine(heading,0.29,0.8,1)
    for index=1,math.min(#keys,10)do
        local key=keys[index];local record=Store().characters[key]
        local r,g,b=ns.GetCharacterColor(record)
        tooltip:AddDoubleLine(key,L("Bags %d / Bank %s",Count(record.bags,id),record.bankAt and tostring(Count(record.bank,id))or"?"),r,g,b,0.8,0.8,0.8)
    end
    if #keys>10 then tooltip:AddLine(L("%d more characters - /belbank",#keys-10),0.7,0.7,0.7)end
end
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,AddOwnedCounts)
local function IsAccountBankOnly()
    local api=C_PlayerInteractionManager
    local kind=Enum.PlayerInteractionType and Enum.PlayerInteractionType.AccountBanker
    return api and api.IsInteractingWithNpcOfType and kind and api.IsInteractingWithNpcOfType(kind)==true
end
local function BeginBank()
    if IsAccountBankOnly()then bankOpen=false;bankSession=bankSession+1;return end
    if bankOpen then Schedule();return end
    bankOpen=true;bankSession=bankSession+1
    local session=bankSession
    Schedule()
    -- Forever delivers tab/slot data asynchronously. Retry for a bounded period; never scan a closed bank.
    for _,delay in ipairs({.6,1.5,3})do
        C_Timer.After(delay,function()
            if bankOpen and bankSession==session and ns.IsInventoryEnabled()then Snapshot()end
        end)
    end
end
local function AttachWindows()
    for _,name in ipairs({"EUI_MainBagFrame","ContainerFrameCombinedBags","ContainerFrame1","EUI_BankFrame","BankFrame"})do
        local frame=_G[name]
        if frame and frame.HookScript and not hookedWindows[frame]then
            hookedWindows[frame]=true
            if name=="EUI_BankFrame"or name=="BankFrame"then frame:HookScript("OnShow",BeginBank)
            else frame:HookScript("OnShow",Schedule)end
        end
    end
end
local function IsBankBag(id)
    for _,bag in ipairs(BankBags())do if id==bag then return true end end
    return false
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ADDON_LOADED","BAG_UPDATE","BAG_UPDATE_DELAYED","BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYERBANKSLOTS_CHANGED","BANK_TABS_CHANGED","BANK_TAB_SETTINGS_UPDATED","PLAYER_LOGOUT","GET_ITEM_INFO_RECEIVED","PLAYER_INTERACTION_MANAGER_FRAME_SHOW","PLAYER_INTERACTION_MANAGER_FRAME_HIDE"})do
    pcall(events.RegisterEvent,events,event)
end
if _G.EllesmereUI and EllesmereUI.IS_FOREVER then events:RegisterEvent("BAG_CONTAINER_UPDATE")end
events:SetScript("OnEvent",function(_,event,arg)
    if event=="BANKFRAME_OPENED"then BeginBank()
    elseif event=="BANKFRAME_CLOSED"then bankOpen=false;bankSession=bankSession+1;Schedule()
    elseif event=="PLAYER_INTERACTION_MANAGER_FRAME_SHOW"or event=="PLAYER_INTERACTION_MANAGER_FRAME_HIDE"then
        local banker=Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
        if banker and arg==banker then
            if event=="PLAYER_INTERACTION_MANAGER_FRAME_SHOW"then BeginBank()
            else bankOpen=false;bankSession=bankSession+1;Schedule()end
        end
    elseif event=="PLAYER_LOGOUT"then Snapshot()
    elseif event=="GET_ITEM_INFO_RECEIVED"then if ns.RefreshInventoryView then ns.RefreshInventoryView()end
    elseif event=="ADDON_LOADED"then AttachWindows()
    elseif event=="PLAYER_LOGIN"or event=="PLAYER_ENTERING_WORLD"then
        AttachWindows();Schedule()
        for _,delay in ipairs({1,3})do C_Timer.After(delay,Snapshot)end
    elseif bankOpen and (event=="PLAYERBANKSLOTS_CHANGED"or (event=="BAG_UPDATE"or event=="BAG_CONTAINER_UPDATE")and (arg==nil or IsBankBag(arg)))then
        -- Capture the delivered bank change now, so an immediate close cannot cancel a deferred write.
        Snapshot()
    else Schedule()end
end)

