-- Independent schedules over EUI's existing travel pins. No DockWatch runtime.
-- Recorded tracks/timings are credited in THIRD_PARTY_NOTICES.md.
local _,ns=...
local routes=ns.TransportRoutes or {}
local labels=setmetatable({},{__mode="k"})
local tracks,previous,ticker,hovered,tooltipGuard={},nil,nil,nil,false
local atlases={flightmasterferry=true,["vehicle-air-horde"]=true,["vehicle-air-alliance"]=true}
local openMapPins=setmetatable({},{__mode="k"})
local hookedStitches=setmetatable({},{__mode="k"})
local openMapAtlases={["Ships_CargoShip-Map"]=true,["vehicle-air-horde"]=true,["vehicle-air-alliance"]=true}
local openMapKinds={boat=true,zeppelin=true,airship=true}
local function Safe(v)return not (issecretvalue and issecretvalue(v))end
local function Number(v)return Safe(v)and type(v)=="number"and v==v end
function ns.GetTransportSettings()
    local db=ns.GetSettings();db.transportTimers=db.transportTimers or {}
    return db.transportTimers
end
local function Enabled()return ns.GetTransportSettings().enabled==true end
function ns.IsTransportProviderEnabled(provider)
    return Enabled()and ns.GetTransportSettings()[provider]~=false
