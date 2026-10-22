local _,ns=...
local T,L=ns.Toolbars,ns.L
function T.Growth(db)
    return(db.growth=="LEFT"or db.growth=="CENTER")and db.growth or "RIGHT"
end
function T.BarSlot(db,index,count,perRow,size,gap)
    local column,row=(index-1)%perRow,math.floor((index-1)/perRow)
    local direction=T.Growth(db)
    if direction=="LEFT"then return "TOPRIGHT",-column*(size+gap),-row*(size+gap)end
    if direction=="CENTER"then
        local inRow=math.min(perRow,count-row*perRow)
        return "TOP",(column-(inRow-1)/2)*(size+gap),-row*(size+gap)
    end
    return "TOPLEFT",column*(size+gap),-row*(size+gap)
end
function T.AnchorBarButton(button,root,db,index,count,perRow,size,gap,setAnchor)
    local point,x,y=T.BarSlot(db,index,count,perRow,size,gap)
    if setAnchor then setAnchor(button,point,root,point,x,y)
    else button:ClearAllPoints();button:SetPoint(point,root,point,x,y)end
end
function T.SetGrowth(root,db,value,refresh)
    if InCombatLockdown()then return end
    local left,top=root:GetLeft(),root:GetTop()
    if left and top then
        local scale=root:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local fraction=value=="LEFT"and 1 or(value=="CENTER"and .5 or 0)
        db.position={point=value=="LEFT"and "TOPRIGHT"or(value=="CENTER"and "TOP"or "TOPLEFT"),
            relPoint="BOTTOMLEFT",x=(left+root:GetWidth()*fraction)*scale,y=top*scale}
    end
    db.growth=value;refresh()
end
local editors={}
function T.RegisterBarEditor(root,key,title,getSettings,refresh,getSize,getGap,rowKey,maxRow,defaultRow)
    local EUI=_G.EllesmereUI
    if editors[key]or not EUI or not EUI.RegisterUnlockModeListener then return end
    defaultRow=defaultRow or maxRow
    local panel=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    editors[key]=panel;root.belQuickEdit=panel
    panel:SetSize(300,62);panel:SetFrameStrata("FULLSCREEN_DIALOG");panel:SetClampedToScreen(true)
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    panel:SetBackdropColor(.08,.09,.1,.96);panel:SetBackdropBorderColor(.55,.43,.3,1)
    panel:SetPoint("BOTTOM",root,"TOP",0,24);panel:Hide()
    local heading=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    heading:SetPoint("TOPLEFT",8,-7);heading:SetText(L(title))
    local function Button(parent,text,x,y,width,action)
        local button=CreateFrame("Button",nil,parent)
        button:SetSize(width,20);button:SetPoint("TOPLEFT",x,y)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        button.label=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        button.label:SetPoint("CENTER");button.label:SetText(text)
        button:SetScript("OnClick",function()if not InCombatLockdown()then action()end end)
        return button
    end
    local menu=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    menu:SetSize(140,72);menu:SetPoint("TOPRIGHT",panel,"BOTTOMRIGHT",0,-2)
    menu:SetFrameLevel(panel:GetFrameLevel()+10);menu:SetClampedToScreen(true)
    menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    menu:SetBackdropColor(.08,.09,.1,1);menu:SetBackdropBorderColor(.55,.43,.3,1);menu:Hide()
    local names={CENTER="Grow centered",LEFT="Grow left",RIGHT="Grow right"}
    local growth
    local function Update()
        if panel.sizeLabel then
            panel.sizeLabel:SetText(L("Button size")..": "..getSize())
            panel.gapLabel:SetText(L("Button spacing")..": "..getGap())
            panel.rowLabel:SetText(L("Buttons per row")..": "..(getSettings()[rowKey]or defaultRow))
            growth.label:SetText(L(names[T.Growth(getSettings())]).." ▾")
        end
    end
    local function Step(label,x,field,get,low,high)
        local text=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        text:SetPoint("TOPLEFT",x,-26)
        for i,delta in ipairs({-1,1})do
            Button(panel,delta<0 and "−"or "+",x+(i-1)*42,-42,36,function()
                getSettings()[field]=math.max(low,math.min(high,get()+delta));refresh();Update()
            end)
        end
        return text
    end
    panel.sizeLabel=Step("size",8,"size",getSize,18,64)
    panel.gapLabel=Step("spacing",105,"spacing",getGap,0,16)
    panel.rowLabel=Step("rows",202,rowKey,function()return getSettings()[rowKey]or defaultRow end,1,maxRow)
    growth=Button(panel,"",151,-3,140,function()menu:SetShown(not menu:IsShown())end)
    for i,value in ipairs({"CENTER","LEFT","RIGHT"})do
        Button(menu,L(names[value]),4,-4-(i-1)*22,132,function()
            menu:Hide();T.SetGrowth(root,getSettings(),value,refresh);Update()
        end)
    end
    -- Reuse EUI's session notifications so Discard also restores these settings.
    local snapshot,active
    EUI:RegisterUnlockModeListener("BelToolboxEdit"..key,function(open,action)
        active=open
        if open then
            snapshot={}
            for _,field in ipairs({"size","spacing",rowKey,"growth"})do snapshot[field]={getSettings()[field]}end
            Update();panel:SetShown(root:IsShown()and not InCombatLockdown())
        else
            panel:Hide();menu:Hide()
            if action=="discard"and snapshot then
                for field,value in pairs(snapshot)do getSettings()[field]=value[1]end
                refresh()
            end
            snapshot=nil
        end
    end)
    root:HookScript("OnHide",function()panel:Hide();menu:Hide()end)
    root:HookScript("OnShow",function()if active and not InCombatLockdown()then Update();panel:Show()end end)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED");panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED"then panel:Hide();menu:Hide()
        elseif active and root:IsShown()then Update();panel:Show()end
    end)
end
