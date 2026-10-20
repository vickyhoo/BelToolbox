-- Independent schedules over EUI's existing travel pins. No DockWatch runtime.
-- Recorded tracks/timings are credited in THIRD_PARTY_NOTICES.md.
local _,ns=...
local routes=ns.TransportRoutes or {}
local labels=setmetatable({},{__mode="k"})
local tracks,previous,ticker,hovered,tooltipGuard={},nil,nil,nil,false
local atlases={flightmasterferry=true,["vehicle-air-horde"]=true,["vehicle-air-alliance"]=true}
local function Safe(v)return not (issecretvalue and issecretvalue(v))end
local function Number(v)return Safe(v)and type(v)=="number"and v==v end
function ns.GetTransportSettings()
    local db=ns.GetSettings();db.transportTimers=db.transportTimers or {}
    return db.transportTimers
end
local function Enabled()return ns.GetTransportSettings().enabled~=false end
local function Now()return GetServerTime()end
local function Other(from)return from=="a"and "b"or "a"end
local function Direction(from)return from=="a"and "ab"or "ba"end
local function Duration(r,from)return r.base[Direction(from)]end
local function Allowed(r,from)return Duration(r,from)and r[Direction(from)]end
local function Distance(a,b)
    if a[1]~=b[1]then return math.huge end
    return math.sqrt((a[2]-b[2])^2+(a[3]-b[3])^2)
end
local function Saved()
    local db=ns.GetTransportSettings();db.realms=db.realms or {}
    local realm=GetRealmName and GetRealmName()or "default"
    db.realms[realm]=db.realms[realm]or {}
    return db.realms[realm]
end
local function Learned(r,from)
    local row=Saved()[r.id]
    return row and row[from]
end
local function Anchor(r,from)
    local own=Learned(r,from)
    local opposite=Learned(r,Other(from))
    if opposite and Duration(r,Other(from))and (not own or opposite.confirmed>own.confirmed)then
        return opposite.anchor+Duration(r,Other(from))+r.base[from=="a"and "wa"or "wb"],opposite.confirmed
    end
    if own then return own.anchor,own.confirmed end
    if r.seed[from]then return r.seed[from]end
    local other=Other(from)
    if r.seed[other]and Duration(r,other)then
        return r.seed[other]+Duration(r,other)+r.base[from=="a"and "wa"or "wb"]
    end
end
local function Departure(r,from,now)
    if not Allowed(r,from)then return end
    local anchor,confirmed=Anchor(r,from)
    if not anchor then return end
    local nextTime=anchor+math.ceil((now-anchor)/r.base.loop)*r.base.loop
    return nextTime,confirmed
end
local function Incoming(r,from)
    local opposite=Other(from)
    if Allowed(r,opposite)then return r,opposite end
    -- Circuit routes: the incoming boat belongs to the preceding leg.
    for _,other in ipairs(routes)do
        if other~=r and math.abs(other.base.loop-r.base.loop)<.1 then
            for _,side in ipairs({"a","b"})do
                if Allowed(other,side)and Distance(other[Other(side)],r[from])<150 then return other,side end
            end
        end
    end
end
local function Schedule(r,from,now)
    local departure,confirmed=Departure(r,from,now)
    if not departure then return end
    local incoming,side=Incoming(r,from)
    local arrival
    if incoming then
        local nextIncoming=Departure(incoming,side,now)
        if nextIncoming then
            local previousArrival=nextIncoming-incoming.base.loop+Duration(incoming,side)
            arrival=previousArrival>now and previousArrival or nextIncoming+Duration(incoming,side)
        end
    end
    local arriving=arrival and arrival>now and arrival<departure
    return {route=r,from=from,seconds=math.max(0,(arriving and arrival or departure)-now),
        arriving=arriving and true or false,confirmed=confirmed,departure=departure,arrival=arrival}
end
local function Format(seconds)
    local value=math.max(0,math.ceil(seconds))
    return string.format("%d:%02d",math.floor(value/60),value%60)
