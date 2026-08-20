local Features = {}
Features.state = {}

local function dist(a, b) return #(a - b) end
local function axis(center, p)
    return math.abs(p.y - center.y) >= math.abs(p.x - center.x) and 'NS' or 'EW'
end

local function hour()
    local h = GetClockHours()
    return h
end

function Features.period()
    if not Config.TimeOfDay.Enabled then return Config.TimeOfDay.Day end
    local h = hour()
    if h >= Config.TimeOfDay.Day.StartHour and h < Config.TimeOfDay.Day.EndHour then return Config.TimeOfDay.Day end
    if h >= Config.TimeOfDay.Evening.StartHour and h < Config.TimeOfDay.Evening.EndHour then return Config.TimeOfDay.Evening end
    return Config.TimeOfDay.Night
end

function Features.timings()
    local p = Features.period()
    return p.Green, p.Yellow, p.AllRed
end

function Features.isFlashing()
    return Config.TimeOfDay.Enabled and Features.period().Flashing == true
end

local function vehiclesFor(intersection)
    local result = { NS = {}, EW = {} }
    if not Config.Adaptive.Enabled and not Config.Queues.Enabled then return result end
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver) then
                local p = GetEntityCoords(vehicle)
                local d = dist(p, intersection.center)
                if d <= Config.Adaptive.DetectionDistance then
                    local a = axis(intersection.center, p)
                    result[a][#result[a] + 1] = { vehicle = vehicle, distance = d, speed = GetEntitySpeed(vehicle) }
                end
            end
        end
    end
    table.sort(result.NS, function(a,b) return a.distance < b.distance end)
    table.sort(result.EW, function(a,b) return a.distance < b.distance end)
    return result
end

function Features.update(intersection)
    if not Features.state[intersection.key] then
        Features.state[intersection.key] = { waitNS = 0, waitEW = 0, last = 0, ped = nil }
    end
    local s = Features.state[intersection.key]
    local now = GetGameTimer()
    if now - s.last < Config.Adaptive.RecomputeInterval then return end
    s.last = now

    local q = vehiclesFor(intersection)
    local ns = math.min(#q.NS, Config.Adaptive.MaxQueueVehicles)
    local ew = math.min(#q.EW, Config.Adaptive.MaxQueueVehicles)
    local current = intersection.phase or 'NS_GREEN'
    local currentAxis = (current == 'NS_GREEN' or current == 'NS_YELLOW') and 'NS' or 'EW'
    if ns > 0 then s.waitNS = s.waitNS + Config.Adaptive.RecomputeInterval / 1000.0 else s.waitNS = math.max(0, s.waitNS - 1) end
    if ew > 0 then s.waitEW = s.waitEW + Config.Adaptive.RecomputeInterval / 1000.0 else s.waitEW = math.max(0, s.waitEW - 1) end

    s.queueNS, s.queueEW = ns, ew
    s.scoreNS = ns * Config.Adaptive.QueueWeight + s.waitNS * Config.Adaptive.WaitingTimeWeight
    s.scoreEW = ew * Config.Adaptive.QueueWeight + s.waitEW * Config.Adaptive.WaitingTimeWeight

    -- The phase selector uses these scores only at a green-to-green decision;
    -- this avoids unsafe mid-phase reversals.
    if currentAxis == 'NS' then
        s.nextAxis = (s.scoreEW > s.scoreNS or s.waitEW >= Config.Adaptive.StarvationLimit) and 'EW' or 'NS'
    else
        s.nextAxis = (s.scoreNS > s.scoreEW or s.waitNS >= Config.Adaptive.StarvationLimit) and 'NS' or 'EW'
    end
end

function Features.desiredPhase(intersection, fallback)
    Features.update(intersection)
    local s = Features.state[intersection.key]
    if intersection.emergency then
        return intersection.emergency.axis == 'NS' and 'NS_GREEN' or 'EW_GREEN'
    end
    if Features.isFlashing() then return 'FLASHING' end
    if not Config.Adaptive.Enabled or not s or not s.nextAxis then return fallback end
    return s.nextAxis == 'NS' and 'NS_GREEN' or 'EW_GREEN'
end

function Features.phaseDuration(phase)
    local green, yellow, allRed = Features.timings()
    if phase == 'NS_GREEN' or phase == 'EW_GREEN' then
        if Config.Adaptive.Enabled then
            return math.max(Config.Adaptive.MinimumGreen, math.min(green, Config.Adaptive.MaximumGreen))
        end
        return green
    end
    if phase == 'NS_YELLOW' or phase == 'EW_YELLOW' then return yellow end
    if phase == 'ALL_RED' then return math.max(allRed, Config.Safety.MinimumAllRed) end
    return 0.8
end

function Features.applySpecial(intersection)
    if not Features.isFlashing() then return false end
    local now = GetGameTimer()
    local on = math.floor(now / Config.TimeOfDay.FlashInterval) % 2 == 0
    for _, head in ipairs(intersection.heads) do
        if DoesEntityExist(head.entity) then
            local state = SIGNAL_RED
            if head.axis == 'NS' then
                state = on and SIGNAL_YELLOW or SIGNAL_RED
            else
                state = on and SIGNAL_RED or SIGNAL_YELLOW
            end
            SetEntityTrafficlightOverride(head.entity, state)
        end
    end
    return true
end

function Features.getQueue(intersection, approachAxis)
    local s = Features.state[intersection.key]
    if not s then return 0 end
    return approachAxis == 'NS' and (s.queueNS or 0) or (s.queueEW or 0)
end

-- Lightweight pedestrian request detection. We use nearby non-player peds and
-- players near the intersection as a request signal; no traffic signal object
-- is assumed to exist.
function Features.updatePedestrians(intersection)
    if not Config.Pedestrians.Enabled then return end
    local s = Features.state[intersection.key]
    if not s then return end
    local now = GetGameTimer()
    if s.ped and now < s.ped.untilTime then return end
    local request = false
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            local p = GetEntityCoords(ped)
            if dist(p, intersection.center) <= Config.Pedestrians.DetectionRadius and not IsPedInAnyVehicle(ped, false) then
                request = true
                break
            end
        end
    end
    if request and now - (s.lastPed or 0) > Config.Pedestrians.RequestCooldown * 1000 then
        s.lastPed = now
        s.ped = { untilTime = now + (Config.Pedestrians.WalkTime + Config.Pedestrians.FlashingDontWalkTime) * 1000 }
    end
end

function Features.pedestrianActive(intersection)
    local s = Features.state[intersection.key]
    return s and s.ped and GetGameTimer() < s.ped.untilTime
end

_G.TLOFeatures = Features
