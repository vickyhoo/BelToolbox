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
    panel:SetPoint("BOTTOM",root,"TOP",0,6);panel:Hide()
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
    local watcher=CreateFrame("Frame",nil,UIParent)
    watcher:Hide()
    local elapsed,overTime,awayTime=0,0,0
    local moverKey=key=="mage"and "BelToolboxMageBar"or "BelToolboxConsumables"
    local function Hide()
        panel:Hide();menu:Hide();overTime=0;awayTime=0
    end
    local function Hovered()
        if panel:IsShown()and(panel:IsMouseOver()or(menu:IsShown()and menu:IsMouseOver()))then return true end
        -- Native EUI overlays intercept mouse events. Inspect the current focus's
        -- parent chain to include the expanded mover, its links and its cog.
        local foci=GetMouseFoci and GetMouseFoci()or(GetMouseFocus and {GetMouseFocus()}or {})
        for _,focus in ipairs(foci)do
            for _=1,12 do
                if not focus then break end
                if focus._barKey==moverKey then return not focus._dragging end
                focus=focus.GetParent and focus:GetParent()
            end
        end
        return root:IsMouseOver()
    end
    -- Only watch while Unlock Mode is open, throttled to 20 checks/second.
    -- Intent and leave delays mirror EUI's hover interaction without hooking it.
    watcher:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt;if elapsed<.05 then return end
        local step=elapsed;elapsed=0
        if not active or InCombatLockdown()or not root:IsShown()then Hide();return end
        if Hovered()then
            awayTime=0;overTime=overTime+step
            if overTime>=.15 and not panel:IsShown()then Update();panel:Show()end
        else
            overTime=0;awayTime=awayTime+step
            if awayTime>=.25 then Hide()end
        end
    end)
    panel.belHoverWatcher=watcher
    EUI:RegisterUnlockModeListener("BelToolboxEdit"..key,function(open,action)
        active=open
        if open then
            snapshot={}
            for _,field in ipairs({"size","spacing",rowKey,"growth"})do snapshot[field]={getSettings()[field]}end
            Hide();elapsed=0;watcher:Show()
        else
            watcher:Hide();Hide()
            if action=="discard"and snapshot then
                for field,value in pairs(snapshot)do getSettings()[field]=value[1]end
                refresh()
            end
            snapshot=nil
        end
    end)
    root:HookScript("OnHide",Hide)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED");panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent",function(_,event)
        Hide()
    end)
end
