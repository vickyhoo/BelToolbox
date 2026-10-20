-- Native item templates and native purchase indices are preserved (4 columns x 5 rows).
local _,ns=...
local original,hooked,busy,dirty,applied
local skin=ns.skin
local owned,centred,lifted={},{},setmetatable({},{__mode="k"})
local function Wanted()
    return ns.GetEnhancements().merchantColumns~=false and not(_G.EllesmereUIDB and EllesmereUIDB.merchantShowAsList)
end
local controls={"MerchantPageText","MerchantPrevPageButton","MerchantNextPageButton","MerchantRepairAllButton","MerchantRepairItemButton","MerchantSellAllJunkButton","MerchantGuildBankRepairButton","MerchantBuyBackItem"}
local function Capture(frame)
    local points={}
    for i=1,frame:GetNumPoints()do points[i]={frame:GetPoint(i)}end
    return points
end
local function Place(frame,...)
    if frame then frame:ClearAllPoints();frame:SetPoint(...)end
end
local function Restore()
    if not original then return end
    MerchantFrame:SetSize(original.width,original.height)
    MERCHANT_ITEMS_PER_PAGE=original.pageSize
    for frame,points in pairs(original.points)do
        frame:ClearAllPoints();for _,p in ipairs(points)do frame:SetPoint(unpack(p))end
    end
    for i=original.pageSize+1,20 do if _G["MerchantItem"..i]then _G["MerchantItem"..i]:Hide()end end
end
local function SkinExtraSlots()
    if not skin then return end
    for i=13,20 do
        local holder=_G["MerchantItem"..i]
        if holder and owned[i]then
            skin.Panel(holder)
            local name=_G["MerchantItem"..i.."Name"]
            if name then name:SetWordWrap(true);name:SetMaxLines(2)end
            local button=_G["MerchantItem"..i.."ItemButton"]
            if button then
                local normal=button:GetNormalTexture()
                if normal then normal:SetAlpha(0)end
                local slot=_G["MerchantItem"..i.."ItemButtonSlot"]
                if slot then slot:SetAlpha(0)end
                local border=button.IconBorder or _G["MerchantItem"..i.."ItemButtonIconBorder"]
                if border then border:SetAlpha(0)end
                local icon=button.Icon or button.icon or _G["MerchantItem"..i.."ItemButtonIconTexture"]
                if icon then skin.SquareIcon(icon,button,true)end
                if not centred[button]then centred[button]=true;Place(button,"LEFT",holder,"LEFT",0,0)end
            end
            for _,suffix in ipairs({"MoneyFrame","AltCurrencyFrame"})do
                local f=_G["MerchantItem"..i..suffix]
                if f and f:GetNumPoints()>0 then
                    local p,rel,rp,x,y=f:GetPoint(1)
                    local previous=lifted[f]
                    if not previous or previous.rel~=rel or previous.y~=y then
                        f:SetPoint(p,rel,rp,x or 0,(y or 0)+6);lifted[f]={rel=rel,y=(y or 0)+6}
                    end
                end
            end
        end
    end
end
local function Layout()
    if busy or not MerchantFrame or not original or InCombatLockdown()then return end
    if not Wanted()then return end
    local width=original.itemWidth*4+66
    MerchantFrame:SetSize(width,original.height)
    for i=1,20 do
        local item=_G["MerchantItem"..i]
        if item then
            local column=(i-1)%4;local row=math.floor((i-1)/4)
            Place(item,"TOPLEFT",MerchantFrame,"TOPLEFT",11+column*(original.itemWidth+12),-69-row*(original.itemHeight+8))
            if MerchantFrame.selectedTab==2 then
                -- Native buyback shows each item button, but assumes holders 1-10
                -- stayed visible on the vendor tab (it only re-shows 11/12).
                -- Restore ALL buyback holders, including those previously hidden
                -- on a short vendor page; hide extra vendor-only tiles.
                item:SetShown(i<=(BUYBACK_ITEMS_PER_PAGE or 12))
            else
                -- Keep a complete grid, including empty card backgrounds. Native updates
                -- clear unused item buttons; their holders 11/12 are buyback-only in stock
                -- and must be shown again even when the vendor has fewer than 12 goods.
                item:Show()
            end
        end
    end
    Place(MerchantPageText,"BOTTOM",MerchantFrame,"BOTTOMLEFT",width/2,86)
    Place(MerchantPrevPageButton,"CENTER",MerchantFrame,"BOTTOMLEFT",25,96)
    Place(MerchantNextPageButton,"CENTER",MerchantFrame,"BOTTOMLEFT",width-26,96)
    Place(MerchantRepairAllButton,"BOTTOM",MerchantFrame,"BOTTOMLEFT",width/2,34)
    if MerchantRepairItemButton and MerchantRepairAllButton then Place(MerchantRepairItemButton,"RIGHT",MerchantRepairAllButton,"LEFT",-4,0)end
    if MerchantSellAllJunkButton then Place(MerchantSellAllJunkButton,"BOTTOM",MerchantFrame,"BOTTOMLEFT",width/2+50,34)end
    if MerchantGuildBankRepairButton then Place(MerchantGuildBankRepairButton,"BOTTOM",MerchantFrame,"BOTTOMLEFT",width/2+90,34)end
    SkinExtraSlots()
    if MerchantFrame.selectedTab~=2 then Place(MerchantBuyBackItem,"BOTTOMRIGHT",MerchantFrame,"BOTTOMRIGHT",-8,33)end
end
function ns.RefreshMerchantLayout()
    if busy then return end
    if InCombatLockdown()then dirty=true;return end
    dirty=nil
    if not MerchantFrame or not MerchantItem1 then return end
    busy=true
    if not original then
        original={width=MerchantFrame:GetWidth(),height=MerchantFrame:GetHeight(),pageSize=MERCHANT_ITEMS_PER_PAGE or 10,
            itemWidth=MerchantItem1:GetWidth(),itemHeight=MerchantItem1:GetHeight(),points={}}
        for i=1,20 do
            local f=_G["MerchantItem"..i];if f then original.points[f]=Capture(f)end
        end
        for _,name in ipairs(controls)do local f=_G[name];if f then original.points[f]=Capture(f)end end
    end
    if Wanted()then
        for i=1,20 do
            if not _G["MerchantItem"..i]then
                local frame=CreateFrame("Frame","MerchantItem"..i,MerchantFrame,"MerchantItemTemplate")
                frame:SetID(i);owned[i]=true
            end
        end
        MERCHANT_ITEMS_PER_PAGE=20;applied=true
    else Restore();applied=false end
    if not hooked then
        hooked=true
        for _,name in ipairs({"MerchantFrame_Update","MerchantFrame_UpdateMerchantInfo","MerchantFrame_UpdateBuybackInfo","MerchantFrame_UpdateRepairButtons"})do
            if type(_G[name])=="function"then hooksecurefunc(name,function()
                if busy then return end
                if Wanted()~=applied then ns.RefreshMerchantLayout()else Layout()end
            end)end
        end
    end
    if MerchantFrame:IsShown()and MerchantFrame_Update then MerchantFrame_Update()end
    busy=nil;Layout()
end
function ns.RefreshMerchantSkin(S)skin=S;if original then Layout()end end
local events=CreateFrame("Frame")
for _,event in ipairs({"MERCHANT_SHOW","PLAYER_LOGIN","ADDON_LOADED","PLAYER_REGEN_ENABLED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,addon)
    if event=="PLAYER_REGEN_ENABLED"and not dirty then return end
    if event=="ADDON_LOADED"and addon~="Blizzard_MerchantUI"then return end
    ns.RefreshMerchantLayout()
end)
