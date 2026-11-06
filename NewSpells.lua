local _,ns=...
local L=ns.L
local events=CreateFrame("Frame")
local panel,buttons,page
local spells,listed,pending={},{},{}
local queued
local generation=0
local PAGE_SIZE=8
local function Enabled()return ns.GetEnhancements().newSpells==true end
local function Plain(value)return not (issecretvalue and issecretvalue(value))end
local function SpellSlot(id)
    local book=C_SpellBook
    if not book or not book.FindSpellBookSlotForSpell then return end
    return book.FindSpellBookSlotForSpell(id,true)
end
local function Build()
    panel=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    panel:SetSize(340,120);panel:SetPoint("CENTER",0,100)
    panel:SetFrameStrata("DIALOG");panel:SetClampedToScreen(true)
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    panel:SetBackdropColor(.09,.09,.09,.96);panel:SetBackdropBorderColor(.45,.38,.29,1)
    panel:EnableMouse(true);panel:SetMovable(true);panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",panel.StartMoving)
    panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
    local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOP",0,-9);title:SetText(L("Newly learned spells"))
    local close=CreateFrame("Button",nil,panel,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",0,0);close:SetScript("OnClick",function()panel:Hide()end)
    panel.hint=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    panel.hint:SetPoint("BOTTOM",0,10)
    buttons={}
end
local function Show()
    if not Enabled()or InCombatLockdown()or #spells==0 then if panel then panel:Hide()end;return end
    if not panel then Build()end
    local pages=math.ceil(#spells/PAGE_SIZE)
    page=math.max(1,math.min(page or pages,pages))
    for i=1,PAGE_SIZE do
        local button=buttons[i]
        if not button then
            button=CreateFrame("Button",nil,panel)
            button:SetSize(34,34);button:SetPoint("TOPLEFT",12+(i-1)*40,-33)
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetAllPoints()
            button:RegisterForDrag("LeftButton");button:RegisterForClicks("RightButtonUp")
            button:SetScript("OnDragStart",function(self)
                if self.spell and not InCombatLockdown()and not GetCursorInfo()and SpellSlot(self.spell)then
                    C_Spell.PickupSpell(self.spell)
                end
            end)
            button:SetScript("OnClick",function(self)
                local id=self.spell
                for index,spell in ipairs(spells)do
                    if spell==id then table.remove(spells,index);listed[id]=nil;break end
                end
                GameTooltip:Hide();Show()
            end)
            button:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spell);GameTooltip:Show()
            end)
            button:SetScript("OnLeave",function()GameTooltip:Hide()end)
            buttons[i]=button
        end
        local id=spells[(page-1)*PAGE_SIZE+i]
        button.spell=id
        if id then button.icon:SetTexture(C_Spell.GetSpellTexture(id)or 134400)end
        button:SetShown(id~=nil)
    end
    if not panel.previous then
        local function PageButton(label,offset,delta)
            local button=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
            button:SetSize(25,20);button:SetPoint("BOTTOM",offset,27);button:SetText(label)
            button:SetScript("OnClick",function()page=page+delta;Show()end)
            return button
        end
        panel.previous=PageButton("<",-45,-1);panel.next=PageButton(">",45,1)
        panel.counter=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        panel.counter:SetPoint("BOTTOM",0,32)
    end
    panel.previous:SetShown(pages>1);panel.next:SetShown(pages>1)
    panel.counter:SetShown(pages>1);panel.counter:SetText(page.."/"..pages)
    panel.hint:SetText(L("Drag to your action bar. Right-click to dismiss."))
    panel:Show()
end
local function AddSpell(id)
    local slot,bank=SpellSlot(id)
    if not slot then return nil end
    if listed[id]or C_SpellBook.IsSpellBookItemPassive(slot,bank)
        or C_SpellBook.GetSpellBookItemType(slot,bank)~=Enum.SpellBookItemType.Spell then return false end
    spells[#spells+1]=id;listed[id]=true
    return true
end
local function Flush()
    queued=nil
    if not Enabled()or InCombatLockdown()then return end
    local added,retry
    for _,id in ipairs(pending)do
        local result=AddSpell(id)
        if result then added=true
        elseif result==nil then retry=retry or {};retry[#retry+1]=id end
    end
    pending={}
    if added then page=nil;Show()end
    if retry then
        local current=generation
        C_Timer.After(.5,function()
            if current~=generation or not Enabled()then return end
            if InCombatLockdown()then for _,id in ipairs(retry)do pending[#pending+1]=id end;return end
            local found
            for _,id in ipairs(retry)do if AddSpell(id)then found=true end end
            if found then page=nil;Show()end
        end)
    end
end
function ns.RefreshNewSpells()
    if Enabled()then events:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
    else
        generation=generation+1;queued=nil
        events:UnregisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
        spells,listed,pending={},{},{};page=nil
        if panel then panel:Hide()end
    end
end
events:RegisterEvent("PLAYER_LOGIN");events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event,id,_,guildPerk)
    if event=="PLAYER_LOGIN"then ns.RefreshNewSpells()
    elseif event=="PLAYER_REGEN_ENABLED"then if #pending>0 then Flush()end
    elseif Plain(id)and type(id)=="number"and id>0 and Plain(guildPerk)and not guildPerk then
        pending[#pending+1]=id
        if not queued and not InCombatLockdown()then
            queued=true
            local current=generation
            C_Timer.After(.15,function()if current==generation then Flush()end end)
        end
    end
end)
SLASH_BELNEWSPELLS1="/belnewspells"
SlashCmdList.BELNEWSPELLS=Show
