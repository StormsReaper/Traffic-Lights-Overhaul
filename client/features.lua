local Features = {}
Features.state = {}
local SIGNAL_RED, SIGNAL_YELLOW = 1, 2

local function dist(a,b) return #(a-b) end
local function axis(center,p) return math.abs(p.y-center.y) >= math.abs(p.x-center.x) and 'NS' or 'EW' end

function Features.period()
    if not Config.TimeOfDay.Enabled then return Config.TimeOfDay.Day end
    local h=GetClockHours()
    if h>=Config.TimeOfDay.Day.StartHour and h<Config.TimeOfDay.Day.EndHour then return Config.TimeOfDay.Day end
    if h>=Config.TimeOfDay.Evening.StartHour and h<Config.TimeOfDay.Evening.EndHour then return Config.TimeOfDay.Evening end
    return Config.TimeOfDay.Night
end
function Features.timings() local p=Features.period(); return p.Green,p.Yellow,p.AllRed end
function Features.isFlashing() return Config.TimeOfDay.Enabled and Features.period().Flashing==true end

local function vehiclesFor(intersection)
    local result={NS={},EW={}}
    if not Config.Adaptive.Enabled and not Config.Queues.Enabled then return result end
    for _,v in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(v) then
            local d=GetPedInVehicleSeat(v,-1)
            if d~=0 and DoesEntityExist(d) and not IsPedAPlayer(d) then
                local p=GetEntityCoords(v); local dd=dist(p,intersection.center)
                if dd<=Config.Adaptive.DetectionDistance then result[axis(intersection.center,p)][#result[axis(intersection.center,p)]+1]={vehicle=v,distance=dd,speed=GetEntitySpeed(v)} end
            end
        end
    end
    table.sort(result.NS,function(a,b)return a.distance<b.distance end); table.sort(result.EW,function(a,b)return a.distance<b.distance end)
    return result
end

function Features.update(intersection)
    local s=Features.state[intersection.key]
    if not s then s={waitNS=0,waitEW=0,last=0,ped=nil,nextAxis=nil}; Features.state[intersection.key]=s end
    local now=GetGameTimer(); if now-s.last<Config.Adaptive.RecomputeInterval then return s end; s.last=now
    local q=vehiclesFor(intersection); s.queueNS=math.min(#q.NS,Config.Adaptive.MaxQueueVehicles); s.queueEW=math.min(#q.EW,Config.Adaptive.MaxQueueVehicles)
    if s.queueNS>0 then s.waitNS=s.waitNS+Config.Adaptive.RecomputeInterval/1000 else s.waitNS=math.max(0,s.waitNS-1) end
    if s.queueEW>0 then s.waitEW=s.waitEW+Config.Adaptive.RecomputeInterval/1000 else s.waitEW=math.max(0,s.waitEW-1) end
    s.scoreNS=s.queueNS*Config.Adaptive.QueueWeight+s.waitNS*Config.Adaptive.WaitingTimeWeight; s.scoreEW=s.queueEW*Config.Adaptive.QueueWeight+s.waitEW*Config.Adaptive.WaitingTimeWeight
    local cur=(intersection.phase=='EW_GREEN' or intersection.phase=='EW_YELLOW') and 'EW' or 'NS'
    if s.waitNS>=Config.Adaptive.StarvationLimit then s.nextAxis='NS' elseif s.waitEW>=Config.Adaptive.StarvationLimit then s.nextAxis='EW' elseif cur=='NS' then s.nextAxis=s.scoreEW>s.scoreNS and 'EW' or 'NS' else s.nextAxis=s.scoreNS>s.scoreEW and 'NS' or 'EW' end
    return s
end

function Features.desiredPhase(intersection,fallback)
    local s=Features.update(intersection)
    if intersection.emergency then return intersection.emergency.axis=='NS' and 'NS_GREEN' or 'EW_GREEN' end
    if Features.isFlashing() then return 'FLASHING' end
    if not Config.Adaptive.Enabled or not s.nextAxis then return fallback end
    return s.nextAxis=='NS' and 'NS_GREEN' or 'EW_GREEN'
end

function Features.phaseDuration(phase)
    local green,yellow,allred=Features.timings()
    if phase=='NS_GREEN' or phase=='EW_GREEN' then return math.max(Config.Adaptive.MinimumGreen,math.min(green,Config.Adaptive.MaximumGreen)) end
    if phase=='NS_YELLOW' or phase=='EW_YELLOW' then return yellow end
    if phase=='ALL_RED' then return math.max(allred,Config.Safety.MinimumAllRed) end
    return 0.8
end

function Features.applySpecial(intersection)
    if not Features.isFlashing() then return false end
    local on=math.floor(GetGameTimer()/Config.TimeOfDay.FlashInterval)%2==0
    for _,head in ipairs(intersection.heads) do
        if DoesEntityExist(head.entity) then SetEntityTrafficlightOverride(head.entity,head.axis=='NS' and (on and SIGNAL_YELLOW or SIGNAL_RED) or (on and SIGNAL_RED or SIGNAL_YELLOW)) end
    end
    return true
end

function Features.updatePedestrians(intersection)
    if not Config.Pedestrians.Enabled then return end
    local s=Features.state[intersection.key] or Features.update(intersection); local now=GetGameTimer()
    if s.ped and now<s.ped.untilTime then return end
    if now-(s.lastPed or 0)<Config.Pedestrians.RequestCooldown*1000 then return end
    for _,ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped,false) and dist(GetEntityCoords(ped),intersection.center)<=Config.Pedestrians.DetectionRadius then s.lastPed=now; s.ped={untilTime=now+(Config.Pedestrians.WalkTime+Config.Pedestrians.FlashingDontWalkTime)*1000}; return end
    end
end
function Features.pedestrianActive(intersection) local s=Features.state[intersection.key]; return s and s.ped and GetGameTimer()<s.ped.untilTime end
function Features.queueCount(intersection,a) local s=Features.state[intersection.key]; if not s then return 0 end; return a=='NS' and s.queueNS or s.queueEW end
_G.TLOFeatures=Features
