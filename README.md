# Traffic Lights Overhaul

A FiveM traffic-signal controller designed around realistic U.S.-style intersection timing, NPC traffic control, adaptive timing, emergency preemption, pedestrian safety, lane analysis, and coordinated signals.

## v0.4.0-test

This branch is now arranged as a **test build**. It is not a production release yet.

### Installation

1. Put the resource in your server's `resources` directory.
2. Add `ensure Traffic-Lights-Overhaul` to `server.cfg`.
3. Restart the resource.
4. Verify the console shows no Lua load errors.
5. Drive near a normal signalized intersection.

### Test/debug commands

```text
/tlo_debug
```
Toggles the main visualization.

```text
/tlo_debug_options intersections
/tlo_debug_options queues
/tlo_debug_options emergency
/tlo_debug_options pedestrian
/tlo_debug_options coordination
```
Toggles individual diagnostic layers.

### Recommended first-test configuration

Keep these conservative settings for the first server test:

```lua
Config.Debug = false
Config.LaneAnalysis.Enabled = true
Config.Adaptive.Enabled = true
Config.Queues.Enabled = true
Config.Emergency.Enabled = true
Config.Emergency.RequireEmergencyLights = true
Config.Emergency.RequireSiren = false
Config.Coordination.Enabled = true
Config.Pedestrians.Enabled = true
Config.NpcTraffic.Enabled = true
Config.TimeOfDay.Enabled = false
```

Time-of-day flashing is intentionally disabled during the first test. Enable it only after normal signal sequencing is confirmed.

### Test checklist

#### 1. Basic signal operation
- [ ] Signals are discovered near the player.
- [ ] N/S and E/W phases alternate.
- [ ] Green transitions to yellow before changing direction.
- [ ] All-red clearance occurs between conflicting greens.
- [ ] Leaving the area and returning does not create duplicate intersections.

#### 2. NPC traffic
- [ ] NPC vehicles approaching red signals are detected.
- [ ] Player-controlled vehicles are not intentionally overridden.
- [ ] NPCs do not stop after entering the intersection clear zone.
- [ ] NPCs pull toward a roadside/road-node point when configured.
- [ ] NPCs resume normal driving after their approach receives permission.

#### 3. Emergency preemption
- [ ] Class 18 vehicle with emergency lights OFF behaves as normal traffic.
- [ ] Class 18 vehicle with emergency lights ON is detected.
- [ ] Siren is not required with the default configuration.
- [ ] The emergency approach receives priority.
- [ ] Conflicting traffic receives a safe yellow/all-red transition.
- [ ] The intersection resumes normal operation after the emergency clears.

#### 4. Adaptive timing
- [ ] A busy approach accumulates queue pressure.
- [ ] Green duration stays within configured minimum/maximum bounds.
- [ ] An empty approach does not receive unnecessary long green time.
- [ ] Starvation protection eventually serves a waiting approach.

#### 5. Lane analyzer
- [ ] `/tlo_debug` shows the active intersection.
- [ ] NPCs show NORTH/SOUTH/EAST/WEST approach labels.
- [ ] Vehicles receive LEFT/THROUGH/RIGHT movement estimates.
- [ ] Queue ordering is visible with the queues debug option.
- [ ] Movement estimates are treated as approximate, not guaranteed.

#### 6. Pedestrians
- [ ] A pedestrian near an active intersection creates a request.
- [ ] Traffic is not held forever by a pedestrian request.
- [ ] Clearance timing completes before conflicting traffic is released.

#### 7. Coordination
- [ ] Nearby intersections can select the same preferred axis.
- [ ] Emergency preemption can break coordination.
- [ ] Unrelated intersections are not synchronized when outside the configured corridor distance.

#### 8. Time of day
Keep disabled for the initial test. After normal operation is verified:

```lua
Config.TimeOfDay.Enabled = true
```

Then test Day, Evening, and Night separately. The Night plan can use flashing yellow/red behavior.

## Key configuration groups

- `Config.Normal` — baseline signal timing.
- `Config.LaneAnalysis` — lane/movement detection tuning.
- `Config.Adaptive` — queue-based signal timing.
- `Config.Queues` — queue spacing and holding limits.
- `Config.Turns` — protected left/right-on-red behavior settings.
- `Config.Pedestrians` — pedestrian request and clearance timing.
- `Config.Emergency` — emergency detection and light/siren requirements.
- `Config.Coordination` — corridor/green-wave behavior.
- `Config.TimeOfDay` — optional Day/Evening/Night timing plans.
- `Config.Safety` — all-red and intersection safety rules.
- `Config.NpcTraffic` — AI detection, driving style, pull-over and road-node behavior.
- `Config.DebugOptions` — development diagnostics.

## Architecture

FiveM exposes GTA's vehicle AI through tasks rather than a single replaceable traffic-AI API. TLO therefore uses a hybrid architecture: GTA retains navigation/pathfinding while Traffic Lights Overhaul controls intersection permission, stopping, queue behavior, and signal phases.

## Important limitation

The lane analyzer and turn classification are heuristic. GTA's map does not provide a universal, clean lane-to-signal mapping for every intersection. Do not treat the current protected-turn/pedestrian/coordination frameworks as production-grade until they have been tested against the specific map and traffic-light assets used by the server.
