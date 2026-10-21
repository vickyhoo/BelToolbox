-- Shared controls for addon-owned toolbars. No dependency on RS.
local _, ns = ...
local L = ns.L
local T = {}
ns.Toolbars = T
function T.Settings(key)
    local db=ns.GetSettings()
    db[key]=db[key] or {}
    return db[key]
end
function T.Size(key)
    local n=tonumber(T.Settings(key).size) or 22
    return math.max(18,math.min(key=="consumables"and 64 or 32,n))
end
function T.Tooltip(button,title,body)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText(title)
        if type(body)=="table"then
            for _,line in ipairs(body)do GameTooltip:AddLine(line,1,1,1,false)end
        elseif body then GameTooltip:AddLine(body,0.75,0.75,0.75,true)end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function()GameTooltip:Hide()end)
end
function T.Button(parent,name,secure,text,texture)
    local template=secure and "SecureActionButtonTemplate" or nil
    local b=CreateFrame("Button",name,parent,template)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    if texture then
        b.icon=b:CreateTexture(nil,"ARTWORK")
        b.icon:SetPoint("TOPLEFT",2,-2);b.icon:SetPoint("BOTTOMRIGHT",-2,2)
        b.icon:SetTexture(texture)
    else
        b.label=b:CreateFontString(nil,"OVERLAY")
        b.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",16,"OUTLINE")
        b.label:SetPoint("CENTER");b.label:SetText(text or "")
    end
    return b
end
function T.Position(root,key,default)
    if InCombatLockdown() then return end
    local p=T.Settings(key).position or default()
    root:ClearAllPoints();root:SetPoint(p.point,UIParent,p.relPoint,p.x,p.y)
    if root._belAfterPosition then root._belAfterPosition()end
end
function T.Mover(root,key,title,order,default)
    root:SetSize(T.Size(key),T.Size(key))
    root:SetMovable(true);root:SetClampedToScreen(true)
    local function Apply()T.Position(root,key,default)end
    local registered
    root.RegisterBelMover=function()
        local EUI=_G.EllesmereUI
        if registered or not EUI or not EUI.MakeUnlockElement or not EUI.RegisterUnlockElements then return end
        local e=EUI.MakeUnlockElement({
            key="BelToolbox"..key,label=L(title),group=L("Bel Toolbox"),order=order,
            noResize=true,ownsPosition=true,noAnchorTarget=true,noAnchorTo=true,noSizeMatchTarget=true,
            getFrame=function()return root end,
            getSize=function()return root:GetWidth(),root:GetHeight()end,
            isHidden=function()return T.Settings(key).enabled==false or not root:IsShown()end,
            loadPos=function()local p=T.Settings(key).position or default();return {point=p.point,relPoint=p.relPoint,x=p.x,y=p.y}end,
            savePos=function(_,point,relPoint,x,y)
                if point then T.Settings(key).position={point=point,relPoint=relPoint,x=x,y=y};Apply()end
            end,
            clearPos=function()T.Settings(key).position=nil;Apply()end,
            applyPos=Apply,
        })
        EUI:RegisterUnlockElements({e},"BelToolbox");registered=true
    end
    Apply();root.RegisterBelMover()
    return Apply
end
function T.Layout(root,buttons,key)
    local db=T.Settings(key)
    local size=T.Size(key)
    local vertical=db.vertical==true
    local offset=0
    for _,button in ipairs(buttons)do
        button:ClearAllPoints();button:SetSize(button.belWide and size*1.8 or size,size)
        if button.label then button.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",math.max(12,size-6),"OUTLINE")end
        if vertical then button:SetPoint("TOP",root,"TOP",0,-offset);offset=offset+size+2
        else button:SetPoint("LEFT",root,"LEFT",offset,0);offset=offset+button:GetWidth()+2 end
        button:Show()
    end
    root:SetSize(vertical and size*1.8 or math.max(size,offset-2),vertical and math.max(size,offset-2)or size)
end
