-- Item-targeted hardware clicks; original bag buttons remain unmodified.
local _,ns=...
local COMPREHEND=1296017
local overlay,owner,queued,registered
local slots=setmetatable({},{__mode="k"})
local hooked=setmetatable({},{__mode="k"})
function ns.GetBagActionSettings()
    local db=ns.GetSettings();db.bagActions=db.bagActions or {};return db.bagActions
end
local function Readable(value)return not(issecretvalue and issecretvalue(value))end
local buffs={}
local function Items(kind,ids)for _,id in ipairs(ids)do buffs[id]=kind end end
Items("sharp",{2862,2863,2871,7964,12404,18262,23122})
Items("blunt",{3239,3240,3241,7965,12643})
Items("oil",{20744,20746,20750,20749,20745,20747,20748,23123,3824,3829})
Items("poison",{6947,6949,6950,8926,8927,8928,2892,2893,8984,8985,20844,3775,3776,5237,6951,9186,10918,10920,10921,10922})
Items("lure",{6529,6530,6532,6533,7307,6811})
local sharp={[0]=true,[1]=true,[6]=true,[7]=true,[8]=true,[15]=true}
local blunt={[4]=true,[5]=true,[10]=true}
local melee={[0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[10]=true,[13]=true,[15]=true}
local scrolls={}
for _,id in ipairs({211780,211784,211785,211786,211787,211853,211854,211855,
    213543,213544,213545,213546,213547,281015,281016,281017,281018})do scrolls[id]=true end
local function Fits(kind,inventorySlot)
    local id=GetInventoryItemID and GetInventoryItemID("player",inventorySlot)
    if not Readable(id)or not id or not C_Item or not C_Item.GetItemInfoInstant then return false end
    local _,_,_,_,_,class,subclass=C_Item.GetItemInfoInstant(id)
    if not Readable(class)or not Readable(subclass)or class~=2 then return false end
    if kind=="lure"then return inventorySlot==16 and subclass==20 end
    if kind=="sharp"then return sharp[subclass]or false end
    if kind=="blunt"then return blunt[subclass]or false end
    return melee[subclass]or false
end
local function EnchantTime(inventorySlot)
    if C_Item and C_Item.GetWeaponEnchantInfo then
        local shortest
        for _,enchant in pairs(C_Item.GetWeaponEnchantInfo(inventorySlot-16)or {})do
            if Readable(enchant.hasEnchant)and enchant.hasEnchant then
                local t=enchant.timeLeft
                if not Readable(t)or type(t)~="number"then t=0 end
                shortest=shortest and math.min(shortest,t)or t
            end
        end
        return shortest
    end
    if GetWeaponEnchantInfo then
        local mh,mt,_,_,oh,ot=GetWeaponEnchantInfo()
        local has,time
        if inventorySlot==16 then has,time=mh,mt else has,time=oh,ot end
        if not Readable(has)or not has then return end
        return Readable(time)and type(time)=="number"and time or 0
    end
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
        local info=C_PaperDollInfo.GetTemporaryEnchantmentInfo(inventorySlot)
        if info then local t=info.remainingTimeMs;return Readable(t)and type(t)=="number"and t or 0 end
    end
end
local function WeaponSlot(kind)
    local main,off=Fits(kind,16),Fits(kind,17)
    if main and off then
        local mt,ot=EnchantTime(16),EnchantTime(17)
        return mt~=nil and (ot==nil or ot<mt)and 17 or 16
    end
    return main and 16 or off and 17 or nil
end
local function KnowsComprehend()
    local _,class=UnitClass("player")
    if class~="MAGE"then return false end
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        local found=C_SpellBook.IsSpellInSpellBook(COMPREHEND,bank,false)
        if Readable(found)and found then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local found=C_SpellBook.IsSpellKnown(COMPREHEND,bank)
        if Readable(found)and found then return true end
    end
    if IsSpellKnown then local found=IsSpellKnown(COMPREHEND);return Readable(found)and found or false end
    return false
end
local function IsScroll(id,bag,slot)
    if scrolls[id]then return true end
    local skill=C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
        and C_TradeSkillUI.GetProfessionInfoBySkillLineID(3012)
    local name=skill and skill.professionName
    if not Readable(name)or type(name)~="string"or name==""then return false end
    local data=C_TooltipInfo and C_TooltipInfo.GetBagItem and C_TooltipInfo.GetBagItem(bag,slot)
    for _,line in ipairs(data and data.lines or {})do
        local text=line.leftText
        if Readable(text)and type(text)=="string"and text:find(name,1,true)and text:find("%(%d+%)")then return true end
    end
    return false
end
local busyFrames={"MerchantFrame","BankFrame","EUI_BankFrame","SendMailFrame","MailFrame",
    "TradeFrame","AuctionHouseFrame","AuctionFrame","GuildBankFrame","AccountBankPanel"}
local interacting={}
local function Visible(frame)
    if not frame then return false end
    local visible
    if frame.IsVisible then visible=frame:IsVisible()else visible=frame:IsShown()end
    return Readable(visible)and visible or false
end
local function Busy()
    if next(interacting)then return "interaction"end
    -- IsShown ignores hidden ancestors. SendMailFrame/AccountBankPanel can
    -- stay shown after their window closes, blocking every future bag click.
    for _,name in ipairs(busyFrames)do if Visible(_G[name])then return name end end
    return false
end
local function Modified()
    return (IsShiftKeyDown and IsShiftKeyDown())or(IsControlKeyDown and IsControlKeyDown())or(IsAltKeyDown and IsAltKeyDown())
end
local function Action(bag,slot)
    local last=Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
    if not C_Container or type(bag)~="number"or bag<0 or bag>last or type(slot)~="number"or slot<1 then return end
    local id=C_Container.GetContainerItemID(bag,slot)
    if not Readable(id)or type(id)~="number"then return end
    local db=ns.GetBagActionSettings()
    if db.weaponBuff==true and buffs[id]then
        local target=WeaponSlot(buffs[id])
        if target then return "item",bag.." "..slot,nil,target,id end
    end
    if db.comprehendScrolls~=false and KnowsComprehend()and IsScroll(id,bag,slot)then
        return "spell",COMPREHEND,bag,slot,id
    end
end
local function Hide()
    if overlay and not InCombatLockdown()then
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(overlay)then GameTooltip:Hide()end
        overlay:Hide();owner=nil
    end
end
local function Tooltip()
    local data=owner and slots[owner]
    if not data then return end
    GameTooltip:SetOwner(overlay,"ANCHOR_RIGHT");GameTooltip:SetBagItem(data.bag,data.slot)
    local kind=Action(data.bag,data.slot)
    GameTooltip:AddLine(ns.L(kind=="spell"and "Right-click: comprehend this scroll."or "Right-click: apply to an equipped weapon."),.4,.85,1,true)
    GameTooltip:Show()
end
local function Build()
    overlay=CreateFrame("Button","BelToolboxBagAction",UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
    overlay:Hide();overlay:RegisterForClicks("AnyUp")
    overlay:SetAttribute("useOnKeyDown",false)
    -- Hide securely even if combat lockdown is already active when events fire.
    overlay:SetAttribute("_onstate-combat",[[if newstate=="combat"then self:Hide()end]])
    RegisterStateDriver(overlay,"combat","[combat] combat; rest")
    overlay:SetScript("PreClick",function(self,mouse)
        if InCombatLockdown()then return end
        -- Pass-through defaults preserve normal and modified bag clicks.
        self:SetAttribute("type2","click")
        for _,key in ipairs({"item","spell","target-bag","target-slot"})do self:SetAttribute(key,nil)end
        local data=owner and slots[owner]
        if mouse~="RightButton"or not data or Busy()or Modified()or not Visible(owner)then return end
        -- Re-read at the hardware click, not from a cached item/weapon selection.
        local kind,value,bag,slot=Action(data.bag,data.slot)
        if kind then
            self:SetAttribute("type2",kind);self:SetAttribute(kind,value)
            self:SetAttribute("target-bag",bag);self:SetAttribute("target-slot",slot)
        end
    end)
    overlay:SetScript("OnEnter",Tooltip)
    overlay:SetScript("OnLeave",Hide)
    overlay:SetScript("OnHide",function()
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(overlay)then GameTooltip:Hide()end
    end)
    local function Drag()
        if InCombatLockdown()then return end
        local data=owner and slots[owner]
        if data and C_Container.PickupContainerItem then C_Container.PickupContainerItem(data.bag,data.slot)end
        Hide()
    end
    overlay:RegisterForDrag("LeftButton");overlay:SetScript("OnDragStart",Drag);overlay:SetScript("OnReceiveDrag",Drag)
end
local function Hover(button)
    if InCombatLockdown()or Modified()or Busy()then return end
    local data=slots[button]
    if not data or not Action(data.bag,data.slot)then return end
    if not overlay then Build()end
    Hide();owner=button
    local host=button._textOverlay or button:GetParent()
    overlay:SetParent(host)
    overlay:ClearAllPoints();overlay:SetAllPoints(button)
    overlay:SetFrameStrata(button:GetFrameStrata())
    overlay:SetFrameLevel(math.max(button:GetFrameLevel(),host and host:GetFrameLevel()or 0)+2)
    overlay:SetAttribute("type1","click");overlay:SetAttribute("clickbutton1",button)
    overlay:SetAttribute("type2","click");overlay:SetAttribute("clickbutton2",button)
    overlay:Show()
end
local function Track(button,bag,slot)
    local last=Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
    if type(bag)~="number"or bag<0 or bag>last or type(slot)~="number"or slot<1 then
        if owner==button then Hide()end
        slots[button]=nil;return
    end
    local id=C_Container and C_Container.GetContainerItemID(bag,slot)
    local old=slots[button]
    if owner==button and (not old or old.bag~=bag or old.slot~=slot or old.id~=id)then Hide()end
    slots[button]={bag=bag,slot=slot,id=id}
    if not hooked[button]then
        hooked[button]=true
        button:HookScript("OnEnter",Hover)
        button:HookScript("OnLeave",function()if owner==button and overlay and not overlay:IsMouseOver()then Hide()end end)
        button:HookScript("OnHide",function()if owner==button then Hide()end end)
    end
end
local Queue
local function ScanNative()
    local containers={}
    if _G.ContainerFrameCombinedBags then containers[#containers+1]=ContainerFrameCombinedBags end
    for i=1,_G.NUM_CONTAINER_FRAMES or 13 do local f=_G["ContainerFrame"..i];if f then containers[#containers+1]=f end end
    for _,frame in ipairs(containers)do
        if not hooked[frame]then
            hooked[frame]=true;frame:HookScript("OnShow",Queue);frame:HookScript("OnHide",Hide)
            if type(frame.UpdateItems)=="function"then hooksecurefunc(frame,"UpdateItems",Queue)end
        end
        if frame:IsShown()and frame.EnumerateValidItems then
            for _,button in frame:EnumerateValidItems()do
                local bag=button.GetBagID and button:GetBagID()or button:GetParent():GetID()
                Track(button,bag,button:GetID())
            end
        end
    end
end
function ns.RefreshBagActions()
    if InCombatLockdown()then return end
    local previous=owner
    Hide();ScanNative()
    local bags=_G.EUI_Bags
    if bags and type(bags.RegisterItemOverlayIcon)=="function"and registered~=bags then
        registered=bags
        bags.RegisterItemOverlayIcon("BelToolboxBagActions",function(button,data)
            -- EUI reuses data tables. Keep only our own copied coordinates.
            Track(button,data.bag,data.slot)
        end)
        if bags:IsShown()and bags.RefreshInventory then bags:RefreshInventory()end
    end
    if previous and Visible(previous)and previous:IsMouseOver()then Hover(previous)end
end
Queue=function()
    if queued then return end
    queued=true;C_Timer.After(0,function()queued=nil;ns.RefreshBagActions()end)
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ADDON_LOADED","BAG_UPDATE_DELAYED",
    "PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_EQUIPMENT_CHANGED","SPELLS_CHANGED",
    "MODIFIER_STATE_CHANGED","MERCHANT_SHOW","BANKFRAME_OPENED","MAIL_SHOW","TRADE_SHOW","AUCTION_HOUSE_SHOW",
    "GUILDBANKFRAME_OPENED","PLAYER_INTERACTION_MANAGER_FRAME_SHOW","PLAYER_INTERACTION_MANAGER_FRAME_HIDE"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,value)
    if event=="PLAYER_INTERACTION_MANAGER_FRAME_SHOW"or event=="PLAYER_INTERACTION_MANAGER_FRAME_HIDE"then
        local t=Enum and Enum.PlayerInteractionType or {}
        for _,key in ipairs({"Merchant","Banker","AccountBanker","MailInfo","TradePartner","Auctioneer","GuildBanker"})do
            if t[key]~=nil and value==t[key]then interacting[value]=event=="PLAYER_INTERACTION_MANAGER_FRAME_SHOW"or nil;break end
        end
    end
    if event=="ADDON_LOADED"and value~="EllesmereUIBags"and value~="Blizzard_ContainerUI"then return end
    if event=="PLAYER_REGEN_DISABLED"then Hide();return end
    if event=="MODIFIER_STATE_CHANGED"then
        if Modified()then Hide()end
        return
    end
    Hide();Queue()
end)

-- On-demand diagnostics: report eligibility without attempting a protected action.
SLASH_BELBAGDEBUG1="/belbagdebug"
SlashCmdList.BELBAGDEBUG=function()
    local count=0;for _ in pairs(slots)do count=count+1 end
    local _,class=UnitClass("player")
    local db=ns.GetBagActionSettings()
    local data=owner and slots[owner]
    local target=data and (data.bag..":"..data.slot)or "-"
    print(ns.L("Bel Toolbox")..": "..ns.L("Bag shortcut diagnostic: class=%s, comprehend=%s, known=%s, combat=%s, busy=%s, EUI=%s, slots=%d, overlay=%s, target=%s",
        tostring(class),tostring(db.comprehendScrolls~=false),tostring(KnowsComprehend()),
        tostring(InCombatLockdown()),tostring(Busy()or "-"),tostring(registered~=nil),count,
        tostring(Visible(overlay)),target))
end
