local TrafficAI = {}
TrafficAI.states = {}

local function distance(a, b) return #(a - b) end
local function normalize(v) local len = #v; if len < 0.001 then return vector3(0.0, 0.0, 0.0) end; return v / len end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function approach(center, coords)
    local dx, dy = coords.x - center.x, coords.y - center.y
    if math.abs(dy) >= math.abs(dx) then return dy >= 0 and 'NORTH' or 'SOUTH' end
    return dx >= 0 and 'EAST' or 'WEST'
end
local function axis(dir) return (dir == 'NORTH' or dir == 'SOUTH') and 'NS' or 'EW' end

local function controlledVehicle(vehicle)
    if not DoesEntityExist(vehicle) or IsEntityDead(vehicle) then return false end
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == 0 or not DoesEntityExist(driver) or IsPedAPlayer(driver) then return false end
    return true, driver
end

local function approaching(vehicle, center)
    local coords = GetEntityCoords(vehicle)
    local delta = center - coords
    local dist = #delta
    if dist > Config.NpcTraffic.DetectionRadius or dist < Config.NpcTraffic.IntersectionClearRadius then return false, dist end
    if GetEntitySpeed(vehicle) < 0.25 then return false, dist end
    return dot(GetEntityForwardVector(vehicle), normalize(delta)) >= Config.NpcTraffic.LookAheadDot, dist
end

-- Emergency preemption is tied to the actual emergency lightbar/strobe state,
-- not merely the audible siren state. A Class 18 vehicle with its siren audio
-- on but emergency lights off will NOT receive signal priority.
local function emergencyLightsActive(vehicle)
    if not Config.Emergency.Enabled or GetVehicleClass(vehicle) ~= 18 then return false end
    if not Config.Emergency.RequireEmergencyLights then return true end
    return GetVehicleSirenLights(vehicle) == true
end

function TrafficAI.isEmergency(vehicle)
    return emergencyLightsActive(vehicle)
end

function TrafficAI.shouldStop(intersection, vehicle)
    if TrafficAI.isEmergency(vehicle) then return false end
    local phase = intersection.phase
    if not phase then return true end
    local a = axis(approach(intersection.center, GetEntityCoords(vehicle)))
    if phase == 'NS_GREEN' and a == 'NS' then return false end
    if phase == 'EW_GREEN' and a == 'EW' then return false end
    return true
end

local function getShoulderPoint(vehicle, intersection)
    local coords = GetEntityCoords(vehicle)
    local forward = normalize(GetEntityForwardVector(vehicle))
    local right = vector3(-forward.y, forward.x, 0.0)
    local leftPoint = coords - right * Config.NpcTraffic.PullOver.ShoulderOffset
    local rightPoint = coords + right * Config.NpcTraffic.PullOver.ShoulderOffset

    -- Prefer the side that moves farther away from the intersection center.
    -- This is a practical fallback for GTA's road graph when an explicit
    -- shoulder node is not available.
    local side = right
    if distance(leftPoint, intersection.center) > distance(rightPoint, intersection.center) then
        side = -right
    end

    local distToIntersection = distance(coords, intersection.center)
    local ahead = math.min(Config.NpcTraffic.PullOver.MaxPullOverDistance, math.max(8.0, distToIntersection * 0.35))
    local point = coords + forward * ahead + side * Config.NpcTraffic.PullOver.ShoulderOffset
    return vector3(point.x, point.y, coords.z)
end

local function pullOver(driver, vehicle, intersection, state)
    if not Config.NpcTraffic.PullOver.Enabled then return false end
    local now = GetGameTimer()
    if state.pullOverPoint and now - (state.lastRepath or 0) < Config.NpcTraffic.PullOver.RepathInterval then return true end

    state.pullOverPoint = getShoulderPoint(vehicle, intersection)
    state.lastRepath = now

    TaskVehicleDriveToCoord(
        driver,
        vehicle,
        state.pullOverPoint.x,
        state.pullOverPoint.y,
        state.pullOverPoint.z,
        Config.NpcTraffic.PullOver.PullOverSpeed,
        0,
        GetEntityModel(vehicle),
        Config.NpcTraffic.DrivingStyle,
        2.5,
        5.0
    )
    state.pullingOver = true
    return true
end

local function stopAtShoulder(driver, vehicle, state)
    SetDriveTaskDrivingStyle(driver, Config.NpcTraffic.DrivingStyle)
    SetDriveTaskMaxCruiseSpeed(driver, 0.5)
    TaskVehicleTempAction(driver, vehicle, Config.NpcTraffic.StopAction, Config.NpcTraffic.StopActionDuration)
    state.stopped = true
end

local function release(driver, vehicle, state)
    ClearPedTasks(driver)
    SetDriveTaskDrivingStyle(driver, Config.NpcTraffic.DrivingStyle)
    SetDriveTaskMaxCruiseSpeed(driver, Config.NpcTraffic.ReleaseSpeed)
    state.stopped = false
    state.pullingOver = false
    state.pullOverPoint = nil
    state.lastRepath = 0
end

local function process(intersection, vehicle)
    local valid, driver = controlledVehicle(vehicle)
    if not valid then return end
    local isApproaching, dist = approaching(vehicle, intersection.center)
    if not isApproaching then return end

    local state = TrafficAI.states[vehicle]
    if not state then
        state = { stopped = false, pullingOver = false, pullOverPoint = nil, lastRepath = 0 }
        TrafficAI.states[vehicle] = state
    end
    state.lastSeen = GetGameTimer(); state.intersection = intersection.key; state.distance = dist

    -- Emergency vehicles only bypass the controller while their emergency
    -- lights are actually active.
    if TrafficAI.isEmergency(vehicle) then
        if state.stopped or state.pullingOver then release(driver, vehicle, state) end
        return
    end

    if TrafficAI.shouldStop(intersection, vehicle) then
        if not state.pullingOver and not state.stopped then
            if not pullOver(driver, vehicle, intersection, state) then
                SetDriveTaskMaxCruiseSpeed(driver, Config.NpcTraffic.StopApproachSpeed)
                TaskVehicleTempAction(driver, vehicle, Config.NpcTraffic.StopAction, Config.NpcTraffic.StopActionDuration)
                state.stopped = true
            end
        elseif state.pullingOver and state.pullOverPoint then
            if distance(GetEntityCoords(vehicle), state.pullOverPoint) <= Config.NpcTraffic.PullOver.ArrivalDistance then
                stopAtShoulder(driver, vehicle, state)
            end
        end
    elseif state.stopped or state.pullingOver then
        release(driver, vehicle, state)
    end
end

function TrafficAI.update(intersection)
    if not Config.NpcTraffic.Enabled then return end
    if distance(GetEntityCoords(PlayerPedId()), intersection.center) > Config.NpcTraffic.ControlRadius then return end
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do process(intersection, vehicle) end
end

_G.TLOTrafficAI = TrafficAI

CreateThread(function()
    while true do
        if Config.NpcTraffic.Enabled and _G.TLOIntersections then
            for _, intersection in pairs(_G.TLOIntersections) do
                TrafficAI.update(intersection)
            end
        end
        Wait(Config.NpcTraffic.ScanInterval)
    end
end)
