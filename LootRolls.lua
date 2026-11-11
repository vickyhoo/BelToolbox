local _, ns = ...
local EUI = EllesmereUI
local history = C_LootHistory
local events = CreateFrame("Frame")
local labels, matches = {}, {}
local enabled, queued
local rollStates = Enum.EncounterLootDropRollState or { NeedMainSpec = 0, NeedOffSpec = 1, Greed = 3, Pass = 5 }
local choiceByState = {
    [rollStates.NeedMainSpec] = "NeedButton",
    [rollStates.NeedOffSpec] = "NeedButton",
    [rollStates.Greed] = "GreedButton",
    [rollStates.Pass] = "PassButton",
}
local choices = { "NeedButton", "GreedButton", "PassButton" }
local historyEvents = {
    "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS",
    "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_CLEAR_HISTORY",
}

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function ItemKey(link)
    if Plain(link) and type(link) == "string" then
        return link:match("|H(item:[^|]+)|h") or link:match("^(item:[^|]+)$")
    end
end

local function HideBonusRollMover()
    local registered = EUI._unlockRegisteredElements
    local mover = registered and registered.EUI_BonusRoll
    if EUI.IS_FOREVER and mover then
        mover.isHidden = function() return true end
    end
end

function ns.SetLootRollMovement(enabled)
    if not EUI._InitShifterLootWindows then return end
    EllesmereUIDB = EllesmereUIDB or {}
    EllesmereUIDB.shifterLootUnlock = enabled
    if enabled then
        EllesmereUIDB.shifterLootHideOverlays = false
        EUI._InitShifterLootWindows()
        HideBonusRollMover()
    elseif EUI._DisableShifterLootWindows then
        EUI._DisableShifterLootWindows()
    end
end

local function Draw(frame, counts)
    local buttons = frame.LootButtonContainer or frame
    for _, choice in ipairs(choices) do
        local button = buttons[choice]
        if button and button:IsShown() then
            local label = labels[button]
            if not label then
                label = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                -- Need and Greed are stacked tightly on Forever's default frame.
                label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, 2)
                label:SetShadowOffset(1, -1)
                labels[button] = label
            end
            label:SetText(counts and tostring(counts[choice] or 0) or "–")
            label:Show()
        end
    end
end

local function FindDrops()
    local used, candidates = {}, {}
    for _, match in pairs(matches) do
        used[match.encounterID .. ":" .. match.key] = true
    end
    for _, encounter in ipairs(history.GetAllEncounterInfos() or {}) do
        local encounterID = encounter.encounterID
        if Plain(encounterID) and type(encounterID) == "number" then
            for _, drop in ipairs(history.GetSortedDropsForEncounter(encounterID) or {}) do
                local item, key = ItemKey(drop.itemHyperlink), drop.lootListKey
                if item and Plain(key) and type(key) == "number" and not used[encounterID .. ":" .. key]
                    and Plain(drop.winner) and Plain(drop.allPassed) and not drop.winner and not drop.allPassed then
                    if candidates[item] == nil then candidates[item] = { encounterID = encounterID, key = key }
                    else candidates[item] = false end
                end
            end
        end
    end
    return candidates
end

local function Update()
    for _, label in pairs(labels) do label:Hide() end
    if not enabled then return end

    local active, unpaired = {}, {}
    local container = GroupLootContainer
    for _, frame in pairs(container and container.rollFrames or {}) do
        local id = frame.rollID
        if frame:IsShown() and Plain(id) and type(id) == "number" then
            local item = ItemKey(GetLootRollItemLink(id))
            active[#active + 1] = { frame = frame, id = id, item = item }
            if item and not matches[id] then unpaired[item] = (unpaired[item] or 0) + 1 end
        end
    end
    local candidates = next(unpaired) and FindDrops() or {}
    for _, roll in ipairs(active) do
        local match = matches[roll.id]
        if not match and roll.item and unpaired[roll.item] == 1 then
            match = candidates[roll.item] or nil
            matches[roll.id] = match
        end
        local drop = match and history.GetSortedInfoForDrop(match.encounterID, match.key)
        local counts
        if drop and ItemKey(drop.itemHyperlink) == roll.item and Plain(drop.rollInfos) and type(drop.rollInfos) == "table" then
            counts = {}
            for _, info in ipairs(drop.rollInfos) do
                local state = info.state
                local choice = Plain(state) and choiceByState[state]
                if choice then counts[choice] = (counts[choice] or 0) + 1 end
            end
        end
        Draw(roll.frame, counts)
    end
end

local function QueueUpdate()
    if queued or not enabled then return end
    queued = true
    C_Timer.After(0, function()
        queued = nil
        Update()
    end)
end

function ns.RefreshLootRollCounts()
    local wanted = ns.GetEnhancements().lootRollCounts == true and history
        and history.GetAllEncounterInfos and history.GetSortedDropsForEncounter and history.GetSortedInfoForDrop
        and GetLootRollItemLink and true or false
    if wanted == enabled then return end
    enabled = wanted
    for _, event in ipairs(historyEvents) do
        if enabled then events:RegisterEvent(event)
        elseif events:IsEventRegistered(event) then events:UnregisterEvent(event) end
    end
    if enabled then QueueUpdate()
    else
        wipe(matches)
        for _, label in pairs(labels) do label:Hide() end
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, id)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0, HideBonusRollMover)
        if GroupLootContainer_Update then hooksecurefunc("GroupLootContainer_Update", QueueUpdate) end
        ns.RefreshLootRollCounts()
        return
    end
    if event == "LOOT_HISTORY_CLEAR_HISTORY" or event == "CANCEL_ALL_LOOT_ROLLS" then wipe(matches) end
    if (event == "START_LOOT_ROLL" or event == "CANCEL_LOOT_ROLL") and Plain(id) and type(id) == "number" then
        matches[id] = nil
    end
    QueueUpdate()
end)