end
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
local function MatchingPoint(point,destination,vehicle)
    local found,best={},nil
    for _,r in ipairs(routes)do
        for _,from in ipairs({"a","b"})do
            if Allowed(r,from)and(not vehicle or r.vehicle==vehicle)and Distance(point,r[from])<=650
                and(not destination or Distance(destination,r[Other(from)])<=650)then
                local score=destination and(Distance(point,r[from])+Distance(destination,r[Other(from)]))
                if score and(not best or score<best-1)then found={};best=score end
                if not score or score<=best+1 then
                    found[#found+1]={route=r,from=from,destination=Destination(r,from)}
                end
            end
        end
    end
    return found
end
local function Matching(pin)
    if not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return {}end
    local ok,instance,position=pcall(C_Map.GetWorldPosFromMapPos,pin.linkMap,CreateVector2D(pin.linkX,pin.linkY))
    if not ok or not Number(instance)or not position then return {}end
    local x,y=position:GetXY();if not Number(x)or not Number(y)then return {}end
    return MatchingPoint({instance,x,y})
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
local widgetTooltip
local function FindWidgetTooltip(pin,text)
    local EUI=EllesmereUI
    if not EUI._WidgetTooltipOwner or EUI._WidgetTooltipOwner()~=pin then return end
    if widgetTooltip then return widgetTooltip end
    if not UIParent or not UIParent.GetChildren then return end
    for _,candidate in ipairs({UIParent:GetChildren()})do
        if not (candidate.IsForbidden and candidate:IsForbidden())then
            local region=candidate.text
            local kind=type(region)
            if (kind=="table"or kind=="userdata")and candidate.bg
                and candidate.GetFrameStrata and candidate:GetFrameStrata()=="TOOLTIP"and region.GetText then
                local value=region:GetText()
                if Safe(value)and value==text then widgetTooltip=candidate;return candidate end
            end
        end
    end
end
local function ShowTip(pin,record,initial)
    if not ns.IsTransportProviderEnabled(record.provider)then return end
    local EUI=EllesmereUI
    if not record.tip or not EUI or not EUI.ShowWidgetTooltip then return end
    local text=record.tip.."\n\n"..Tip(record,Now())
    if initial then
        tooltipGuard=true
        EUI.ShowWidgetTooltip(pin,text,record.tipOptions)
        tooltipGuard=false
        record.widget=FindWidgetTooltip(pin,text)
    else
        local tooltip=record.widget
        -- ShowWidgetTooltip restarts its fade at alpha zero. Refresh only the
        -- existing owner's text/height; never show, reanchor or animate it again.
        if not tooltip or not EUI._WidgetTooltipOwner or EUI._WidgetTooltipOwner()~=pin or not tooltip:IsShown()then return end
        if record.tipRendered==text then return end
        tooltip.text:SetText(text)
        local height=tooltip.text:GetStringHeight()
        if Number(height)then tooltip:SetHeight(height+16)end
    end
    record.tipRendered=text
end
local function Forbidden(frame)
    return frame.IsForbidden and frame:IsForbidden()
end
local function Attach(pin,provider)
    local record=labels[pin]
    if record then return record end
    record={provider=provider};labels[pin]=record
    record.text=pin:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    record.text:SetPoint("TOP",pin,"BOTTOM",0,-2)
    record.text:SetFontObject("GameFontNormalSmall")
    if provider=="eui"then
        pin:HookScript("OnEnter",function()if ns.IsTransportProviderEnabled(provider)then hovered=pin end end)
        pin:HookScript("OnLeave",function()if hovered==pin then hovered=nil end end)
    end
    pin:HookScript("OnHide",function()
        record.text:SetShown(false)
        if hovered==pin then hovered=nil end
    end)
    return record
end
local function OpenMapMatches(pin,addon,stitch)
    local found={}
    for _,dock in ipairs(addon.MapPlaces and addon.MapPlaces.transports or {})do
        if dock[1]==pin.kind then
            local u,v=stitch.FromYards(dock[3],dock[4],dock[5])
            local target=true
            if pin.to and dock[6]then
                local tu,tv=stitch.FromYards(dock[6],dock[7],dock[8])
                target=Number(tu)and Number(tv)and math.abs(tu-pin.to[1])<.000001 and math.abs(tv-pin.to[2])<.000001
            end
            if target and Number(u)and Number(v)and math.abs(u-pin.u)<.000001 and math.abs(v-pin.v)<.000001 then
                -- Distinct piers can be close together. Match the destination
                -- too, rather than attaching every nearby route to every icon.
                local destination=dock[6]and {dock[6],dock[7],dock[8]}
                local matches=MatchingPoint({dock[3],dock[4],dock[5]},destination,pin.kind=="zeppelin"and "zeppelin"or "ship")
                for _,match in ipairs(matches)do found[#found+1]=match end
            end
        end
    end
    return found
end
local function OpenMapShown()
    local api=_G.OpenMapAPI
    return api and api.major==1 and type(api.IsStitched)=="function"and api.IsStitched()
end
local function DiscoverOpenMap()
    local addon=_G.OpenMap;local stitch=addon and addon.MapStitch
    if not stitch or type(stitch.AddPin)~="function"or type(stitch.FromYards)~="function"then return end
    if not hookedStitches[stitch]then
        hookedStitches[stitch]=true
        hooksecurefunc(stitch,"AddPin",function(set,_,_,look)
            local pin=set and set.pins and set.pins[#set.pins]
            if pin and look and openMapAtlases[look.atlas]then openMapPins[pin]=true end
        end)
        -- Bootstrap pins built before this adapter loaded. Parts is read-only;
        -- only visit OpenMap's pin root, pin sets and spatial cells, never art.
        if type(stitch.Parts)=="function"then
            local ok,parts=pcall(stitch.Parts)
            local root=ok and parts and parts[1]and parts[1][2]and parts[1][2][2]
            if root and not Forbidden(root)then
                for _,set in ipairs({root:GetChildren()})do
                    if not Forbidden(set)then
                        for _,cell in ipairs({set:GetChildren()})do
                            if not Forbidden(cell)then
                                for _,pin in ipairs({cell:GetChildren()})do
                                    if not Forbidden(pin)and pin.Icon and openMapKinds[pin.kind]then openMapPins[pin]=true end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for pin in pairs(openMapPins)do
        if not Forbidden(pin)and openMapKinds[pin.kind]and Number(pin.u)and Number(pin.v)and pin.Icon then
            local record=Attach(pin,"openmap")
            local key=pin.kind..":"..pin.u..":"..pin.v..":"..tostring(pin.to and pin.to[1])..":"..tostring(pin.to and pin.to[2])
            if record.key~=key then record.key=key;record.matches=OpenMapMatches(pin,addon,stitch)end
        end
    end
end
local function Discover()
    if ns.IsTransportProviderEnabled("openmap")then DiscoverOpenMap()end
    if not ns.IsTransportProviderEnabled("eui")then return end
    local map=WorldMapFrame
    local canvas=map and map.ScrollContainer and map.ScrollContainer.Child
    if not canvas or Forbidden(canvas)then return end
    -- EUI owns a layer directly under this canvas, with pooled pins under it.
    -- Inspect only these two levels; never enumerate unrelated game frames.
    for _,layer in ipairs({canvas:GetChildren()})do
        if not Forbidden(layer)then
            for _,pin in ipairs({layer:GetChildren()})do
                if not Forbidden(pin)and Safe(pin.atlas)and atlases[pin.atlas]and pin.tex and Number(pin.linkMap)and Number(pin.linkX)and Number(pin.linkY)then
                    local record=Attach(pin,"eui")
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
        local valid
        if record.provider=="openmap"then
            valid=OpenMapShown()and openMapKinds[pin.kind]and pin.look and openMapAtlases[pin.look.atlas]
                and pin:IsVisible()and #(record.matches or {})>0
        else valid=Safe(pin.atlas)and atlases[pin.atlas]and pin:IsVisible()end
        valid=valid and ns.IsTransportProviderEnabled(record.provider)
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
local function EnableMapMarkers()
    if not ns.IsTransportProviderEnabled("eui")then return end
    local travel=EllesmereUI and EllesmereUI._MapTravel
    if not travel or type(travel.Cfg)~="function"or type(travel.Apply)~="function"then return end
    local cfg=travel.Cfg()
    if cfg.enabled~=true or cfg.transports~=true then
        cfg.enabled=true;cfg.transports=true
        travel.Apply()
    end
end
local function Install()
    if WorldMapFrame and hookedMap~=WorldMapFrame then
        hookedMap=WorldMapFrame
        hookedMap:HookScript("OnShow",Display)
        hookedMap:HookScript("OnHide",function()hovered=nil end)
    end
    if not hookedTooltip and EllesmereUI and type(EllesmereUI.ShowWidgetTooltip)=="function"then
        hookedTooltip=true
        hooksecurefunc(EllesmereUI,"ShowWidgetTooltip",function(pin,text,options)
            if tooltipGuard or not ns.IsTransportProviderEnabled("eui")or not labels[pin]or labels[pin].provider~="eui"or type(text)~="string"then return end
            labels[pin].tip=text;labels[pin].tipOptions=options;hovered=pin;ShowTip(pin,labels[pin],true)
        end)
    end
end
function ns.RefreshTransportTimers()
    if ticker then ticker:Cancel();ticker=nil end
    previous=nil;tracks={}
    Install()
    if hovered and labels[hovered]and not ns.IsTransportProviderEnabled(labels[hovered].provider)then
        local record=labels[hovered]
        if record.tip and EllesmereUI then EllesmereUI.ShowWidgetTooltip(hovered,record.tip)end
        hovered=nil
    end
    for _,record in pairs(labels)do
        if not ns.IsTransportProviderEnabled(record.provider)then record.text:SetShown(false)end
    end
    if ns.IsTransportProviderEnabled("eui")or ns.IsTransportProviderEnabled("openmap")then
        EnableMapMarkers()
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
    elseif addon=="Blizzard_WorldMap"or addon=="EllesmereUIForeverEssentials"or addon=="OpenMap"then EnableMapMarkers();Install();Display()end
end)
