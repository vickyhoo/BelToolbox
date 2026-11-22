local _, ns = ...
local L = ns.L
local groups = {
    { key = "mooncloth", label = "Mooncloth", spells = {18560} },
    { key = "transmute", label = "Alchemy transmutation",
      spells = {17187, 11479, 11480, 17559, 17560, 17561, 17562, 17563, 17564, 17565, 17566, 25146, 1317279} },
    { key = "salt", label = "Salt Shaker", item = 15846 },
}
local trackedSpells = {}
for _, group in ipairs(groups) do
    for _, id in ipairs(group.spells or {}) do trackedSpells[id] = true end
end
local timer, scanTimer, loginPending
local confirmed = {}
local summaryShown, subscribed
-- All tracked classic cooldowns fit within a week. Do not persist corrupt
-- readings (including a mismatched client clock) as multi-week cooldowns.
local MAX_REMAINING = 7 * 86400

local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end
local function Number(value)
    return Readable(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end
local function ValidRemaining(value)
    return Number(value) and value >= 0 and value <= MAX_REMAINING
end
local function Remaining(start, duration, enabled)
    if not Number(start) or not Number(duration) or not Readable(enabled) or enabled == false or enabled == 0 then return end
    if duration < 60 then return 0 end -- Ignore the global cooldown.
    if duration > MAX_REMAINING then return end
    local remaining = math.max(0, start + duration - GetTime())
    if remaining > duration + 2 or not ValidRemaining(remaining) then return end
    return remaining
end
local function SpellRemaining(id)
    local recipeAPI = C_TradeSkillUI
    local info = recipeAPI and recipeAPI.GetRecipeInfo and recipeAPI.GetRecipeInfo(id)
    local known = confirmed[id] or (Readable(info) and info and Readable(info.learned) and info.learned)
    if not known then
        local check = C_SpellBook and C_SpellBook.IsSpellKnown or IsSpellKnown
        local learned = check and check(id)
        known = Readable(learned) and learned
    end
    if not known then return end

    local recipeTime
    -- Recipe data is scoped to the open profession and can be transient while
    -- switching between two professions. Spell/item cooldowns remain usable.
    if recipeAPI and recipeAPI.GetRecipeCooldown
        and not (recipeAPI.IsDataSourceChanging and recipeAPI.IsDataSourceChanging())
        and not (recipeAPI.IsTradeSkillReady and not recipeAPI.IsTradeSkillReady()) then
        recipeTime = recipeAPI.GetRecipeCooldown(id)
    end
    local cd = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(id)
    local spellTime = Readable(cd) and cd and Remaining(cd.startTime, cd.duration, cd.isEnabled)
    if not ValidRemaining(recipeTime) then return spellTime or nil end
    return math.max(0, recipeTime, spellTime or 0)
end
local function GroupRemaining(group)
    if group.item then
        if not C_Item or not C_Item.GetItemCount or not C_Item.GetItemCooldown then return end
        local count = C_Item.GetItemCount(group.item)
        if Number(count) and count > 0 then return Remaining(C_Item.GetItemCooldown(group.item)) end
        return
    end
    local longest
    for _, id in ipairs(group.spells) do
        local seconds = SpellRemaining(id)
        if seconds and (not longest or seconds > longest) then longest = seconds end
    end
    return longest
end
local function Store()
    local db = ns.GetSettings()
    db.craftingCooldowns = db.craftingCooldowns or {}
    return db.craftingCooldowns
end
local function Enabled()
    return ns.GetSettings().craftingCooldownAlerts == true
end
local function FormatRemaining(seconds)
    if seconds < 60 then return L("%ds", seconds) end
    local minutes = math.ceil(seconds / 60)
    local days = math.floor(minutes / 1440)
    local hours = math.floor(minutes / 60) % 24
    local parts = {}
    if days > 0 then parts[#parts + 1] = L("%dd", days) end
    if hours > 0 then parts[#parts + 1] = L("%dh", hours) end
    if minutes % 60 > 0 then parts[#parts + 1] = L("%dm", minutes % 60) end
    return table.concat(parts, " ")
end
local function ReportReady(login)
    if timer then timer:Cancel(); timer = nil end
    if not Enabled() then return end
    local now, nearest = GetServerTime(), nil
    local ready, cooling = {}, {}
    for _, character in pairs(Store()) do
        local name = character.name
        if character.realm ~= GetRealmName() then name = name .. "-" .. character.realm end
        for _, group in ipairs(groups) do
            local record = character.cooldowns[group.key]
            if record and (not Number(record.expires) or record.expires > now + MAX_REMAINING) then
                character.cooldowns[group.key] = nil
                record = nil
            end
            if record and record.expires <= now then
                if login or not record.notified then ready[#ready + 1] = L("%s (%s)", L(group.label), name) end
                record.notified = true
            elseif record then
                if not nearest or record.expires < nearest then nearest = record.expires end
                if login then
                    cooling[#cooling + 1] = { expires = record.expires, label = L("%s (%s)", L(group.label), name) }
                end
            end
        end
    end
    if #ready > 0 then
        table.sort(ready)
        print("|cff4accff" .. L("Bel Toolbox") .. "|r " .. L("Profession cooldowns ready: %s", table.concat(ready, ", ")))
    end
    if #cooling > 0 then
        table.sort(cooling, function(a, b)
            if a.expires == b.expires then return a.label < b.label end
            return a.expires < b.expires
        end)
        local entries = {}
        for _, entry in ipairs(cooling) do
            entries[#entries + 1] = L("%s: %s remaining", entry.label, FormatRemaining(entry.expires - now))
        end
        print("|cff4accff" .. L("Bel Toolbox") .. "|r " .. L("Profession cooldowns: %s", table.concat(entries, ", ")))
    end
    if nearest then
        timer = C_Timer.NewTimer(math.min(3600, math.max(1, nearest - now)), function()
            timer = nil
            ReportReady(false)
        end)
    end
end
local function ReadCharacter()
    local name, realm = UnitFullName("player")
    if not name then return end
    realm = realm and realm ~= "" and realm or GetRealmName()
    local key, now = name .. "-" .. realm, GetServerTime()
    local characters = Store()
    for _, group in ipairs(groups) do
        local remaining = GroupRemaining(group)
        local character = characters[key]
        local old = character and character.cooldowns[group.key]
        if old and (not Number(old.expires) or old.expires > now + MAX_REMAINING) then
            character.cooldowns[group.key] = nil
            old = nil
        end
        if remaining and (remaining > 0 or not old or old.expires <= now) then
            if not character then
                character = { name = name, realm = realm, cooldowns = {} }
                characters[key] = character
            end
            if remaining > 0 then
                local expires = now + math.ceil(remaining)
                if not old or math.abs(old.expires - expires) > 2 then
                    character.cooldowns[group.key] = { expires = expires }
                end
            elseif not old then
                -- A ready cooldown seen for the first time belongs in the login summary.
                character.cooldowns[group.key] = { expires = now, notified = true }
            end
        end
    end
end
local function Scan()
    scanTimer = nil
    if not Enabled() or InCombatLockdown() then return end
    ReadCharacter()
    local summary = loginPending and not summaryShown
    if summary then summaryShown = true end
    ReportReady(summary)
    loginPending = nil
end
local function QueueScan(delay)
    if scanTimer then return end
    scanTimer = C_Timer.NewTimer(delay or .5, Scan)
end

local events = CreateFrame("Frame")
local scanEvents = {"UNIT_SPELLCAST_SUCCEEDED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE",
    "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED"}
function ns.SetProfessionCooldownAlerts(enabled)
    enabled = enabled == true
    ns.GetSettings().craftingCooldownAlerts = enabled
    if subscribed == enabled then return end
    subscribed = enabled
    for _, event in ipairs(scanEvents) do
        if enabled then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
    if enabled then
        loginPending = not summaryShown
        QueueScan(2)
    else
        if scanTimer then scanTimer:Cancel(); scanTimer = nil end
        if timer then timer:Cancel(); timer = nil end
        loginPending = nil
    end
end
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
        if Enabled() then ns.SetProfessionCooldownAlerts(true) end
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" or not Number(spellID) or not trackedSpells[spellID] then return end
        confirmed[spellID] = true
    end
    if not InCombatLockdown() then QueueScan(loginPending and 2 or .5) end
end)
