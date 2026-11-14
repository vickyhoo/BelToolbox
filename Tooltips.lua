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

local function CostText(copper)
    local format = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
    if format then return format(copper) end
    if GetMoneyString then return GetMoneyString(copper, true) end
    return ns.L("%d copper", copper)
end

local function IsPrimaryTooltip(tooltip, data)
    if not tooltip.GetPrimaryTooltipData then return true end
    local primary = tooltip:GetPrimaryTooltipData()
    return not IsSecret(primary) and (not primary or primary == data)
end

local function AddMaterialCost(tooltip, id, quantity, total, highlight, vendor)
    local name = C_Item.GetItemNameByID(id)
    if IsSecret(name) or not name then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        name = ns.L("Item #%d", id)
    end
    local r, g, b = .55, .55, .55
    if total then
        if highlight then r, g, b = .35, 1, .35
        else r, g, b = 1, 1, 1 end
    end
    local amount = total and CostText(total) or ns.L("No auction price")
    if vendor then amount = amount .. " (" .. ns.L("Vendor price") .. ")" end
    tooltip:AddDoubleLine(quantity .. " × " .. name, amount, 1, 1, 1, r, g, b)
end

local function AddPriceSources(tooltip, sources)
    local names = {}
    for source in pairs(sources) do names[#names + 1] = source end
    if #names > 0 then
        table.sort(names)
        tooltip:AddLine(ns.L("Price sources: %s", table.concat(names, ", ")), .65, .65, .65)
    end
end

local function AddCrateCosts(tooltip, data)
    if tooltip:IsForbidden() or IsSecret(data) or not data then return end
    local id = data.id
    if IsSecret(id) or type(id) ~= "number" or ns.GetSettings().crateCosts == false then return end
    local bundles = ns.WaylaidCrates and ns.WaylaidCrates[id]
    if not bundles or not ns.GetAuctionUnitPrice then return end
    if not IsPrimaryTooltip(tooltip, data) then return end

    local sources, totals = {}, {}
    local cheapest
    for index, bundle in ipairs(bundles) do
        local unitPrice = ns.GetAuctionUnitPrice(bundle[1], sources)
        if unitPrice then
            local total = unitPrice * bundle[2]
            totals[index] = total
            cheapest = cheapest and math.min(cheapest, total) or total
        end
    end

    local L = ns.L
    tooltip:AddLine(L("Crate filling cost"), 1, .82, 0)
    for index, bundle in ipairs(bundles) do
        local total = totals[index]
        AddMaterialCost(tooltip, bundle[1], bundle[2], total, total == cheapest)
    end
    AddPriceSources(tooltip, sources)
end

local itemRecipes = {
    [14513] = 18457, -- Pattern: Robe of the Archmage
    [249481] = 1248805, -- Formula: Enchant Weapon - Revelation
    [273629] = 1248805, -- Enchant Weapon - Revelation
}
-- These recipes can appear in item links before their profession is open.
local recipeFallbacks = {
    [18457] = {{14048, 12}, {7078, 8}, {7082, 8}, {7076, 8}, {7080, 8}, {14341, 2}, {249431, 10}},
    [1248805] = {{11083, 8}, {11084, 6}, {11082, 2}, {249409, 4}, {249410, 4}},
}

local function GetItemRecipeID(id)
    if type(id) ~= "number" then return end
    if itemRecipes[id] then return itemRecipes[id] end
    local getInfo = C_Item.GetItemInfoInstant
    local getSpell = C_Item.GetItemSpell
    if not getInfo or not getSpell then return end
    local _, _, _, _, _, classID = getInfo(id)
    local recipeClass = Enum.ItemClass and Enum.ItemClass.Recipe or 9
    if IsSecret(classID) or classID ~= recipeClass then return end
    local _, spellID = getSpell(id)
    return spellID
end

local function AddRecipeCosts(tooltip, data, isSpell)
    if tooltip:IsForbidden() or IsSecret(data) or not data or not ns.GetMaterialUnitPrice
        or ns.GetSettings().recipeCosts == false or not IsPrimaryTooltip(tooltip, data) then return end
    local id = data.id
    if IsSecret(id) then return end
    local recipeID, recipeLevel
    if isSpell then
        recipeID = id
    else
        local info = tooltip.GetPrimaryTooltipInfo and tooltip:GetPrimaryTooltipInfo()
        if IsSecret(info) then return end
        if info and not IsSecret(info.getterName) and info.getterName == "GetRecipeResultItem" then
            local args = info.getterArgs
            if not IsSecret(args) and args then recipeID, recipeLevel = args[1], args[4] end
        else
            recipeID = GetItemRecipeID(id)
        end
    end
    if IsSecret(recipeID) or type(recipeID) ~= "number" or IsSecret(recipeLevel) then return end

    local slots = ns.GetRecipeMaterialSlots and ns.GetRecipeMaterialSlots(recipeID, recipeLevel)
    local fallback = recipeFallbacks[recipeID]
    if not slots and fallback then
        slots = {}
        for _, pair in ipairs(fallback) do slots[#slots + 1] = {quantity = pair[2], ids = {pair[1]}} end
    end
    if not slots then return end

    local L, sources = ns.L, {}
    local sum, complete = 0, true
    tooltip:AddLine(L("Recipe material costs"), 1, .82, 0)
    for _, slot in ipairs(slots) do
        local cheapest
        for _, material in ipairs(slot.ids) do
            local price, vendor = ns.GetMaterialUnitPrice(material, sources)
            local subtotal = price and price * slot.quantity
            if subtotal and (not cheapest or subtotal < cheapest) then cheapest = subtotal end
            AddMaterialCost(tooltip, material, slot.quantity, subtotal, false, vendor)
        end
        if cheapest then sum = sum + cheapest else complete = false end
    end
    tooltip:AddDoubleLine(L("Estimated material total"), complete and CostText(sum) or L("Missing reagent prices"), 1, .82, 0, 1, 1, 1)
    AddPriceSources(tooltip, sources)
end

if C_Item and C_Item.GetItemNameByID then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddCrateCosts)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data) AddRecipeCosts(tooltip, data, false) end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data) AddRecipeCosts(tooltip, data, true) end)
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
