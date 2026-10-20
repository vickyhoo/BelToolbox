local _, ns = ...
local L = ns.L
local function Say(message) print("|cff4accffBel Toolbox:|r " .. message) end
local function Settings()
    local db = ns.GetSettings()
    db.merchant = db.merchant or {}
    return db.merchant
end
ns.GetMerchantSettings = Settings
local frame, selected, pending, running
local serial = 0
local function Stop(message)
    serial = serial + 1
    running = nil
    pending = nil
    if frame then frame.buy:Enable(); frame.buy:SetText(L("Buy")); if frame.notice then frame.notice:SetText("") end end
    if message then Say(message) end
end

local function Info(index)
    if not MerchantFrame or not MerchantFrame:IsShown() or MerchantFrame.selectedTab ~= 1 then return end
    local info
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        info = C_MerchantFrame.GetItemInfo(index)
    elseif GetMerchantItemInfo then
        local name, texture, price, count, stock, usable, purchasable, extended = GetMerchantItemInfo(index)
        info = { name=name, texture=texture, price=price, stackCount=count, numAvailable=stock, hasExtendedCost=extended }
    end
    if not info or not info.name then return end
    local link = GetMerchantItemLink(index)
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return end
    local _, _, _, _, _, _, _, stack, _, _, _, _, _, _, _, _, _, reagent = C_Item.GetItemInfo(id)
    if not stack then return end
    -- Extended-cost and unique items are deliberately left to the native purchase UI.
    local costs = GetMerchantItemCostInfo and GetMerchantItemCostInfo(index) or 0
    if info.hasExtendedCost or info.extendedCost or (costs and costs > 0) then return nil, "currency" end
    local unique = C_Item.GetItemUniquenessByID and C_Item.GetItemUniquenessByID(id)
    if unique then return nil, "unique" end
    return { index=index, id=id, link=link, name=info.name, price=info.price or 0,
        pack=math.max(info.stackCount or 1, 1), stock=info.numAvailable or -1,
        stack=stack, reagent=reagent, vendor=UnitGUID("npc") }
end

local function Capacity(item)
    local capacity = 0
    local family = C_Item.GetItemFamily(item.id) or 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local free, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if bagFamily == 0 or (bagFamily and bit.band(bagFamily, family) ~= 0) then
            capacity = capacity + (free or 0) * item.stack
        end
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local existing = C_Container.GetContainerItemInfo(bag, slot)
            if existing and existing.itemID == item.id and not existing.isLocked then
                capacity = capacity + math.max(0, item.stack - existing.stackCount)
            end
        end
    end
    return capacity
end
local function Limit(item)
    local limit = Capacity(item)
    if item.price > 0 then limit = math.min(limit, math.floor(GetMoney() / math.ceil(item.price / item.pack))) end
    if item.stock >= 0 then limit = math.min(limit, item.stock) end
    return math.max(0, math.floor(limit))
end
local function Current()
    if not selected or Settings().enabled == false then return end
    local item = Info(selected.index)
    if not item or item.id ~= selected.id or item.vendor ~= selected.vendor
        or item.price ~= selected.price or item.pack ~= selected.pack then return end
    return item
end
local function Update()
    if not frame or not selected then return end
    local item = Current()
    if not item then Stop(); frame:Hide(); return end
    local amount = tonumber(frame.input:GetText()) or 0
    if pending and (pending.amount ~= amount or pending.selection ~= selected) then
        pending = nil; frame.buy:SetText(L("Buy")); if frame.notice then frame.notice:SetText("") end
    end
    frame.detail:SetText(string.format(L("Vendor pack: %d   |   Max: %d"), item.pack, Limit(item)))
    frame.cost:SetText(L("Total: ") .. GetCoinTextureString(math.ceil(amount * item.price / item.pack)))
end
local function NextBatch(token)
    if token ~= serial or not running then return end
    local item = Current()
    if not item or InCombatLockdown() then Stop(L("Purchase stopped.")); return end
    if running.left <= 0 then Stop(L("Purchase complete.")); Update(); return end
    local amount = math.min(running.left, item.stack, Limit(item))
    if amount <= 0 then Stop(L("Stopped: insufficient money, stock or bag space.")); Update(); return end
    local before = C_Item.GetItemCount(item.id)
    BuyMerchantItem(item.index, amount)
    local elapsed = 0
    local function Check()
        if token ~= serial or not running then return end
        if not Current() then Stop(); return end
        local received = C_Item.GetItemCount(item.id) - before
        if received >= amount then
            running.left = running.left - amount
            C_Timer.After(0.2, function() NextBatch(token) end)
        else
            elapsed = elapsed + 0.2
            if elapsed >= 4 then
                Stop(L("Delivery was not confirmed; further purchases stopped. Check your bags."))
                Update()
            else C_Timer.After(0.2, Check) end
        end
    end
    C_Timer.After(0.2, Check)
