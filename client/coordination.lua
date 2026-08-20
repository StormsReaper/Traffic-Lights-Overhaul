local Coordination = {}

local function distance(a,b) return #(a-b) end

function Coordination.axisOverride(intersection)
    if not Config.Coordination.Enabled or not _G.TLOIntersections then return nil end
    if intersection.emergency and Config.Coordination.AllowEmergencyBreakout then return nil end

    local best, bestDistance
    for _,other in pairs(_G.TLOIntersections) do
        if other ~= intersection then
            local d=distance(intersection.center,other.center)
            if d<=Config.Coordination.CorridorMaxDistance and d>=Config.IntersectionMergeDistance then
                if other.phase=='NS_GREEN' or other.phase=='EW_GREEN' then
                    if not bestDistance or d<bestDistance then best,bestDistance=other,d end
                end
            end
        end
    end
    if not best then return nil end

    -- Favor the same axis as a nearby active intersection. This produces a
    -- practical green wave without forcing unrelated intersections to sync.
    return best.phase=='NS_GREEN' and 'NS' or 'EW'
end

function Coordination.update(intersection)
    if not Config.Coordination.Enabled then return end
    local s=intersection.coordination or {}
    local now=GetGameTimer()
    if now-(s.last or 0)<Config.Coordination.SyncInterval then return end
    s.last=now
    s.axis=Coordination.axisOverride(intersection)
    intersection.coordination=s
end

_G.TLOCoordination=Coordination
