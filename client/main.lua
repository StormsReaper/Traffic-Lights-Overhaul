local intersections = {}
_G.TLOIntersections = intersections
local lastScan, lastEmergencyScan = 0, 0
local SIGNAL_RED, SIGNAL_YELLOW, SIGNAL_GREEN = 1, 2, 0

local function distance(a,b) return #(a-b) end
local function normalize(v) local len=#v if len<0.001 then return vector3(0,0,0) end return v/len end
local function dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end

local function axisForPosition(c,p)
    return math.abs(p.y-c.y)>=math.abs(p.x-c.x) and 'NS' or 'EW'
end

local function approachForPosition(c,p)
    local dx,dy=p.x-c.x,p.y-c.y
    if math.abs(dy)>=math.abs(dx) then return dy>=0 and 'NORTH' or 'SOUTH' end
    return dx>=0 and 'EAST' or 'WEST'
end

local function intersectionKey(p) return ('%.0f:%.0f'):format(p.x/10,p.y/10) end

local function createIntersection(center)
    local key=intersectionKey(center)
    if intersections[key] then return intersections[key] end
    intersections[key]={
        key=key,
        center=center,
        heads={},
        emergency=nil,
        phase=nil,
        phaseStarted=0,
        cycleOffset=math.abs(math.floor(center.x*13.37+center.y*7.91))%1000
    }
    return intersections[key]
end

-- Recompute the intersection center from all detected signal heads. The old
-- implementation used the first signal head as the center, which could put
-- every other head on the same side of the calculated center and consequently
-- make every signal receive the same color.
local function recenterIntersection(i)
    if #i.heads==0 then return end
    local sum=vector3(0,0,0)
    local count=0
    for _,h in ipairs(i.heads) do
        if DoesEntityExist(h.entity) then
            sum=sum+GetEntityCoords(h.entity)
            count=count+1
        end
    end
    if count>0 then
        i.center=sum/count
        for _,h in ipairs(i.heads) do
            if DoesEntityExist(h.entity) then
                h.axis=axisForPosition(i.center,GetEntityCoords(h.entity))
                h.approach=approachForPosition(i.center,GetEntityCoords(h.entity))
            end
        end
    end
end

