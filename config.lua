Config = {}

Config.Debug = false
Config.ScanInterval = 1500
Config.SignalUpdateInterval = 100
Config.IntersectionMergeDistance = 32.0
Config.SignalSearchRadius = 45.0
Config.IntersectionActivationRadius = 260.0

Config.Normal = { Green = 25.0, Yellow = 4.0, AllRed = 2.0, StartPhase = 'NS_GREEN' }

Config.LaneAnalysis = {
    Enabled = true,
    UpdateInterval = 300,
    DetectionDistance = 100.0,
    IntersectionClearRadius = 10.0,
    LaneWidth = 3.5,
    MaxLanesPerApproach = 4,
    ThroughAlignment = 0.82,
    TurnThreshold = 0.28,
    DebugIntersectionSize = 24.0
}

Config.Adaptive = {
    Enabled = true, MinimumGreen = 12.0, MaximumGreen = 45.0,
    DetectionDistance = 95.0, QueueDistance = 55.0, QueueSpacing = 9.0,
    MaxQueueVehicles = 12, QueueWeight = 2.0, WaitingTimeWeight = 1.25,
    StarvationLimit = 55.0, ExtensionStep = 4.0, RecomputeInterval = 1000
}

Config.Queues = {
    Enabled = true, MaxQueueVehicles = 16, VehicleSpacing = 7.5,
    StopBuffer = 3.5, RecheckInterval = 350, MaxHoldTime = 90.0,
    ClearInsideIntersection = true
}

Config.Turns = {
    Enabled = true, ProtectedLeft = true, PermissiveLeft = true,
    PermissiveRight = true, RightOnRed = true, RightOnRedStopTime = 1.5,
    LeftTurnDetectionDistance = 42.0, ProtectedLeftDuration = 9.0,
    LeftYellow = 3.0, FlashingYellowArrow = true
}

Config.Pedestrians = {
    Enabled = true, DetectionRadius = 18.0, CrossingRadius = 10.0,
    WalkTime = 7.0, FlashingDontWalkTime = 7.0, ClearanceSpeed = 1.35,
    RequestCooldown = 10.0, HoldTrafficForWalk = true
}

Config.Emergency = {
    Enabled = true, DetectionRadius = 180.0, MinimumSpeed = 3.0,
    LookAheadDot = 0.45, HoldAfterClear = 2.0, MaxHold = 35.0,
    ScanInterval = 400, RequireSiren = false, RequireEmergencyLights = true,
    RequireEmergencyClass = true, Classes = { [18] = true }
}

Config.Coordination = {
    Enabled = true, DetectionRadius = 120.0, CorridorMaxDistance = 450.0,
    TargetSpeed = 13.0, LookAheadDistance = 90.0, MaxOffsetCorrection = 8.0,
    SyncInterval = 2000, AllowEmergencyBreakout = true
}

Config.TimeOfDay = {
    Enabled = false, UseGameClock = true,
    Day = { StartHour = 6, EndHour = 18, Green = 28.0, Yellow = 4.0, AllRed = 2.0, Flashing = false },
    Evening = { StartHour = 18, EndHour = 22, Green = 22.0, Yellow = 4.0, AllRed = 2.0, Flashing = false },
    Night = { StartHour = 22, EndHour = 6, Green = 14.0, Yellow = 3.0, AllRed = 2.0, Flashing = true },
    FlashingMainColor = 'YELLOW', FlashingSideColor = 'RED', FlashInterval = 800
}

Config.Safety = {
    MinimumAllRed = 1.5, ClearIntersectionBeforePhaseChange = true, ClearDistance = 11.0,
    MaximumEmergencyHold = 45.0, NeverStopInsideIntersection = true, NeverOverridePlayerVehicles = true
}

Config.DebugOptions = {
    DrawIntersections = false, DrawQueues = false, DrawEmergency = true,
    DrawPedestrian = false, DrawCoordination = false, PrintPhaseChanges = false
}

Config.NpcTraffic = {
    Enabled = true, ScanInterval = 250, ControlRadius = 110.0, DetectionRadius = 75.0,
    IntersectionClearRadius = 12.0, LookAheadDot = 0.55, StopApproachSpeed = 4.0,
    ReleaseSpeed = 16.0, DrivingStyle = 786603, StopAction = 6, StopActionDuration = 900,
    PullOver = {
        Enabled = true, UseRoadNode = true, NodeSearchRadius = 12.0, MaxNodeDistance = 10.0,
        ShoulderOffset = 2.8, PullOverSpeed = 5.0, MaxPullOverDistance = 28.0,
        ArrivalDistance = 2.5, RepathInterval = 1200
    }
}

Config.SignalModels = {
    'prop_traffic_01a','prop_traffic_01b','prop_traffic_01d','prop_traffic_02a',
    'prop_traffic_03a','prop_traffic_04a','prop_traffic_05a','prop_traffic_01',
    'prop_traffic_02','prop_traffic_03','prop_traffic_04','prop_traffic_05'
}

Config.Intersections = {}
