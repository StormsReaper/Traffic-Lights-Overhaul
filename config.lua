Config = {}

Config.Debug = false
Config.ScanInterval = 1500
Config.SignalUpdateInterval = 250
Config.IntersectionMergeDistance = 32.0
Config.SignalSearchRadius = 45.0
Config.IntersectionActivationRadius = 260.0

Config.Normal = {
    Green = 25.0,
    Yellow = 4.0,
    AllRed = 2.0,
    StartPhase = 'NS_GREEN'
}

Config.Emergency = {
    Enabled = true,
    DetectionRadius = 180.0,
    MinimumSpeed = 3.0,
    LookAheadDot = 0.45,
    HoldAfterClear = 2.0,
    MaxHold = 35.0,
    RequireSiren = true,
    RequireEmergencyClass = true,
    Classes = {
        [18] = true -- Emergency vehicles
    }
}

-- GTA traffic-light object models. The scanner discovers these locally and groups
-- nearby heads into intersections. Add models here if a server uses custom signal props.
Config.SignalModels = {
    'prop_traffic_01a',
    'prop_traffic_01b',
    'prop_traffic_01d',
    'prop_traffic_02a',
    'prop_traffic_03a',
    'prop_traffic_04a',
    'prop_traffic_05a',
    'prop_traffic_01',
    'prop_traffic_02',
    'prop_traffic_03',
    'prop_traffic_04',
    'prop_traffic_05'
}

-- Optional fixed intersections. Automatic discovery is the default.
-- Example:
-- Config.Intersections = {
--     { coords = vector3(100.0, 200.0, 30.0), radius = 35.0 }
-- }
Config.Intersections = {}
