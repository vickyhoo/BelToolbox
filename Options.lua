local addonName, ns = ...
local EUI = _G.EllesmereUI
if not EUI or type(EUI.RegisterPlugin) ~= "function" then return end

local L = ns.L
local title = L("Tooltips")
local page = L("Status Display")

local function BuildToolbarPage(parent,yOffset,key,title,refresh)
    local W=EUI.Widgets
    local y=yOffset
    local _,h
    local function Row(widget,...) _,h=W[widget](W,parent,...);y=y-h end
    local function Toggle(field,text,default)
        Row("Toggle",L(text),y,
            function()local v=ns.Toolbars.Settings(key)[field];if v==nil then return default end;return v end,
            function(v)ns.Toolbars.Settings(key)[field]=v;refresh()end)
    end
    Row("SectionHeader",L(title),y)
    Toggle("enabled","Enable chat bar",true)
    Row("Dropdown",L("Button size"),y,{[18]="18",[22]="22",[26]="26",[30]="30"},
        function()return ns.Toolbars.Size(key)end,
        function(v)ns.Toolbars.Settings(key).size=v;refresh()end,{18,22,26,30})
    Toggle("vertical","Vertical layout",false)
    Row("SectionHeader",L("Toolbar buttons"),y)
    for _,data in ipairs(ns.ChatBarButtons)do
        local field=data.key
        Row("Toggle",L(data.title),y,
            function()local db=ns.Toolbars.Settings(key);return not db.buttons or db.buttons[field]~=false end,
            function(v)local db=ns.Toolbars.Settings(key);db.buttons=db.buttons or {};db.buttons[field]=v;refresh()end)
    end
    Row("Button",L("Reset position"),y,function()ns.Toolbars.Settings(key).position=nil;refresh()end)
    return math.abs(y)+12
end

