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