end
local function Name(dock)
    if C_Map.GetMapPosFromWorldPos and C_Map.GetMapInfo and CreateVector2D then
        -- A zone name is localized by the client; English route names are fallback only.
        for _,map in ipairs({1415,1414})do
            local ok,_,position=pcall(C_Map.GetMapPosFromWorldPos,dock[1],CreateVector2D(dock[2],dock[3]),map)
            if ok and position then
                local x,y=position:GetXY()
                if Number(x)and Number(y)and x>=0 and x<=1 and y>=0 and y<=1 and C_Map.GetMapInfoAtPosition then
                    local info=C_Map.GetMapInfoAtPosition(map,x,y)
                    if info and Safe(info.name)and type(info.name)=="string"then return info.name end
                end
            end
        end
    end
end
local destinationMaps={
    ["tirisfal-glades"]=1420,durotar=1411,["baradin-bay"]=1437,["the-long-wash"]=1439,
    ["western-strand"]=1424,["theramore-isle"]=1445,["gromgol-base-camp"]=1434,
    ["booty-bay"]=1434,ratchet=1413,["stormwind-harbor"]=1453,["mists-edge"]=1439,
    ["ruttheran-village"]=1438,dalaran=1416,valanaar=2521,["skywatcher-plateau"]=1412,
    ["powderfuse-port"]=2548,["steamwheedle-port"]=1446,
}
local function Destination(r,from)
    local index=from=="a"and 2 or 1
    local mapID=destinationMaps[r.places[index]]
    local info=mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if info and Safe(info.name)and type(info.name)=="string"then return info.name end
    return Name(r[Other(from)])or r.names[index]or r.id
