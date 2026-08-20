Config = {}

Config.Debug = false
Config.ScanInterval = 1500
Config.SignalUpdateInterval = 100
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
    ScanInterval = 400,
    -- Preemption is strictly tied to the emergency lighting system.
    RequireSiren = true,
    RequireEmergencyLights = true,
    RequireEmergencyClass = true,
    Classes = { [18] = true }
}

Config.NpcTraffic = {
    Enabled = true,
    ScanInterval = 250,
    ControlRadius = 110.0,
    DetectionRadius = 75.0,
    IntersectionClearRadius = 12.0,
    LookAheadDot = 0.55,
    StopApproachSpeed = 4.0,
    ReleaseSpeed = 16.0,
    DrivingStyle = 786603,
    StopAction = 6,
    StopActionDuration = 900,

    -- Instead of stopping NPCs in their lane, the controller asks GTA's
    -- driving AI to move toward the shoulder/road edge before holding them.
    PullOver = {
        Enabled = true,
        ShoulderOffset = 3.0,
        PullOverSpeed = 5.0,
        MaxPullOverDistance = 35.0,
        ArrivalDistance = 7.0,
        ActionDuration = 1200,
        RepathInterval = 900
    }
}

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

Config.Intersections = {}
