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
    -- The native mover owns the background, name, coordinates and position cog.
    -- Our compact action row shares its hover box instead of adding a second box.
    local panel=CreateFrame("Frame",nil,UIParent)
    editors[key]=panel;root.belQuickEdit=panel
    panel:SetSize(264,20);panel:SetFrameStrata("FULLSCREEN_DIALOG");panel:Hide()
    local actions={};local mover
    local function Update()
        local labels={L("Button size").." "..getSize(),L("Button spacing").." "..getGap(),
            L("Buttons per row").." "..(getSettings()[rowKey]or defaultRow),L("Bar growth direction")}
        for i,button in ipairs(actions)do button.label:SetText(labels[i])end
    end
    local function Set(field,value)
        if InCombatLockdown()then return end
        getSettings()[field]=value;refresh();Update()
    end
    local rows={
        {type="slider",label=L("Button size"),min=18,max=64,step=1,get=getSize,set=function(v)Set("size",v)end},
        {type="slider",label=L("Button spacing"),min=0,max=16,step=1,get=getGap,set=function(v)Set("spacing",v)end},
        {type="slider",label=L("Buttons per row"),min=1,max=maxRow,step=1,
            get=function()return getSettings()[rowKey]or defaultRow end,set=function(v)Set(rowKey,v)end},
        {type="dropdown",label=L("Bar growth direction"),
            values={CENTER=L("Grow centered"),LEFT=L("Grow left"),RIGHT=L("Grow right")},order={"CENTER","LEFT","RIGHT"},
            get=function()return T.Growth(getSettings())end,
            set=function(v)T.SetGrowth(root,getSettings(),v,refresh);Update()end},
    }
    for i,row in ipairs(rows)do
        local button=CreateFrame("Button",nil,panel)
        actions[i]=button;button:SetSize(66,20);button:SetPoint("LEFT",panel,"LEFT",(i-1)*66,0)
        button.label=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        button.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",9,"")
        button.label:SetTextColor(.82,.63,.43);button.label:SetPoint("CENTER")
        button:SetScript("OnEnter",function()button.label:SetTextColor(1,1,1)end)
        button:SetScript("OnLeave",function()button.label:SetTextColor(.82,.63,.43)end)
        button:SetScript("OnClick",function()
            if InCombatLockdown()or not EUI.BuildCogPopup then return end
            if not button.showPopup then
                local _,show=EUI.BuildCogPopup({title=L(title),minWidth=280,rows=rows})
                button.showPopup=show
            end
            button.showPopup(button)
        end)
        if i>1 then
            local divider=button:CreateTexture(nil,"ARTWORK")
            divider:SetColorTexture(1,1,1,.25);divider:SetSize(1,9);divider:SetPoint("LEFT",0,0)
        end
    end
    panel.belActions=actions
    local snapshot,active
    local watcher=CreateFrame("Frame",nil,UIParent);watcher:Hide()
    panel.belHoverWatcher=watcher
    local elapsed,overTime,awayTime=0,0,0
    local moverKey=key=="mage"and "BelToolboxMageBar"or "BelToolboxConsumables"
    local function Hide(closePopups)
        panel:Hide();overTime=0;awayTime=0
        if closePopups then
            for _,button in ipairs(actions)do
                local popup=button.showPopup and button.showPopup._popupFrame
                if popup then popup:Hide()end
            end
        end
    end
    local function Hovered()
        local foci=GetMouseFoci and GetMouseFoci()or(GetMouseFocus and {GetMouseFocus()}or {})
        for _,focus in ipairs(foci)do
            for _=1,12 do
                if not focus then break end
                if focus._barKey==moverKey then mover=focus;return not focus._dragging end
                focus=focus.GetParent and focus:GetParent()
            end
        end
        for _,button in ipairs(actions)do
            local popup=button.showPopup and button.showPopup._popupFrame
            if popup and popup:IsShown()then return true end
        end
        return panel:IsShown()and panel:IsMouseOver()or root:IsMouseOver()
    end
    watcher:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt;if elapsed<.05 then return end
        local step=elapsed;elapsed=0
        if not active or InCombatLockdown()or not root:IsShown()then Hide(true);return end
        if Hovered()then
            awayTime=0;overTime=overTime+step
            if mover and mover:IsShown()then
                -- Extend EUI's own animated hover bounds to fit our action row.
                if mover._cachedHoverW then mover._cachedHoverW=math.max(mover._cachedHoverW,280)end
                if mover._cachedHoverH then mover._cachedHoverH=math.max(mover._cachedHoverH,48)end
                panel:ClearAllPoints();panel:SetPoint("CENTER",mover,"CENTER",0,-12)
            else panel:ClearAllPoints();panel:SetPoint("CENTER",root,"CENTER",0,-12)end
            if overTime>=.2 then Update();panel:Show()end
        else
            overTime=0;awayTime=awayTime+step
            if awayTime>=.25 then Hide(false)end
        end
    end)
    EUI:RegisterUnlockModeListener("BelToolboxEdit"..key,function(open,action)
        active=open
        if open then
            snapshot={}
            for _,field in ipairs({"size","spacing",rowKey,"growth"})do snapshot[field]={getSettings()[field]}end
            Hide(true);elapsed=0;mover=nil;watcher:Show()
        else
            watcher:Hide();Hide(true)
            if action=="discard"and snapshot then
                for field,value in pairs(snapshot)do getSettings()[field]=value[1]end
                refresh()
            end
            snapshot=nil
        end
    end)
    root:HookScript("OnHide",function()Hide(true)end)
    watcher:RegisterEvent("PLAYER_REGEN_DISABLED");watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent",function()Hide(true)end)
end