end
local function Begin(request)
    if pending ~= request then return end
    pending = nil
    local item = Current()
    if not item or selected ~= request.selection or running or InCombatLockdown() then return end
    if Limit(item) < request.amount then Say(L("Available quantity changed. Enter a new amount.")); Update(); return end
    serial = serial + 1
    running = { left=request.amount }
    frame.buy:SetText(L("Purchasing..."))
    frame.buy:Disable()
    if frame.notice then frame.notice:SetText(L("Purchasing...")) end
    NextBatch(serial)
end
local function Purchase()
    if running or InCombatLockdown() then return end
    local item = Current()
    if not item then return end
    local amount = tonumber(frame.input:GetText())
    if not amount or amount < 1 or amount ~= math.floor(amount) or amount > Limit(item) then
        Say(L("Enter a positive whole item count within the available limit.")); return
    end
    local request = { amount=amount, selection=selected }
    pending = request
    Begin(request)
end
local function BuildFrame()
    frame = CreateFrame("Frame", "BelToolboxMerchantFrame", UIParent, "BackdropTemplate")
    frame:SetSize(304, 208)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    frame:SetBackdropColor(0.055, 0.065, 0.08, 0.98); frame:SetBackdropBorderColor(0.29, 0.8, 1)
    local function Label(y, font)
        local label = frame:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        label:SetPoint("TOPLEFT", 12, y); label:SetWidth(280); label:SetJustifyH("LEFT")
        return label
    end
    Label(-12, "GameFontNormal"):SetText("Bel Toolbox")
    frame.item = Label(-34)
    frame.item:SetMaxLines(1)
    frame.detail = Label(-57, "GameFontHighlightSmall")
    frame.input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.input:SetSize(72, 24); frame.input:SetPoint("TOPLEFT", 46, -80)
    frame.input:SetJustifyH("CENTER")
    frame.input:SetAutoFocus(false); frame.input:SetNumeric(true); frame.input:SetMaxLetters(6)
    frame.input:SetScript("OnTextChanged", Update)
    frame.input:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Purchase() end)
    frame.input:SetScript("OnEscapePressed", function() frame:Hide() end)
    local function Button(text, x, y, width, callback)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(width, 24); button:SetPoint("TOPLEFT", x, y); button:SetText(text); button:SetScript("OnClick", callback)
        return button
    end
    local function Adjust(delta)
        if running then return end
        local item = Current()
        if not item then return end
        local value = tonumber(frame.input:GetText()) or 1
        frame.input:SetText(tostring(math.max(1, math.min(Limit(item), value + delta))))
    end
    Button("−", 12, -80, 26, function() Adjust(-1) end)
    Button("+", 126, -80, 26, function() Adjust(1) end)
    frame.input:EnableMouseWheel(true)
    frame.input:SetScript("OnMouseWheel", function(_, delta) Adjust(delta > 0 and 1 or -1) end)
    Button(L("Stack"), 160, -80, 58, function()
        local item = Current(); if item then frame.input:SetText(tostring(math.min(Limit(item), item.stack))) end
    end)
    Button(L("Max"), 222, -80, 70, function() local item=Current(); if item then frame.input:SetText(tostring(Limit(item))) end end)
    frame.cost = Label(-114)
    frame.notice = Label(-173, "GameFontHighlightSmall")
    frame.buy = Button(L("Buy"), 12, -140, 136, Purchase)
    Button(L("Close / Stop"), 156, -140, 136, function() frame:Hide() end)
    frame:SetScript("OnHide", function() Stop(); selected=nil end)
    tinsert(UISpecialFrames, "BelToolboxMerchantFrame")
    frame:Hide()
end
local hooked
local function HookMerchant()
    if hooked or type(MerchantItemButton_OnModifiedClick) ~= "function" then return end
    hooked = true
    hooksecurefunc("MerchantItemButton_OnModifiedClick", function(button, mouseButton)
        if Settings().enabled == false or mouseButton ~= "LeftButton" or not IsShiftKeyDown()
            or IsControlKeyDown() or IsAltKeyDown() or InCombatLockdown() then return end
        if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return end
        local item, reason = Info(button:GetID())
        if not item then
            if reason then Say(L("Use the native purchase UI for currency-cost or unique items.")) end
            return
        end
        Stop()
        if not frame then BuildFrame() end
        if StackSplitFrame then StackSplitFrame:Hide() end
        selected = item
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
        frame.item:SetText(item.link)
        frame:Show()
        frame.input:SetText("1"); Update()
        frame.input:SetFocus(); frame.input:HighlightText()
    end)
end
local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW"); events:RegisterEvent("MERCHANT_CLOSED")
events:RegisterEvent("MERCHANT_UPDATE"); events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then HookMerchant()
    elseif event == "MERCHANT_CLOSED" or event == "PLAYER_REGEN_DISABLED" then
        Stop(); if frame then frame:Hide() end
    elseif frame and frame:IsShown() then Update() end
end)