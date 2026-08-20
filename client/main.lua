local intersections = {}
local emergencyCache = {}
local lastScan = 0
local lastEmergencyScan = 0

local SIGNAL_RED = 1
local SIGNAL_YELLOW = 2
local SIGNAL_GREEN = 0

local function dbg(message)
    if Config.Debug then
        print(('[TLO] %s'):format(message))
    end
end

local function distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function normalize(v)
    local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if len < 0.001 then return vector3(0.0, 0.0, 0.0) end
    return vector3(v.x / len, v.y / len, v.z / len)
end

local function dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function axisForPosition(center, position)
    local dx = position.x - center.x
    local dy = position.y - center.y

    if math.abs(dy) >= math.abs(dx) then
        return 'NS'
    end

    return 'EW'
end

local function approachForPosition(center, position)
    local dx = position.x - center.x
    local dy = position.y - center.y

    if math.abs(dy) >= math.abs(dx) then
        return dy >= 0.0 and 'NORTH' or 'SOUTH'
    end

    return dx >= 0.0 and 'EAST' or 'WEST'
end

local function intersectionKey(position)
    return ('%.0f:%.0f'):format(position.x / 10.0, position.y / 10.0)
end

local function createIntersection(center)
    local key = intersectionKey(center)
    if intersections[key] then return intersections[key] end

    local cycle = Config.Normal.Green * 2.0 + Config.Normal.Yellow * 2.0 + Config.Normal.AllRed * 2.0
    local offset = math.abs(math.floor(center.x * 13.37 + center.y * 7.91)) % math.max(1, math.floor(cycle))

    local intersection = {
        key = key,
        center = center,
        heads = {},
        emergency = nil,
        cycleOffset = offset
    }

    intersections[key] = intersection
    return intersection
end

local function scanSignals()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearby = {}

    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object) then
            local model = GetEntityModel(object)
            local modelName

            for _, configuredModel in ipairs(Config.SignalModels) do
                if model == joaat(configuredModel) then
                    modelName = configuredModel
                    break
                end
            end

            if modelName then
                local coords = GetEntityCoords(object)
                if distance(playerCoords, coords) <= Config.IntersectionActivationRadius then
                    nearby[#nearby + 1] = {
                        entity = object,
                        coords = coords,
                        model = modelName
                    }
                end
            end
        end
    end

    for _, signal in ipairs(nearby) do
        local assigned
        local closest = Config.IntersectionMergeDistance

        for _, intersection in pairs(intersections) do
            local d = distance(intersection.center, signal.coords)
            if d < closest then
                closest = d
                assigned = intersection
            end
        end

        if not assigned then
            assigned = createIntersection(signal.coords)
        else
            -- Smooth the cluster center as more heads are discovered.
            assigned.center = vector3(
                (assigned.center.x + signal.coords.x) * 0.5,
                (assigned.center.y + signal.coords.y) * 0.5,
                (assigned.center.z + signal.coords.z) * 0.5
            )
        end

        local alreadyKnown = false
        for _, head in ipairs(assigned.heads) do
            if head.entity == signal.entity then
                alreadyKnown = true
                break
            end
        end

        if not alreadyKnown then
            assigned.heads[#assigned.heads + 1] = {
                entity = signal.entity,
                axis = axisForPosition(assigned.center, signal.coords),
                approach = approachForPosition(assigned.center, signal.coords)
            }
            dbg(('Discovered signal %s at %.1f %.1f %.1f'):format(
                signal.model, signal.coords.x, signal.coords.y, signal.coords.z))
        end
    end

    -- Remove dead entity references.
    for key, intersection in pairs(intersections) do
        for i = #intersection.heads, 1, -1 do
            if not DoesEntityExist(intersection.heads[i].entity) then
                table.remove(intersection.heads, i)
            end
        end

        if #intersection.heads == 0 then
            intersections[key] = nil
        end
    end
end

local function getEmergencyCandidates(center)
    local candidates = {}
    local playerPed = PlayerPedId()

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and GetVehicleClass(vehicle) == 18 then
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver ~= 0 and DoesEntityExist(driver) then
                local sirenOn = IsVehicleSirenOn(vehicle)
                local emergencyLights = IsVehicleSirenOn(vehicle)

                if (not Config.Emergency.RequireSiren or sirenOn) and emergencyLights then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local delta = center - vehicleCoords
                    local dist = #(delta)

                    if dist <= Config.Emergency.DetectionRadius and GetEntitySpeed(vehicle) >= Config.Emergency.MinimumSpeed then
                        local forward = GetEntityForwardVector(vehicle)
                        local toIntersection = normalize(delta)
                        local approachDot = dot(forward, toIntersection)

                        if approachDot >= Config.Emergency.LookAheadDot then
                            candidates[#candidates + 1] = {
                                vehicle = vehicle,
                                distance = dist,
                                speed = math.max(GetEntitySpeed(vehicle), 0.1),
                                eta = dist / math.max(GetEntitySpeed(vehicle), 0.1),
                                approach = approachForPosition(center, vehicleCoords),
                                axis = axisForPosition(center, vehicleCoords)
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.eta < b.eta
    end)

    return candidates