local function scanSignals()
    local pc=GetEntityCoords(PlayerPedId())
    local nearby={}

    for _,o in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(o) then
            local model=GetEntityModel(o)
            for _,m in ipairs(Config.SignalModels) do
                if model==joaat(m) then
                    local p=GetEntityCoords(o)
                    if distance(pc,p)<=Config.IntersectionActivationRadius then
                        nearby[#nearby+1]={entity=o,coords=p}
                    end
                    break
                end
            end
        end
    end

    for _,s in ipairs(nearby) do
        local assigned,closest=nil,Config.IntersectionMergeDistance
        for _,i in pairs(intersections) do
            local d=distance(i.center,s.coords)
            if d<closest then closest,assigned=d,i end
        end

        if not assigned then assigned=createIntersection(s.coords) end

        local known=false
        for _,h in ipairs(assigned.heads) do
            if h.entity==s.entity then known=true break end
        end
        if not known then assigned.heads[#assigned.heads+1]={entity=s.entity,axis='NS',approach='NORTH'} end
    end

    for key,i in pairs(intersections) do
        for n=#i.heads,1,-1 do
            if not DoesEntityExist(i.heads[n].entity) then table.remove(i.heads,n) end
        end
        if #i.heads==0 then
            intersections[key]=nil
        else
            recenterIntersection(i)
        end
    end
end

local function emergencyLightsActive(v)
    if not Config.Emergency.Enabled or GetVehicleClass(v)~=18 then return false end
    if Config.Emergency.RequireEmergencyLights and GetVehicleSirenLights(v)~=true then return false end
    if Config.Emergency.RequireSiren and not IsVehicleSirenOn(v) then return false end
    return true
end

local function getEmergencyCandidates(center)
    local c={}
    for _,v in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(v) and emergencyLightsActive(v) then
            local d=GetPedInVehicleSeat(v,-1)
            if d~=0 and DoesEntityExist(d) then
                local p=GetEntityCoords(v)
                local delta=center-p
                local distv=#delta
                local speed=GetEntitySpeed(v)
                if distv<=Config.Emergency.DetectionRadius and speed>=Config.Emergency.MinimumSpeed and dot(GetEntityForwardVector(v),normalize(delta))>=Config.Emergency.LookAheadDot then
                    c[#c+1]={vehicle=v,distance=distv,speed=speed,eta=distv/math.max(speed,.1),approach=approachForPosition(center,p),axis=axisForPosition(center,p)}
                end
            end
        end
    end
    table.sort(c,function(a,b)return a.eta<b.eta end)
    return c
end

local function updateEmergencyState()
    if not Config.Emergency.Enabled then return end
    local now=GetGameTimer()
    if now-lastEmergencyScan<Config.Emergency.ScanInterval then return end
    lastEmergencyScan=now

    for _,i in pairs(intersections) do
        local e=getEmergencyCandidates(i.center)[1]
        if e then
            i.emergency={vehicle=e.vehicle,approach=e.approach,axis=e.axis,distance=e.distance,eta=e.eta,lastSeen=now,started=i.emergency and i.emergency.started or now}
        elseif i.emergency and (now-i.emergency.lastSeen)/1000>Config.Emergency.HoldAfterClear then
            i.emergency=nil
        end
    end
end

local function normalPhase(i)
    local green,yellow,allred=Config.Normal.Green,Config.Normal.Yellow,Config.Normal.AllRed
    if _G.TLOFeatures then green,yellow,allred=_G.TLOFeatures.timings() end
    local cycle=green*2+yellow*2+allred*2
    local t=(GetNetworkTimeAccurate()/1000+i.cycleOffset)%cycle
    local a=green
    local b=a+yellow
    local c=b+allred
    local d=c+green
    local e=d+yellow
    local f=e+allred
    if t<a then return 'NS_GREEN' elseif t<b then return 'NS_YELLOW' elseif t<c then return 'ALL_RED' elseif t<d then return 'EW_GREEN' elseif t<e then return 'EW_YELLOW' elseif t<f then return 'ALL_RED' end
    return 'NS_GREEN'
end

local function phaseAxis(p)
    if p=='NS_GREEN' or p=='NS_YELLOW' then return 'NS' end
    if p=='EW_GREEN' or p=='EW_YELLOW' then return 'EW' end
end

local function phaseIsGreen(p) return p=='NS_GREEN' or p=='EW_GREEN' end

local function desiredPhase(i)
    if i.emergency and (GetGameTimer()-i.emergency.started)/1000<=Config.Emergency.MaxHold then
        return i.emergency.axis=='NS' and 'NS_GREEN' or 'EW_GREEN'
    end
    if _G.TLOFeatures then return _G.TLOFeatures.desiredPhase(i,normalPhase(i)) end
    return normalPhase(i)
end

local function applyPhase(i,p)
    if _G.TLOFeatures and _G.TLOFeatures.applySpecial(i) then return end

    for _,h in ipairs(i.heads) do
        if DoesEntityExist(h.entity) then
            local s=SIGNAL_RED
            if p=='NS_GREEN' and h.axis=='NS' then s=SIGNAL_GREEN
            elseif p=='NS_YELLOW' and h.axis=='NS' then s=SIGNAL_YELLOW
            elseif p=='EW_GREEN' and h.axis=='EW' then s=SIGNAL_GREEN
            elseif p=='EW_YELLOW' and h.axis=='EW' then s=SIGNAL_YELLOW
            elseif p=='ALL_RED' then s=SIGNAL_RED
            end
            SetEntityTrafficlightOverride(h.entity,s)
        end
    end
end

local function transition(i,target)
    local current=i.phase
    local now=GetGameTimer()
    if not current then i.phase,i.phaseStarted=target,now return end
    if current==target then return end

    if phaseIsGreen(current) and phaseAxis(current)~=phaseAxis(target) then
        i.phase,i.phaseStarted=phaseAxis(current)=='NS' and 'NS_YELLOW' or 'EW_YELLOW',now
    elseif current=='NS_YELLOW' or current=='EW_YELLOW' then
        i.phase,i.phaseStarted='ALL_RED',now
    elseif current=='ALL_RED' then
        i.phase,i.phaseStarted=target,now
    else
        i.phase,i.phaseStarted=target,now
    end
end

local function advance(i)
    local now=GetGameTimer()
    local elapsed=(now-i.phaseStarted)/1000
    local p=i.phase
    local target=desiredPhase(i)
    local duration=Config.Normal.AllRed

    if _G.TLOFeatures then
        duration=_G.TLOFeatures.phaseDuration(p)
    elseif p=='NS_GREEN' or p=='EW_GREEN' then
        duration=Config.Normal.Green
    elseif p=='NS_YELLOW' or p=='EW_YELLOW' then
        duration=Config.Normal.Yellow
    end

    if p=='FLASHING' then return end

    if elapsed>=duration then
        if p=='NS_YELLOW' or p=='EW_YELLOW' then
            i.phase,i.phaseStarted='ALL_RED',now
        elseif p=='ALL_RED' then
            i.phase,i.phaseStarted=target,now
        else
            transition(i,target)
        end
    elseif i.emergency and phaseIsGreen(p) and phaseAxis(p)~=phaseAxis(target) then
        transition(i,target)
    end
end

local function pedestrianUpdate(i)
    if _G.TLOFeatures then _G.TLOFeatures.updatePedestrians(i) end
end

CreateThread(function()
    while true do
        local wait=Config.ScanInterval
        local pc=GetEntityCoords(PlayerPedId())

        if GetGameTimer()-lastScan>=Config.ScanInterval then
            lastScan=GetGameTimer()
            scanSignals()
        end

        updateEmergencyState()

        for _,i in pairs(intersections) do
            if distance(pc,i.center)<=Config.IntersectionActivationRadius then
                pedestrianUpdate(i)
                if not i.phase then
                    i.phase=Config.Normal.StartPhase
                    i.phaseStarted=GetGameTimer()
                end
                advance(i)
                applyPhase(i,i.phase)
                wait=math.min(wait,Config.SignalUpdateInterval)
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop',function(r)
    if r~=GetCurrentResourceName() then return end
    for _,i in pairs(intersections) do
        for _,h in ipairs(i.heads) do
            if DoesEntityExist(h.entity) then SetEntityTrafficlightOverride(h.entity,3) end
        end
    end
end)

RegisterCommand('tlo_debug',function()
    Config.Debug=not Config.Debug
    print(('[TLO] Debug: %s'):format(Config.Debug and 'ON' or 'OFF'))
end,false)