local registered = EUI.RegisterPlugin(addonName, {
    label = L("Bel Toolbox"),
    position = "bottom",
    modules = {
        {
            key="ProfessionProfit",title=L("Profession Helper"),pages={L("Recipe Profit")},
            description=L("Show estimated profit in the recipe list while preserving native skill-up arrows. Uses installed price providers; no auction scanning is added."),
            buildPage=function(_,parent,yOffset)
                local W=EUI.Widgets;local y=yOffset;local _,h
                _,h=W:SectionHeader(parent,L("Recipe Profit"),y);y=y-h
                _,h=W:Toggle(parent,L("Enable recipe list profit"),y,
                    function()return ns.GetProfessionProfitSettings().enabled~=false end,
                    function(v)ns.GetProfessionProfitSettings().enabled=v;ns.RefreshProfessionProfit()end,
                    L("Shows profit per craft after the auction cut. Missing prices show a dash. When CraftProfit row tags are enabled, its tags take priority to avoid duplicates."));y=y-h
                local available=ns.GetProfessionPriceSources()
                local choices={auto=L("Automatic")}
                for _,source in ipairs({{"auctionator","Auctionator"},{"tsm","TradeSkillMaster"},{"craftprofit","CraftProfit"}})do
                    choices[source[1]]=source[2].." ("..L(available[source[1]] and "API available" or "Not loaded")..")"
                end
                _,h=W:Dropdown(parent,L("Price source"),y,choices,
                    function()return ns.GetProfessionProfitSettings().source or "auto"end,
                    function(v)ns.GetProfessionProfitSettings().source=v;ns.RefreshProfessionProfit()end,
                    {"auto","auctionator","tsm","craftprofit"});y=y-h
                _,h=W:Slider(parent,L("Auction cut (%)"),y,0,30,1,
                    function()return ns.GetProfessionProfitSettings().ahCut or 5 end,
                    function(v)ns.GetProfessionProfitSettings().ahCut=v;ns.RefreshProfessionProfit()end);y=y-h
                _,h=W:Toggle(parent,L("Recipe names by skill-up difficulty"),y,
                    function()return ns.GetProfessionProfitSettings().difficulty~=false end,
                    function(v)ns.GetProfessionProfitSettings().difficulty=v;ns.RefreshProfessionProfit()end,
                    L("Color learned recipe names orange, yellow, green or gray. Native skill-up arrows remain unchanged."));y=y-h
                return math.abs(y)+12
            end,
        },
        {
            key="RaidToolsExtension",title=L("EUI Raid Tools Extension"),pages={L("EUI Raid Tools Extension")},
            description=L("Customize the compact EUI raid tools background and attach a reset-instances button. Applies only to Compact Band mode."),
            buildPage=function(_,parent,yOffset)
                local W=EUI.Widgets;local y=yOffset;local _,h
                _,h=W:SectionHeader(parent,L("Compact Band"),y);y=y-h
                _,h=W:Toggle(parent,L("Custom compact background"),y,
                    function()return ns.GetRaidExtensionSettings().customBackground~=false end,
                    function(v)ns.GetRaidExtensionSettings().customBackground=v;ns.RefreshRaidToolsExtension()end);y=y-h
                _,h=W:ColorPicker(parent,L("Background color and opacity"),y,ns.GetRaidCompactColor,
                    function(r,g,b,a)ns.GetRaidExtensionSettings().color={r,g,b,a};ns.RefreshRaidToolsExtension()end,true);y=y-h
                _,h=W:Toggle(parent,L("Custom marker opacity"),y,
                    function()return ns.GetRaidExtensionSettings().customMarkerOpacity~=false end,
                    function(v)ns.GetRaidExtensionSettings().customMarkerOpacity=v;ns.RefreshRaidToolsExtension()end);y=y-h
                for _,state in ipairs({{false,"Marker opacity without a target"},{true,"Marker opacity with a target"}})do
                    local hasTarget=state[1]
                    _,h=W:Slider(parent,L(state[2]),y,0,100,1,
                        function()return math.floor(ns.GetRaidMarkerOpacity(hasTarget)*100+.5)end,
                        function(v)
                            ns.GetRaidExtensionSettings()[hasTarget and "markerAlphaTarget"or "markerAlphaNoTarget"]=v/100
                            ns.RefreshRaidToolsExtension()
                        end,L("0% is invisible; 100% is fully visible. Applies to the eight compact marker icons."));y=y-h
                end
                _,h=W:Toggle(parent,L("Show reset-instances button"),y,
                    function()return ns.GetRaidExtensionSettings().resetButton~=false end,
                    function(v)ns.GetRaidExtensionSettings().resetButton=v;ns.RefreshRaidToolsExtension()end);y=y-h
                _,h=W:Button(parent,L("Restore default background"),y,function()
                    ns.GetRaidExtensionSettings().color=nil;ns.RefreshRaidToolsExtension()
                end);y=y-h
                return math.abs(y)+12
            end,
        },

        {
            key="QuickFocus",title=L("Quick Focus"),pages={L("Quick Focus")},
            description=L("Set focus with a shortcut and optionally apply a control marker. Mouseover takes priority over your target."),
            buildPage=function(_,parent,yOffset)
                local W=EUI.Widgets;local y=yOffset;local _,h
                local function Toggle(key,text,default)
                    _,h=W:Toggle(parent,L(text),y,
                        function()local v=ns.GetFocusSettings()[key];if v==nil then return default end;return v end,
                        function(v)ns.GetFocusSettings()[key]=v;ns.RefreshQuickFocus()end);y=y-h
                end
                _,h=W:SectionHeader(parent,L("Quick Focus"),y);y=y-h
                Toggle("enabled","Enable quick focus",true)
                _,h=W:Dropdown(parent,L("Focus shortcut"),y,
                    {['SHIFT-BUTTON1']=L("Shift + left click"),['CTRL-BUTTON1']=L("Ctrl + left click"),['ALT-BUTTON1']=L("Alt + left click"),['ALT-F']="Alt + F",['SHIFT-F']="Shift + F"},
                    function()return ns.GetFocusSettings().binding or "SHIFT-BUTTON1"end,
                    function(v)ns.GetFocusSettings().binding=v;ns.RefreshQuickFocus()end,
                    {"SHIFT-BUTTON1","CTRL-BUTTON1","ALT-BUTTON1","ALT-F","SHIFT-F"});y=y-h
                Toggle("markEnabled","Mark the focus target",true)
                local markers={};for i,key in ipairs({"Star","Circle","Diamond","Triangle","Moon","Square","Cross","Skull"})do markers[i]=L(key)end
                _,h=W:Dropdown(parent,L("Control marker"),y,markers,
                    function()return ns.GetFocusSettings().marker or 3 end,
                    function(v)ns.GetFocusSettings().marker=v;ns.RefreshQuickFocus()end,{1,2,3,4,5,6,7,8});y=y-h
                Toggle("overwrite","Replace existing target markers",false)
                return math.abs(y)+12
            end,
        },
        {
            key="Enhancements",title=L("Interface Enhancements"),pages={L("Interface Enhancements")},
            description=L("Map and window movement and known recipe colors."),
            buildPage=function(_,parent,yOffset)
                local W=EUI.Widgets;local y=yOffset;local _,h
                local function Header(key)_,h=W:SectionHeader(parent,L(key),y);y=y-h end
                local function Toggle(text,get,set,tip)
                    _,h=W:Toggle(parent,L(text),y,get,set,tip and L(tip));y=y-h
                end
                Header("Map and Blizzard windows")
                Toggle("Enable map and window movement",ns.IsWindowMovementEnabled,ns.SetWindowMovement,
                    "Uses EUI Shifter. Shift-drag to move; Shift-mousewheel to scale and save. Ctrl makes temporary adjustments. Drag the map title bar in windowed mode.")
                Toggle("Map corner resize handle",function()return ns.GetEnhancements().mapCornerResize~=false end,
                    function(v)ns.GetEnhancements().mapCornerResize=v;ns.RefreshMapResize()end,
                    "Drag the bottom-right corner to resize. Windowed mode only. The size is saved with EUI window settings.")
                Toggle("Ship and zeppelin timers",function()return ns.GetTransportSettings().enabled~=false end,
                    function(v)ns.GetTransportSettings().enabled=v;ns.RefreshTransportTimers()end,
                    "Show the next arrival or departure below EUI map transport icons. Enable EUI Map Markers and transports first. Stand still aboard a moving boat or zeppelin to calibrate. No DockWatch dependency.")
                Header("Chat Copy Window")
                Toggle("Enable chat copy enhancements",ns.IsChatCopyEnabled,
                    function(v)local db=ns.GetSettings();db.chatCopy=db.chatCopy or {};db.chatCopy.enabled=v;ns.RefreshChatCopy()end,
                    "Disable to restore EUI's original copy window, text and layout.")
                Toggle("Move and resize chat copy window",function()local db=ns.GetSettings().chatCopy;return not db or db.resizable~=false end,
                    function(v)local db=ns.GetSettings();db.chatCopy=db.chatCopy or {};db.chatCopy.resizable=v;ns.RefreshChatCopy()end,
                    "Drag the title to move or the bottom-right corner to resize. Position and size are remembered.")
                Toggle("Search copied chat",function()local db=ns.GetSettings().chatCopy;return not db or db.searchable~=false end,
                    function(v)local db=ns.GetSettings();db.chatCopy=db.chatCopy or {};db.chatCopy.searchable=v;ns.RefreshChatCopy()end)
                Toggle("Channel colors in copied chat",function()local db=ns.GetSettings().chatCopy;return not db or db.channelColors~=false end,
                    function(v)local db=ns.GetSettings();db.chatCopy=db.chatCopy or {};db.chatCopy.channelColors=v;ns.RefreshChatCopy()end,
                    "Preserve each message's original channel color and inline link colors in EUI's chat copy window.")
                Toggle("Class-colored names in copied chat",function()local db=ns.GetSettings().chatCopy;return not db or db.classNames~=false end,
                    function(v)local db=ns.GetSettings();db.chatCopy=db.chatCopy or {};db.chatCopy.classNames=v;ns.RefreshChatCopy()end,
                    "Preserve EUI's player colors first, then fill missing name colors from other messages and known class information.")
                Header("Data Bars")
                Toggle("Bel Toolbox icons",function()return ns.GetEnhancements().belMicroMenuIcons~=false end,
                    function(v)ns.GetEnhancements().belMicroMenuIcons=v;ns.RefreshMicroMenuIcons()end,
                    "Use original Bel Toolbox icons for custom data-bar micro menus. Blizzard icon style is preserved.")
                Header("Player Frame")
                Toggle("Animated resting indicator",function()return ns.GetEnhancements().animatedRestIndicator~=false end,
                    function(v)ns.GetEnhancements().animatedRestIndicator=v;ns.RefreshRestIndicator()end,
                    "Replace the player-frame ZZZ text with the clock's animated resting icon. Visibility and position follow EUI's Rested Indicator settings.")
                Header("Known Recipes")
                Toggle("Color learned recipes",function()return ns.GetEnhancements().knownRecipes~=false end,
                    function(v)ns.GetEnhancements().knownRecipes=v;ns.RefreshKnownRecipes()end,
                    "Learned recipes have a green tint and check mark in supported item slots. Unknown recipes keep their normal appearance.")
                Header("Item Highlights")
                Toggle("Quest item sparkles",function()return ns.GetEnhancements().lootSparkles~=false end,
                    function(v)ns.GetEnhancements().lootSparkles=v;ns.RefreshLootSparkles()end,
                    "Enable native loot sparkles for quest objects without changing character outlines. Disabling restores the previous setting. Changes apply after combat.")
                return math.abs(y)+12
            end,
        },

        {
            key="ChatBar",title=L("Chat Bar"),pages={L("Chat Bar")},
            description=L("Quick chat channels and useful shortcuts."),
            buildPage=function(_,parent,y)return BuildToolbarPage(parent,y,"chatBar","Chat Bar",ns.RefreshChatBar)end,
        },
        {
            key = "InventoryMail",
            title = L("Bags and Mail"),
            description = L("Record character inventories and bank visits. Mail contacts only fill the recipient."),
            pages = { L("Bags and Mail") },
            buildPage = function(pageName, parent, yOffset)
                local W=EUI.Widgets
                local y=yOffset
                local _,h
                _,h=W:SectionHeader(parent,L("Bag Shortcuts"),y);y=y-h
                _,h=W:Toggle(parent,L("Auto weapon buff"),y,
                    function()return ns.GetBagActionSettings().weaponBuff==true end,
                    function(v)ns.GetBagActionSettings().weaponBuff=v;ns.RefreshBagActions()end,
                    L("Right-click a supported stone, oil, poison or lure to apply it to a compatible equipped weapon. Off by default. Merchant, bank, mail, trade and auction clicks are preserved."));y=y-h
                _,h=W:Toggle(parent,L("Comprehend scrolls"),y,
                    function()return ns.GetBagActionSettings().comprehendScrolls~=false end,
                    function(v)ns.GetBagActionSettings().comprehendScrolls=v;ns.RefreshBagActions()end,
                    L("Mages who know Comprehend Scroll can right-click a comprehension scroll to cast on it. Out of combat only; no modifier keys."));y=y-h
                _,h=W:SectionHeader(parent,L("Offline Inventory"),y);y=y-h
                _,h=W:Toggle(parent,L("Enable offline inventory"),y,
                    ns.IsInventoryEnabled,
                    function(value)ns.GetSettings().offlineInventoryEnabled=value;ns.RefreshInventoryFeature()end,
                    L("Show the offline bank button and record bank contents. Disabling keeps saved snapshots."));y=y-h
                _,h=W:SectionHeader(parent,L("Mail Contacts"),y);y=y-h
                _,h=W:Toggle(parent,L("Show contacts button at the mailbox"),y,
                    function()return ns.GetSettings().mailContactsEnabled~=false end,
                    function(value)ns.GetSettings().mailContactsEnabled=value;ns.RefreshMailContacts()end);y=y-h
                return math.abs(y)+12
            end,
        },
        {
            key = "MageBar",
            title = L("Mage Bar"),
            description = L("Teleports, portals, mana gems, water and food. Hover to expand; click to cast the last selected spell."),
            pages = { L("Mage Bar") },
            buildPage = function(pageName, parent, yOffset)
                local W = EUI.Widgets
                local y = yOffset
                local _, h
                _, h = W:SectionHeader(parent, L("Mage Bar"), y); y=y-h
                local function Toggle(key, label, default)
                    _, h = W:Toggle(parent, L(label), y,
                        function() local v=ns.GetMageSettings()[key]; if v==nil then return default end; return v end,
                        function(value) ns.GetMageSettings()[key]=value; ns.RefreshMageBar() end)
                    y=y-h
                end
                Toggle("enabled", "Enable mage travel bar", true)
                Toggle("large", "Use larger buttons", false)
                _, h = W:Dropdown(parent, L("Expansion direction"), y,
                    { UP=L("Up"), DOWN=L("Down"), LEFT=L("Left"), RIGHT=L("Right") },
                    ns.GetMageDirection,
                    function(value) ns.GetMageSettings().direction=value; ns.RefreshMageBar() end,
                    { "UP", "DOWN", "LEFT", "RIGHT" })
                y=y-h
                return math.abs(y)+12
            end,
        },
        {
            key = "Merchant",
            title = L("Merchant Assistant"),
            description = L("Shift-left-click a vendor item to enter an item count. Gold purchases supported; use the native UI for special currencies and unique items."),
            pages = { L("Bulk Purchase") },
            buildPage = function(pageName, parent, yOffset)
                local W = EUI.Widgets
                local y = yOffset
                local _, h
                _, h = W:SectionHeader(parent, L("Bulk Purchase"), y); y = y - h
                _, h = W:Toggle(parent,L("Four-column merchant layout"),y,
                    function()return ns.GetEnhancements().merchantColumns~=false end,
                    function(v)ns.GetEnhancements().merchantColumns=v;ns.RefreshMerchantLayout()end,
                    L("Show 20 vendor items per page in four columns. Native purchase buttons and Shift-click bulk purchase are preserved."));y=y-h
                _, h = W:Toggle(parent, L("Enable merchant assistant"), y,
                    function() return ns.GetMerchantSettings().enabled ~= false end,
                    function(value)
                        ns.GetMerchantSettings().enabled = value
                        if not value and BelToolboxMerchantFrame then BelToolboxMerchantFrame:Hide() end
                    end,
                    L("Shift-left-click a vendor item. Disable BuyEmAll to avoid duplicate purchase windows.")); y = y - h
                return math.abs(y) + 12
            end,
        },
        {
            key = "Tooltips",
            title = title,
            description = L("Show AFK and DND status in player tooltips."),
            pages = { page, L("Tooltip Colors") },
            buildPage = function(pageName, parent, yOffset)
                local W = EUI.Widgets
                local y = yOffset
                local _, h
                if pageName == L("Tooltip Colors") then
                _,h=W:SectionHeader(parent,L("Tooltip Colors"),y);y=y-h
                local function ColorToggle(key,label)
                    _,h=W:Toggle(parent,L(label),y,
                        function()return ns.GetTooltipColorSettings()[key]~=false end,
                        function(value)ns.GetTooltipColorSettings()[key]=value;ns.RefreshTooltipColors()end)
                    y=y-h
                end
                ColorToggle("enabled","Enable tooltip colors")
                ColorToggle("unitBorder","Unit border by class or reaction")
                ColorToggle("itemBorder","Item border by quality")
                ColorToggle("unitName","Unit name by class or reaction")
                ColorToggle("guild","Color guild names")
                ColorToggle("level","Level color by difficulty")
                ColorToggle("class","Color class text")
                ColorToggle("faction","Color faction text")
                    return math.abs(y) + 12
                end

                _, h = W:SectionHeader(parent, page, y)
                y = y - h

                local function Toggle(label, key, tooltip)
                    _, h = W:Toggle(parent, label, y,
                        function() return ns.GetSettings()[key] ~= false end,
                        function(value) ns.GetSettings()[key] = value end,
                        tooltip)
                    y = y - h
                end

                Toggle(L("Show owned item counts"), "ownedCounts",
                    L("Show recorded bag and bank counts for your characters. Visit each bank to refresh its snapshot."))
                Toggle(L("Show item title icons"), "itemTitleIcons",
                    L("Show an item icon to the left of its tooltip name."))
                Toggle(L("Show spell title icons"), "spellTitleIcons",
                    L("Show spell and aura icons to the left of their tooltip names."))
                Toggle(L("Enable status tooltips"), "enabled",
                    L("Show status beside the player name in angle brackets."))
                Toggle(L("Show AFK status"), "showAFK",
                    L("Show AFK text in the client language."))
                Toggle(L("Show DND status"), "showDND",
                    L("Show DND text in the client language."))
                return math.abs(y) + 12
            end,
        },
    },
})

if registered then
    SLASH_BELTOOLBOX1 = "/beltoolbox"
    SLASH_BELTOOLBOX2 = "/bel"
    SlashCmdList.BELTOOLBOX = function()
        EUI.OpenPlugin(addonName, "Tooltips", page)
    end
end