end

local function updateEmergencyState()
    local now = GetGameTimer()

    if now - lastEmergencyScan < 500 then return end
    lastEmergencyScan = now

    for _, intersection in pairs(intersections) do
        local candidates = getEmergencyCandidates(intersection.center)
        local selected = candidates[1]

        if selected then
            intersection.emergency = {
                vehicle = selected.vehicle,
                approach = selected.approach,
                axis = selected.axis,
                lastSeen = now,
                started = intersection.emergency and intersection.emergency.started or now
            }
        elseif intersection.emergency then
            local elapsed = (now - intersection.emergency.lastSeen) / 1000.0
            if elapsed > Config.Emergency.HoldAfterClear then
                intersection.emergency = nil
            end
        end
    end
end

local function normalPhase(intersection)
    local cycle = Config.Normal.Green * 2.0 + Config.Normal.Yellow * 2.0 + Config.Normal.AllRed * 2.0
    local networkSeconds = GetNetworkTimeAccurate() / 1000.0
    local t = (networkSeconds + intersection.cycleOffset) % cycle

    local nsGreenEnd = Config.Normal.Green
    local nsYellowEnd = nsGreenEnd + Config.Normal.Yellow
    local allRed1End = nsYellowEnd + Config.Normal.AllRed
    local ewGreenEnd = allRed1End + Config.Normal.Green
    local ewYellowEnd = ewGreenEnd + Config.Normal.Yellow
    local allRed2End = ewYellowEnd + Config.Normal.AllRed

    if t < nsGreenEnd then
        return 'NS_GREEN'
    elseif t < nsYellowEnd then
        return 'NS_YELLOW'
    elseif t < allRed1End then
        return 'ALL_RED'
    elseif t < ewGreenEnd then
        return 'EW_GREEN'
    elseif t < ewYellowEnd then
        return 'EW_YELLOW'
    elseif t < allRed2End then
        return 'ALL_RED'
    end

    return 'NS_GREEN'
end

local function emergencyPhase(intersection)
    if not intersection.emergency then return nil end

    if (GetGameTimer() - intersection.emergency.started) / 1000.0 > Config.Emergency.MaxHold then
        intersection.emergency = nil
        return nil
    end

    return intersection.emergency.axis == 'NS' and 'NS_GREEN' or 'EW_GREEN'
end

local function applyPhase(intersection, phase)
    for _, head in ipairs(intersection.heads) do
        if DoesEntityExist(head.entity) then
            local state = SIGNAL_RED

            if phase == 'NS_GREEN' and head.axis == 'NS' then
                state = SIGNAL_GREEN
            elseif phase == 'NS_YELLOW' and head.axis == 'NS' then
                state = SIGNAL_YELLOW
            elseif phase == 'EW_GREEN' and head.axis == 'EW' then
                state = SIGNAL_GREEN
            elseif phase == 'EW_YELLOW' and head.axis == 'EW' then
                state = SIGNAL_YELLOW
            end

            SetEntityTrafficlightOverride(head.entity, state)
        end
    end
end

local function drawDebug(intersection, phase)
    if not Config.Debug then return end

    local e = intersection.emergency
    local text = ('TLO | %s | heads=%d'):format(phase, #intersection.heads)

    if e then
        text = ('%s | EMERGENCY %s'):format(text, e.approach)
    end

    SetDrawOrigin(intersection.center.x, intersection.center.y, intersection.center.z + 3.0, 0)
    SetTextScale(0.28, 0.28)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        local wait = Config.ScanInterval
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        if GetGameTimer() - lastScan >= Config.ScanInterval then
            lastScan = GetGameTimer()
            scanSignals()
        end

        if next(intersections) then
            updateEmergencyState()

            for _, intersection in pairs(intersections) do
                if distance(coords, intersection.center) <= Config.IntersectionActivationRadius then
                    local phase = emergencyPhase(intersection) or normalPhase(intersection)
                    applyPhase(intersection, phase)
                    drawDebug(intersection, phase)
                    wait = Config.SignalUpdateInterval
                end
            end
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, intersection in pairs(intersections) do
        for _, head in ipairs(intersection.heads) do
            if DoesEntityExist(head.entity) then
                SetEntityTrafficlightOverride(head.entity, 3)
            end
        end
    end
end)

RegisterCommand('tlo_debug', function()
    Config.Debug = not Config.Debug
    print(('[TLO] Debug mode: %s'):format(Config.Debug and 'ON' or 'OFF'))
end, false)
