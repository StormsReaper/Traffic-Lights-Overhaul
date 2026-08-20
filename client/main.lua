local intersections = {}
_G.TLOIntersections = intersections
local lastScan = 0
local lastEmergencyScan = 0

local SIGNAL_RED = 1
local SIGNAL_YELLOW = 2
local SIGNAL_GREEN = 0

local function dbg(message) if Config.Debug then print(('[TLO] %s'):format(message)) end end
local function distance(a, b) return #(a - b) end
local function normalize(v) local len = #v; if len < 0.001 then return vector3(0.0, 0.0, 0.0) end; return v / len end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function axisForPosition(center, position)
    local dx, dy = position.x - center.x, position.y - center.y
    return math.abs(dy) >= math.abs(dx) and 'NS' or 'EW'
end
local function approachForPosition(center, position)
    local dx, dy = position.x - center.x, position.y - center.y
    if math.abs(dy) >= math.abs(dx) then return dy >= 0.0 and 'NORTH' or 'SOUTH' end
    return dx >= 0.0 and 'EAST' or 'WEST'
end
local function intersectionKey(position) return ('%.0f:%.0f'):format(position.x / 10.0, position.y / 10.0) end

local function createIntersection(center)
    local key = intersectionKey(center)
    if intersections[key] then return intersections[key] end
    local cycle = Config.Normal.Green * 2.0 + Config.Normal.Yellow * 2.0 + Config.Normal.AllRed * 2.0
    intersections[key] = { key = key, center = center, heads = {}, emergency = nil, phase = nil, phaseStarted = GetGameTimer(), cycleOffset = math.abs(math.floor(center.x * 13.37 + center.y * 7.91)) % math.max(1, math.floor(cycle)) }
    return intersections[key]
end