end
local function Matching(pin)
    if not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return {}end
    local ok,instance,position=pcall(C_Map.GetWorldPosFromMapPos,pin.linkMap,CreateVector2D(pin.linkX,pin.linkY))
    if not ok or not Number(instance)or not position then return {}end
    local x,y=position:GetXY();if not Number(x)or not Number(y)then return {}end
    local point={instance,x,y};local found={}
    for _,r in ipairs(routes)do
        for _,from in ipairs({"a","b"})do
            if Allowed(r,from)and Distance(point,r[from])<=650 then
                found[#found+1]={route=r,from=from,destination=Destination(r,from)}
            end
        end
    end
    return found
end
local function Rows(record,now)
    local result={}
    for _,match in ipairs(record.matches or {})do
        local state=Schedule(match.route,match.from,now)
        if state then state.destination=match.destination;result[#result+1]=state end
    end
    table.sort(result,function(a,b)if a.seconds==b.seconds then return a.route.id<b.route.id end;return a.seconds<b.seconds end)
    return result
end
local function Tip(record,now)
    local lines={ns.L("Ship and zeppelin timers")}
    for _,row in ipairs(Rows(record,now))do
        local status=row.arriving and ns.L("Arrives in %s",Format(row.seconds))or ns.L("Departs in %s",Format(row.seconds))
        lines[#lines+1]="|cffffffff"..row.destination..": "..status.."|r"
        if row.confirmed then
            lines[#lines+1]="|cffaaaaaa"..ns.L("Last calibrated %d min ago",math.max(0,math.floor((now-row.confirmed)/60))).."|r"
        else lines[#lines+1]="|cffaaaaaa"..ns.L("Built-in timetable; ride to calibrate.").."|r"end
    end
    if #lines==1 then lines[#lines+1]=ns.L("No timetable for this dock.")end
    return table.concat(lines,"\n")
end
local function ShowTip(pin,record)
    local EUI=EllesmereUI
    if not record.tip or not EUI or not EUI.ShowWidgetTooltip then return end
    tooltipGuard=true
    EUI.ShowWidgetTooltip(pin,record.tip.."\n\n"..Tip(record,Now()))
    tooltipGuard=false
end
local function Forbidden(frame)
    return frame.IsForbidden and frame:IsForbidden()
end
local function Discover()
    local map=WorldMapFrame
    local canvas=map and map.ScrollContainer and map.ScrollContainer.Child
    if not canvas or Forbidden(canvas)then return end
    -- EUI owns a layer directly under this canvas, with pooled pins under it.
    -- Inspect only these two levels; never enumerate unrelated game frames.
    for _,layer in ipairs({canvas:GetChildren()})do
        if not Forbidden(layer)then
            for _,pin in ipairs({layer:GetChildren()})do
                if not Forbidden(pin)and Safe(pin.atlas)and atlases[pin.atlas]and pin.tex and Number(pin.linkMap)and Number(pin.linkX)and Number(pin.linkY)then
                    local record=labels[pin]
                    if not record then
                        record={};labels[pin]=record
                        record.text=pin:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                        record.text:SetPoint("TOP",pin,"BOTTOM",0,-2)
                        record.text:SetFontObject("GameFontNormalSmall")
                        pin:HookScript("OnEnter",function()if Enabled()then hovered=pin end end)
                        pin:HookScript("OnLeave",function()if hovered==pin then hovered=nil end end)
                        pin:HookScript("OnHide",function()
                            record.text:SetShown(false)
                            if hovered==pin then hovered=nil end
                        end)
                    end
                    local key=pin.linkMap..":"..pin.linkX..":"..pin.linkY..":"..pin.atlas
                    if record.key~=key then record.key=key;record.matches=Matching(pin);record.tip=nil end
                end
            end
        end
    end
end
local function Display()
    local map=WorldMapFrame
    if not Enabled()or not map or not map:IsShown()then return end
    Discover()
    local now=Now()
    for pin,record in pairs(labels)do
        local valid=Safe(pin.atlas)and atlases[pin.atlas]and pin:IsVisible()
        record.text:SetShown(valid and true or false)
        if valid then
            local first=Rows(record,now)[1]
            local text=first and Format(first.seconds)or "?"
            if record.lastText~=text then record.text:SetText(text);record.lastText=text end
            if first and not first.arriving then record.text:SetTextColor(1,.82,0)else record.text:SetTextColor(1,1,1)end
        end
    end
    if hovered and labels[hovered]and hovered:IsVisible()then ShowTip(hovered,labels[hovered])end
end
local function Store(r,from,anchor,now)
    local saved=Saved();saved[r.id]=saved[r.id]or {}
    saved[r.id][from]={anchor=anchor,confirmed=now}
end
local function Confirm(r,from,anchor,now)
    local old=Learned(r,from)
    if old and math.abs(old.anchor-anchor)<10 and now-old.confirmed<120 then return end
    Store(r,from,anchor,now)
    -- The three-legged circuit shares one boat. Advance through its known stops.
    if not Allowed(r,Other(from))then
        local route,side,time=r,from,anchor
        for _=1,2 do
            local destination=route[Other(side)]
            local nextRoute,nextSide
            for _,other in ipairs(routes)do
                if other~=route and math.abs(other.base.loop-route.base.loop)<.1 then
                    for _,candidate in ipairs({"a","b"})do
                        if Allowed(other,candidate)and Distance(other[candidate],destination)<150 then nextRoute,nextSide=other,candidate end
                    end
                end
            end
            if not nextRoute then break end
            time=time+Duration(route,side)+nextRoute.base[nextSide=="a"and "wa"or "wb"]
            Store(nextRoute,nextSide,time,now);route,side=nextRoute,nextSide
        end
    end
end
local function Projection(path,point,prev)
    local best,bestDistance
    local vx,vy=point.x-prev.x,point.y-prev.y
    local motion=math.sqrt(vx*vx+vy*vy)
    for i=2,#path do
        local a,b=path[i-1],path[i]
        local dt=b[1]-a[1]
        if dt>0 and a[2]==point.instance and b[2]==point.instance then
            local dx,dy=b[3]-a[3],b[4]-a[4]
            local length2=dx*dx+dy*dy
            local length=math.sqrt(length2)
            local speed=length/dt
            if speed>=6 and speed<=100 and motion>0 and (vx*dx+vy*dy)/(motion*length)>.8 then
                local f=((point.x-a[3])*dx+(point.y-a[4])*dy)/length2
                if f>=0 and f<=1 then
                    local distance=math.sqrt((point.x-a[3]-f*dx)^2+(point.y-a[4]-f*dy)^2)
                    if distance<=32 and (not bestDistance or distance<bestDistance)then
                        best,bestDistance=a[1]+f*dt,distance
                    end
                end
            end
        end
    end
    return best
end
local function Sample()
    if not UnitPosition or not GetUnitSpeed then return end
    if InCombatLockdown and InCombatLockdown()then previous=nil;tracks={};return end
    local x,y,_,instance=UnitPosition("player")
    local speed=GetUnitSpeed("player")
    local blocked=false
    for _,fn in ipairs({UnitOnTaxi,UnitInVehicle,IsFlying,IsFalling})do
        local value=fn("player")
        if not Safe(value)or value then blocked=true;break end
    end
    if not Number(x)or not Number(y)or not Number(instance)or not Number(speed)or speed>0 or blocked then previous=nil;tracks={};return end
    local point={x=x,y=y,instance=instance,time=Now(),mono=GetTime()}
    local prev=previous;previous=point
    if not prev or prev.instance~=instance or point.mono-prev.mono>3 then tracks={};return end
    local distance=math.sqrt((x-prev.x)^2+(y-prev.y)^2)
    if distance<2 or distance>200 then tracks={};return end
    local updated,ready,matches={},{},0
    for _,r in ipairs(routes)do
        for _,from in ipairs({"a","b"})do
            if Allowed(r,from)then
                local elapsed=Projection(r[Direction(from)],point,prev)
                if elapsed then
                    matches=matches+1
                    local key=r.id..":"..from
                    local anchor=point.time-elapsed
                    local track=tracks[key]
                    if not track or math.abs(anchor-track.anchor)>3 then track={anchor=anchor,start=point.mono,samples={}}end
                    track.samples[#track.samples+1]=anchor
                    if #track.samples>8 then table.remove(track.samples,1)end
                    updated[key]=track
                    if #track.samples>=6 and point.mono-track.start>=5 then ready[#ready+1]={r=r,from=from,track=track}end
                end
            end
        end
    end
    tracks=updated
    if #ready==1 and matches==1 then
        local chosen=ready[1];local values={}
        for i,v in ipairs(chosen.track.samples)do values[i]=v end
        table.sort(values)
        Confirm(chosen.r,chosen.from,values[math.ceil(#values/2)],point.time)
    end
end
local hookedMap,hookedTooltip
local function Install()
    if WorldMapFrame and hookedMap~=WorldMapFrame then
        hookedMap=WorldMapFrame
        hookedMap:HookScript("OnShow",Display)
        hookedMap:HookScript("OnHide",function()hovered=nil end)
    end
    if not hookedTooltip and EllesmereUI and type(EllesmereUI.ShowWidgetTooltip)=="function"then
        hookedTooltip=true
        hooksecurefunc(EllesmereUI,"ShowWidgetTooltip",function(pin,text)
            if tooltipGuard or not Enabled()or not labels[pin]then return end
            labels[pin].tip=text;hovered=pin;ShowTip(pin,labels[pin])
        end)
    end
end
function ns.RefreshTransportTimers()
    if ticker then ticker:Cancel();ticker=nil end
    previous=nil;tracks={}
    Install()
    if Enabled()then
        ticker=C_Timer.NewTicker(1,function()Sample();Display()end)
        Display()
    else
        for _,record in pairs(labels)do record.text:SetShown(false)end
        if hovered and labels[hovered]and labels[hovered].tip and EllesmereUI then EllesmereUI.ShowWidgetTooltip(hovered,labels[hovered].tip)end
        hovered=nil
    end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN");events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,addon)
    if event=="PLAYER_LOGIN"then ns.RefreshTransportTimers()
    elseif addon=="Blizzard_WorldMap"or addon=="EllesmereUIForeverEssentials"then Install();Display()end
end)
