-- Independent trade receipt implementation. Only a server-confirmed success
-- authorizes a receipt; accepting/closing a trade alone is not proof of success.
local _, ns = ...
local events = CreateFrame("Frame")
local trade
local watched = {"TRADE_SHOW", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED",
    "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "TRADE_REQUEST_CANCEL",
    "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE", "CHAT_MSG_SYSTEM"}
local function Plain(value)
    if not (issecretvalue and issecretvalue(value)) then return value end
end
local function Enabled() return ns.GetEnhancements().tradeReceipt == true end
local function OtherReceipt()
    local gi = _G.GearInsightForever
    local receipt = gi and gi.TradeReceipt
    return receipt and receipt.On and receipt.On()
end
local function Money(value)
    local gold = math.floor(value / 10000)
    local silver = math.floor(value / 100) % 100
    local copper = value % 100
    return ns.L("%dg %ds %dc", gold, silver, copper)
end
local function ReadItems(info, link)
    local items = {}
    if not info then return items end
    -- Slot seven is a non-traded enchant target and must not be a given item.
    for slot = 1, 6 do
        local name, _, count = info(slot)
        name, count = Plain(name), Plain(count)
        if type(name) == "string" and name ~= "" then
            local hyperlink = link and Plain(link(slot))
            items[#items + 1] = {name=name, link=type(hyperlink)=="string" and hyperlink or nil,
                count=type(count)=="number" and math.max(1,count) or 1}
        end
    end
    return items
end
local function ReadMoney(fn)
    local value = fn and Plain(fn())
    return type(value)=="number" and math.max(0,math.floor(value)) or 0
end
local function Snapshot()
    if not trade or trade.closed then return end
    trade.gave = ReadItems(GetTradePlayerItemInfo, GetTradePlayerItemLink)
    trade.received = ReadItems(GetTradeTargetItemInfo, GetTradeTargetItemLink)
    trade.paid = ReadMoney(GetPlayerTradeMoney)
    trade.earned = ReadMoney(GetTargetTradeMoney)
end
local function Side(items, coins, detail)
    local parts = {}
    if #items > 0 then
        if detail == 0 then parts[#parts+1] = ns.L("%d item stacks",#items)
        else
            for index = 1, detail do
                local item = items[index]
                parts[#parts+1] = (item.link or ("["..item.name.."]")).." x"..item.count
            end
            if detail < #items then parts[#parts+1] = ns.L("and %d more stacks",#items-detail) end
        end
    end
    if coins > 0 then parts[#parts+1] = Money(coins) end
    return #parts > 0 and table.concat(parts, ", ") or ns.L("Nothing")
end
local function Text(record)
    local give, receive = #record.gave, #record.received
    while true do
        local text = ns.L("Trade complete. Gave: %s.", Side(record.gave,record.paid,give))
        if ns.GetEnhancements().tradeReceiptReceived ~= false then
            text = text.." "..ns.L("Received: %s.", Side(record.received,record.earned,receive))
        end
        -- Drop whole item links, never cut a hyperlink or a UTF-8 character.
        if #text <= 255 then return text end
        if receive > 0 then receive = receive - 1
        elseif give > 0 then give = give - 1
        else return end
    end
end
local function Complete()
    local record = trade
    trade = nil -- UI_INFO_MESSAGE and CHAT_MSG_SYSTEM may both report success.
    if not record or record.failed then return end
    if #record.gave==0 and #record.received==0 and record.paid==0 and record.earned==0 then return end
    C_Timer.After(1, function()
        if not Enabled() or OtherReceipt() or InCombatLockdown() then return end
        if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
        local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
        local text = Text(record)
        if send and text then send(text,"WHISPER",nil,record.partner) end
    end)
end
function ns.RefreshTradeReceipt()
    trade = nil
    for _, event in ipairs(watched) do
        if Enabled() then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
end
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_,event,a,b)
    if event=="PLAYER_LOGIN" then ns.RefreshTradeReceipt(); return end
    if not Enabled() then return end
    if event=="TRADE_SHOW" then
        trade=nil
        if OtherReceipt() then return end
        local partner = GetUnitName and Plain(GetUnitName("NPC",true))
        if type(partner)~="string" or partner=="" then return end
        trade={partner=partner}
        Snapshot()
    elseif trade then
        if event=="TRADE_ACCEPT_UPDATE" then
            -- Preserve the accepted snapshot if the client has already cleared
            -- the slots during completion. A reset to 0/0 permits editing again.
            a,b=Plain(a),Plain(b)
            if not trade.accepted or (a==0 and b==0) then Snapshot() end
            trade.accepted=(a==1 or b==1)
        elseif event=="TRADE_REQUEST_CANCEL" then trade=nil
        elseif event=="UI_ERROR_MESSAGE" then trade.failed=true
        elseif event=="UI_INFO_MESSAGE" or event=="CHAT_MSG_SYSTEM" then
            local message=Plain(event=="CHAT_MSG_SYSTEM" and a or b)
            if type(message)=="string" and message==ERR_TRADE_COMPLETE then Complete() end
        elseif event=="TRADE_CLOSED" then
            trade.closed=true
            local record=trade
            C_Timer.After(2,function()if trade==record then trade=nil end end)
        elseif not trade.accepted then Snapshot() end
    end
end)
