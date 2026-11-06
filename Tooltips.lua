local _, ns = ...

function ns.GetSettings()
    BelToolboxDB = BelToolboxDB or {}
    return BelToolboxDB
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function AddStatus(tooltip, data)
    if tooltip ~= GameTooltip then return end
    local settings = ns.GetSettings()
    if settings.enabled == false then return end

    local _, unit = TooltipUtil.GetDisplayedUnit(tooltip)

    if not unit or IsSecret(unit) then return end

    local isPlayer = UnitIsPlayer(unit)
    if IsSecret(isPlayer) or not isPlayer then return end

    local afk = UnitIsAFK(unit)
    local dnd = UnitIsDND(unit)

    local status
    if settings.showAFK ~= false and not IsSecret(afk) and afk then
        status = "|cffffb300<" .. AFK .. ">|r"
    elseif settings.showDND ~= false and not IsSecret(dnd) and dnd then
        status = "|cffff4d4d<" .. DND .. ">|r"
    end
    local nameLine = _G.GameTooltipTextLeft1
    if not nameLine then return end
    local text = nameLine:GetText()
    if not text or IsSecret(text) then return end
    if ns.statusRendered == text then text = ns.statusOriginal end
    ns.statusOriginal = text
    if status then
        nameLine:SetFormattedText("%s  %s", text, status)
        ns.statusRendered = nameLine:GetText()
    else
        nameLine:SetText(text)
        ns.statusRendered = nil
    end
end

TooltipDataProcessor.AddTooltipPostCall(
    Enum.TooltipDataType.Unit,
    AddStatus
)

local function AddItemLevel(tooltip, data)
    if ns.GetSettings().itemLevel == false or tooltip:IsForbidden() or IsSecret(data) or not data then return end
    if tooltip.GetPrimaryTooltipData then
        local primary = tooltip:GetPrimaryTooltipData()
        if IsSecret(primary) or (primary and primary ~= data) then return end
    end

    local lines = data.lines
    if IsSecret(lines) then return end
    local levelLine = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemLevel
    if levelLine and lines then
        for _, line in ipairs(lines) do
            if IsSecret(line) or IsSecret(line.type) or line.type == levelLine then return end
        end
    end

    local item = data.hyperlink
    local guid = data.guid
    if IsSecret(item) or IsSecret(guid) then return end
    if type(guid) == "string" and guid ~= "" and C_Item.GetItemLinkByGUID then
        local link = C_Item.GetItemLinkByGUID(guid)
        if IsSecret(link) then return end
        item = link or item
    end
    if type(item) ~= "string" or item == "" then item = data.id end
    if IsSecret(item) or (type(item) ~= "number" and type(item) ~= "string") then return end

    local _, _, _, equipLocation = C_Item.GetItemInfoInstant(item)
    if IsSecret(equipLocation) or not equipLocation or equipLocation == "" or equipLocation == "INVTYPE_NON_EQUIP" then return end
    local level = data.overrideItemLevel
    if IsSecret(level) then return end
    if type(level) ~= "number" or level <= 0 then level = C_Item.GetDetailedItemLevelInfo(item) end
    if IsSecret(level) or type(level) ~= "number" or level <= 0 then return end

    local text = ns.L("Item Level %d", level)
    local nativeText = ITEM_LEVEL and ITEM_LEVEL:format(level)
    local name = tooltip:GetName()
    if name then
        for index = 1, tooltip:NumLines() do
            local line = _G[name .. "TextLeft" .. index]
            local existing = line and line:GetText()
            if not IsSecret(existing) and existing and (existing == text or existing == nativeText) then return end
        end
    end
    tooltip:AddLine(text, 1, 0.82, 0)
end

if C_Item and C_Item.GetItemInfoInstant and C_Item.GetDetailedItemLevelInfo then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddItemLevel)
end

-- Inline title textures keep the icon on the same line as the native name.
local titleIcons = setmetatable({}, { __mode="k" })
local function AddTitleIcon(tooltip, data, kind)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local name = tooltip.GetName and tooltip:GetName()
    local title = name and _G[name .. "TextLeft1"]
    if not title then return end
    local text = title:GetText()
    if IsSecret(text) or type(text) ~= "string" then return end
    local previous = titleIcons[tooltip]
    if previous and text == previous.rendered then text = previous.original end
    local settings = ns.GetSettings()
    if settings[kind == "item" and "itemTitleIcons" or "spellTitleIcons"] == false then
        if previous then title:SetText(text) end
        titleIcons[tooltip] = nil
        return
    end
    local id = data and data.id
    if IsSecret(id) or type(id) ~= "number" then return end
    -- Respect title icons already supplied by another addon.
    if text:find("|T", 1, true) or text:find("|A", 1, true) then return end
    local icon
    if kind == "item" then
        if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(id) end
    elseif C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(id)
    end
    if IsSecret(icon) or (type(icon) ~= "number" and type(icon) ~= "string") then return end
    local texture = "|T" .. tostring(icon) .. ":18:18:0:0:64:64:5:59:5:59|t"
    title:SetFormattedText("%s %s", texture, text)
    titleIcons[tooltip] = { original=text, rendered=title:GetText() }
end
for _, entry in ipairs({
    { Enum.TooltipDataType.Item, "item" },
    { Enum.TooltipDataType.Spell, "spell" },
    { Enum.TooltipDataType.UnitAura, "spell" },
}) do
    local kind = entry[2]
    if entry[1] then
        TooltipDataProcessor.AddTooltipPostCall(entry[1], function(tooltip, data)
            AddTitleIcon(tooltip, data, kind)
        end)
    end
end
