local Debug = {}

local function drawText(x, y, text, scale)
    SetTextFont(0)
    SetTextScale(scale or 0.28, scale or 0.28)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(false)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function drawLine(a, b)
    DrawLine(a.x, a.y, a.z + 0.25, b.x, b.y, b.z + 0.25, 0, 255, 255, 180)
end

local function drawQueue(queue)
    if not Config.DebugOptions.DrawQueues then return end
    for index, item in ipairs(queue) do
        if DoesEntityExist(item.vehicle) then
            local p = GetEntityCoords(item.vehicle)
            DrawMarker(2, p.x, p.y, p.z + 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, 255, 190, 0, 160, false, true, 2, false, nil, nil, false)
            drawText(0.5, 0.68 + math.min(index, 8) * 0.022, ('%s #%d %s %.1fm'):format(item.approach, index, item.movement, item.distance), 0.23)
        end
    end
end

local function drawIntersection(intersection)
    if not Config.DebugOptions.DrawIntersections and not Config.Debug then return end

    local c = intersection.center
    local size = Config.LaneAnalysis.DebugIntersectionSize
    DrawMarker(1, c.x, c.y, c.z - 0.8, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.15, 0, 180, 255, 35, false, false, 2, false, nil, nil, false)

    local north = c + vector3(0.0, size * 0.5, 0.0)
    local south = c - vector3(0.0, size * 0.5, 0.0)
    local east = c + vector3(size * 0.5, 0.0, 0.0)
    local west = c - vector3(size * 0.5, 0.0, 0.0)
    drawLine(south, north)
    drawLine(west, east)

    local phase = intersection.phase or 'UNKNOWN'
    local emergency = intersection.emergency
    local text = ('TLO %s | %s'):format(intersection.key, phase)
    if emergency then text = text .. (' | EMS %.1fm %.1fs'):format(emergency.distance, emergency.eta) end
    drawText(0.015, 0.08, text, 0.30)

    if intersection.laneState then
        for _, queue in pairs(intersection.laneState.queues) do drawQueue(queue) end
    end
end

local function drawEmergency()
    if not Config.DebugOptions.DrawEmergency then return end
    for _, intersection in pairs(_G.TLOIntersections or {}) do
        local e = intersection.emergency
        if e and DoesEntityExist(e.vehicle) then
            local p = GetEntityCoords(e.vehicle)
            DrawMarker(2, p.x, p.y, p.z + 1.8, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 255, 30, 30, 220, false, true, 2, false, nil, nil, false)
        end
    end
end

CreateThread(function()
    while true do
        if Config.Debug and _G.TLOIntersections then
            for _, intersection in pairs(_G.TLOIntersections) do
                local p = GetEntityCoords(PlayerPedId())
                if #(p - intersection.center) <= Config.IntersectionActivationRadius then drawIntersection(intersection) end
            end
            drawEmergency()
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterCommand('tlo_debug_options', function(_, args)
    local value = args[1]
    if value == 'intersections' then Config.DebugOptions.DrawIntersections = not Config.DebugOptions.DrawIntersections
    elseif value == 'queues' then Config.DebugOptions.DrawQueues = not Config.DebugOptions.DrawQueues
    elseif value == 'emergency' then Config.DebugOptions.DrawEmergency = not Config.DebugOptions.DrawEmergency
    elseif value == 'pedestrian' then Config.DebugOptions.DrawPedestrian = not Config.DebugOptions.DrawPedestrian
    elseif value == 'coordination' then Config.DebugOptions.DrawCoordination = not Config.DebugOptions.DrawCoordination
    else print('[TLO] Usage: /tlo_debug_options intersections|queues|emergency|pedestrian|coordination'); return end
    print(('[TLO] Debug option %s: %s'):format(value, tostring(Config.DebugOptions['Draw' .. value:sub(1,1):upper() .. value:sub(2)])))
end, false)