local function scanSignals()
    local playerCoords, nearby = GetEntityCoords(PlayerPedId()), {}
    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object) then
            local model = GetEntityModel(object)
            for _, configuredModel in ipairs(Config.SignalModels) do
                if model == joaat(configuredModel) then
                    local coords = GetEntityCoords(object)
                    if distance(playerCoords, coords) <= Config.IntersectionActivationRadius then nearby[#nearby + 1] = { entity = object, coords = coords } end
                    break
                end
            end
        end
    end
    for _, signal in ipairs(nearby) do
        local assigned, closest = nil, Config.IntersectionMergeDistance
        for _, intersection in pairs(intersections) do
            local d = distance(intersection.center, signal.coords)
            if d < closest then closest, assigned = d, intersection end
        end
        if not assigned then assigned = createIntersection(signal.coords) end
        local known = false
        for _, head in ipairs(assigned.heads) do if head.entity == signal.entity then known = true break end end
        if not known then
            assigned.heads[#assigned.heads + 1] = { entity = signal.entity, axis = axisForPosition(assigned.center, signal.coords), approach = approachForPosition(assigned.center, signal.coords) }
            dbg(('Discovered signal at %.1f %.1f %.1f'):format(signal.coords.x, signal.coords.y, signal.coords.z))
        end
    end
    for key, intersection in pairs(intersections) do
        for i = #intersection.heads, 1, -1 do if not DoesEntityExist(intersection.heads[i].entity) then table.remove(intersection.heads, i) end end
        if #intersection.heads == 0 then intersections[key] = nil end
    end
end

-- Emergency signal preemption requires the actual emergency lightbar/strobe
-- state. Siren audio alone is deliberately NOT enough.
local function emergencyLightsActive(vehicle)
    if not Config.Emergency.Enabled or GetVehicleClass(vehicle) ~= 18 then return false end
    if not Config.Emergency.RequireEmergencyLights then return true end
    return GetVehicleSirenLights(vehicle) == true
end

local function isEmergencyVehicle(vehicle)
    return GetVehicleClass(vehicle) == 18 and (not Config.Emergency.RequireEmergencyClass or Config.Emergency.Classes[18] == true) and emergencyLightsActive(vehicle)
end

local function getEmergencyCandidates(center)
    local candidates = {}
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and isEmergencyVehicle(vehicle) then
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver ~= 0 and DoesEntityExist(driver) then
                local vehicleCoords = GetEntityCoords(vehicle)
                local delta = center - vehicleCoords
                local dist, speed = #delta, GetEntitySpeed(vehicle)
                if dist <= Config.Emergency.DetectionRadius and speed >= Config.Emergency.MinimumSpeed then
                    local approachDot = dot(GetEntityForwardVector(vehicle), normalize(delta))
                    if approachDot >= Config.Emergency.LookAheadDot then
                        candidates[#candidates + 1] = { vehicle = vehicle, distance = dist, speed = speed, eta = dist / math.max(speed, 0.1), approach = approachForPosition(center, vehicleCoords), axis = axisForPosition(center, vehicleCoords) }
                    end
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.eta < b.eta end)
    return candidates
end

local function updateEmergencyState()
    if not Config.Emergency.Enabled then return end
    local now = GetGameTimer()
    if now - lastEmergencyScan < Config.Emergency.ScanInterval then return end
    lastEmergencyScan = now
    for _, intersection in pairs(intersections) do
        local selected = getEmergencyCandidates(intersection.center)[1]
        if selected then
            intersection.emergency = { vehicle = selected.vehicle, approach = selected.approach, axis = selected.axis, distance = selected.distance, eta = selected.eta, lastSeen = now, started = intersection.emergency and intersection.emergency.started or now }
        elseif intersection.emergency and (now - intersection.emergency.lastSeen) / 1000.0 > Config.Emergency.HoldAfterClear then
            dbg(('Emergency cleared at %s'):format(intersection.key)); intersection.emergency = nil
        end
    end
end

local function normalPhase(intersection)
    local cycle = Config.Normal.Green * 2.0 + Config.Normal.Yellow * 2.0 + Config.Normal.AllRed * 2.0
    local t = (GetNetworkTimeAccurate() / 1000.0 + intersection.cycleOffset) % cycle
    local a = Config.Normal.Green; local b = a + Config.Normal.Yellow; local c = b + Config.Normal.AllRed; local d = c + Config.Normal.Green; local e = d + Config.Normal.Yellow; local f = e + Config.Normal.AllRed
    if t < a then return 'NS_GREEN' elseif t < b then return 'NS_YELLOW' elseif t < c then return 'ALL_RED' elseif t < d then return 'EW_GREEN' elseif t < e then return 'EW_YELLOW' elseif t < f then return 'ALL_RED' end
    return 'NS_GREEN'
end
local function phaseAxis(phase)
    if phase == 'NS_GREEN' or phase == 'NS_YELLOW' then return 'NS' end
    if phase == 'EW_GREEN' or phase == 'EW_YELLOW' then return 'EW' end
end
local function phaseIsGreen(phase) return phase == 'NS_GREEN' or phase == 'EW_GREEN' end
local function desiredPhase(intersection)
    if intersection.emergency then
        if (GetGameTimer() - intersection.emergency.started) / 1000.0 <= Config.Emergency.MaxHold then return intersection.emergency.axis == 'NS' and 'NS_GREEN' or 'EW_GREEN' end
        intersection.emergency = nil
    end
    return normalPhase(intersection)
end

local function applyPhase(intersection, phase)
    for _, head in ipairs(intersection.heads) do
        if DoesEntityExist(head.entity) then
            local state = SIGNAL_RED
            if phase == 'NS_GREEN' and head.axis == 'NS' then state = SIGNAL_GREEN elseif phase == 'NS_YELLOW' and head.axis == 'NS' then state = SIGNAL_YELLOW elseif phase == 'EW_GREEN' and head.axis == 'EW' then state = SIGNAL_GREEN elseif phase == 'EW_YELLOW' and head.axis == 'EW' then state = SIGNAL_YELLOW end
            SetEntityTrafficlightOverride(head.entity, state)
        end
    end
end

local function beginTransition(intersection, target)
    local current = intersection.phase
    if not current then intersection.phase, intersection.phaseStarted = target, GetGameTimer(); return end
    if current == target then return end
    local now = GetGameTimer()
    if phaseIsGreen(current) and phaseAxis(current) ~= phaseAxis(target) then intersection.phase, intersection.phaseStarted = phaseAxis(current) == 'NS' and 'NS_YELLOW' or 'EW_YELLOW', now
    elseif current == 'NS_YELLOW' or current == 'EW_YELLOW' then intersection.phase, intersection.phaseStarted = 'ALL_RED', now
    elseif current == 'ALL_RED' then intersection.phase, intersection.phaseStarted = target, now
    else intersection.phase, intersection.phaseStarted = target, now end
end

local function advancePhase(intersection)
    local now = GetGameTimer(); local elapsed = (now - intersection.phaseStarted) / 1000.0; local phase, desired = intersection.phase, desiredPhase(intersection)
    if (phase == 'NS_YELLOW' or phase == 'EW_YELLOW') and elapsed >= Config.Normal.Yellow then intersection.phase, intersection.phaseStarted = 'ALL_RED', now; return end
    if phase == 'ALL_RED' and elapsed >= Config.Normal.AllRed then intersection.phase, intersection.phaseStarted = desired, now; return end
    if intersection.emergency then
        if phaseIsGreen(phase) and phaseAxis(phase) == phaseAxis(desired) then return end
        beginTransition(intersection, desired)
    elseif desired ~= phase then beginTransition(intersection, desired) end
end

local function drawDebug(intersection)
    if not Config.Debug then return end
    local text = ('TLO | %s | heads=%d'):format(intersection.phase or 'NONE', #intersection.heads)
    if intersection.emergency then text = ('%s | EMERGENCY %s ETA %.1fs'):format(text, intersection.emergency.approach, intersection.emergency.eta or 0.0) end
    SetDrawOrigin(intersection.center.x, intersection.center.y, intersection.center.z + 3.0, 0); SetTextScale(0.28, 0.28); SetTextFont(4); SetTextCentre(true); SetTextEntry('STRING'); AddTextComponentString(text); DrawText(0.0, 0.0); ClearDrawOrigin()
end

CreateThread(function()
    while true do
        local wait = Config.ScanInterval; local playerCoords = GetEntityCoords(PlayerPedId())
        if GetGameTimer() - lastScan >= Config.ScanInterval then lastScan = GetGameTimer(); scanSignals() end
        updateEmergencyState()
        for _, intersection in pairs(intersections) do
            if distance(playerCoords, intersection.center) <= Config.IntersectionActivationRadius then
                if not intersection.phase then intersection.phase, intersection.phaseStarted = desiredPhase(intersection), GetGameTimer() end
                advancePhase(intersection); applyPhase(intersection, intersection.phase); drawDebug(intersection); wait = math.min(wait, Config.SignalUpdateInterval)
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, intersection in pairs(intersections) do for _, head in ipairs(intersection.heads) do if DoesEntityExist(head.entity) then SetEntityTrafficlightOverride(head.entity, 3) end end end
end)

RegisterCommand('tlo_debug', function() Config.Debug = not Config.Debug; print(('[TLO] Debug mode: %s'):format(Config.Debug and 'ON' or 'OFF')) end, false)
