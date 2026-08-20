local Features = {}
Features.state = {}
local SIGNAL_RED, SIGNAL_YELLOW = 1, 2
local function dist(a,b) return #(a-b) end
local function axis(center,p) return math.abs(p.y-center.y)>=math.abs(p.x-center.x) and 'NS' or 'EW' end

function Features.period()
    if not Config.TimeOfDay.Enabled then return Config.TimeOfDay.Day end
    local h=GetClockHours()
    if h>=Config.TimeOfDay.Day.StartHour and h<Config.TimeOfDay.Day.EndHour then return Config.TimeOfDay.Day end
    if h>=Config.TimeOfDay.Evening.StartHour and h<Config.TimeOfDay.Evening.EndHour then return Config.TimeOfDay.Evening end
    return Config.TimeOfDay.Night
end
function Features.timings() local p=Features.period(); return p.Green,p.Yellow,p.AllRed end
function Features.isFlashing() return Config.TimeOfDay.Enabled and Features.period().Flashing==true end

local function vehiclesFor(i)
    local r={NS={},EW={}}
    for _,v in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(v) then local d=GetPedInVehicleSeat(v,-1); if d~=0 and DoesEntityExist(d) and not IsPedAPlayer(d) then local p=GetEntityCoords(v); local dd=dist(p,i.center); if dd<=Config.Adaptive.DetectionDistance then local a=axis(i.center,p); r[a][#r[a]+1]={vehicle=v,distance=dd,speed=GetEntitySpeed(v)} end end end
    end
    table.sort(r.NS,function(a,b)return a.distance<b.distance end); table.sort(r.EW,function(a,b)return a.distance<b.distance end); return r
end

function Features.update(i)
    local s=Features.state[i.key]
    if not s then s={waitNS=0,waitEW=0,last=0,ped=nil,nextAxis=nil,coordAxis=nil}; Features.state[i.key]=s end
    local now=GetGameTimer(); if now-s.last<Config.Adaptive.RecomputeInterval then return s end; s.last=now
    local q=vehiclesFor(i); s.queueNS=math.min(#q.NS,Config.Adaptive.MaxQueueVehicles); s.queueEW=math.min(#q.EW,Config.Adaptive.MaxQueueVehicles)
    if s.queueNS>0 then s.waitNS=s.waitNS+Config.Adaptive.RecomputeInterval/1000 else s.waitNS=math.max(0,s.waitNS-1) end
    if s.queueEW>0 then s.waitEW=s.waitEW+Config.Adaptive.RecomputeInterval/1000 else s.waitEW=math.max(0,s.waitEW-1) end
    s.scoreNS=s.queueNS*Config.Adaptive.QueueWeight+s.waitNS*Config.Adaptive.WaitingTimeWeight; s.scoreEW=s.queueEW*Config.Adaptive.QueueWeight+s.waitEW*Config.Adaptive.WaitingTimeWeight
    local cur=(i.phase=='EW_GREEN' or i.phase=='EW_YELLOW') and 'EW' or 'NS'
    if s.waitNS>=Config.Adaptive.StarvationLimit then s.nextAxis='NS' elseif s.waitEW>=Config.Adaptive.StarvationLimit then s.nextAxis='EW' elseif cur=='NS' then s.nextAxis=s.scoreEW>s.scoreNS and 'EW' or 'NS' else s.nextAxis=s.scoreNS>s.scoreEW and 'NS' or 'EW' end
    if _G.TLOCoordination then _G.TLOCoordination.update(i); s.coordAxis=i.coordination and i.coordination.axis or nil end
    return s
end

function Features.desiredPhase(i,fallback)
    local s=Features.update(i)
    if i.emergency then return i.emergency.axis=='NS' and 'NS_GREEN' or 'EW_GREEN' end
    if Features.isFlashing() then return 'FLASHING' end
    local wanted=s.nextAxis
    if Config.Coordination.Enabled and s.coordAxis then wanted=s.coordAxis end
    if not Config.Adaptive.Enabled and not s.coordAxis then return fallback end
    return wanted=='NS' and 'NS_GREEN' or 'EW_GREEN'
end
function Features.phaseDuration(p)
    local g,y,r=Features.timings()
    if p=='NS_GREEN' or p=='EW_GREEN' then return math.max(Config.Adaptive.MinimumGreen,math.min(g,Config.Adaptive.MaximumGreen)) end
    if p=='NS_YELLOW' or p=='EW_YELLOW' then return y end
    if p=='ALL_RED' then return math.max(r,Config.Safety.MinimumAllRed) end
    return .8
end
function Features.applySpecial(i)
    if not Features.isFlashing() then return false end
    local on=math.floor(GetGameTimer()/Config.TimeOfDay.FlashInterval)%2==0
    for _,h in ipairs(i.heads) do if DoesEntityExist(h.entity) then SetEntityTrafficlightOverride(h.entity,h.axis=='NS' and (on and SIGNAL_YELLOW or SIGNAL_RED) or (on and SIGNAL_RED or SIGNAL_YELLOW)) end end
    return true
end
function Features.updatePedestrians(i)
    if not Config.Pedestrians.Enabled then return end
    local s=Features.state[i.key] or Features.update(i); local now=GetGameTimer(); if s.ped and now<s.ped.untilTime then return end
    if now-(s.lastPed or 0)<Config.Pedestrians.RequestCooldown*1000 then return end
    for _,p in ipairs(GetGamePool('CPed')) do if DoesEntityExist(p) and not IsEntityDead(p) and not IsPedInAnyVehicle(p,false) and dist(GetEntityCoords(p),i.center)<=Config.Pedestrians.DetectionRadius then s.lastPed=now; s.ped={untilTime=now+(Config.Pedestrians.WalkTime+Config.Pedestrians.FlashingDontWalkTime)*1000}; return end end
end
function Features.pedestrianActive(i) local s=Features.state[i.key]; return s and s.ped and GetGameTimer()<s.ped.untilTime end
function Features.queueCount(i,a) local s=Features.state[i.key]; if not s then return 0 end return a=='NS' and s.queueNS or s.queueEW end
_G.TLOFeatures=Features
