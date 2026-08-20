# Traffic Lights Overhaul

A FiveM traffic-signal controller designed around realistic U.S.-style intersection timing, NPC traffic control, adaptive timing, emergency preemption, pedestrian safety, and coordinated signals.

## v0.3.0 development build

### Signal controller
- Automatic GTA traffic-light discovery and intersection grouping.
- Deterministic green/yellow/all-red sequencing.
- Safe yellow and all-red transitions.
- Emergency preemption based on **emergency lights**, not merely vehicle class.
- Optional siren requirement.

### NPC traffic
- Separate traffic-AI interception layer for NPC-driven vehicles.
- Player vehicles are never intentionally overridden.
- Red-signal traffic can be routed toward a roadside/shoulder point.
- GTA road nodes are used when available to keep pull-over targets on drivable roads.
- Vehicles are released back to normal GTA driving when permitted.

### Adaptive traffic
- Counts approaching NPC traffic by axis.
- Tracks queue pressure and accumulated waiting time.
- Uses configurable minimum/maximum green times.
- Starvation protection prevents one direction from being ignored indefinitely.
- Queue spacing and detection distances are configurable.

### U.S.-style signal features
- Protected/permissive turn configuration groundwork.
- Right-on-red configuration.
- Protected left-turn timing settings.
- Pedestrian request/safety phase framework.
- Configurable WALK and flashing DON'T WALK timing.

### Time-of-day plans
Time-of-day behavior is controlled by `Config.TimeOfDay.Enabled`.

When `false`, the normal `Config.Normal` timings are used and no time-of-day flashing mode is applied.

When `true`, separate Day, Evening, and Night plans can define:
- Green duration
- Yellow duration
- All-red duration
- Flashing operation
- Flash interval

The default Night plan is configured for flashing operation, but the entire feature is disabled by default so existing servers are not unexpectedly changed.

### Coordinated intersections
Nearby intersections can share a preferred signal axis to form the basis of green-wave corridors. Emergency preemption can break coordination when configured to do so.

## Installation

1. Put the resource in the server's resources directory.
2. Add `ensure Traffic-Lights-Overhaul` to `server.cfg`.
3. Restart the resource/server.
4. Test with `/tlo_debug`.

## Key configuration groups

`config.lua` exposes the major tuning points:

- `Config.Normal` — baseline signal timing.
- `Config.Adaptive` — queue-based signal timing.
- `Config.Queues` — queue spacing and holding limits.
- `Config.Turns` — protected left/right-on-red behavior settings.
- `Config.Pedestrians` — pedestrian request and clearance timing.
- `Config.Emergency` — emergency detection, light/siren requirements, hold times.
- `Config.Coordination` — corridor/green-wave behavior.
- `Config.TimeOfDay` — optional Day/Evening/Night timing plans and flashing mode.
- `Config.Safety` — all-red minimums and intersection safety rules.
- `Config.NpcTraffic` — AI detection, driving style, pull-over and road-node behavior.
- `Config.DebugOptions` — development diagnostics.

## Recommended starting configuration

For a production server, start with:

```lua
Config.TimeOfDay.Enabled = false
Config.Adaptive.Enabled = true
Config.Queues.Enabled = true
Config.Emergency.Enabled = true
Config.Emergency.RequireEmergencyLights = true
Config.Emergency.RequireSiren = false
Config.Coordination.Enabled = true
Config.Pedestrians.Enabled = true
Config.NpcTraffic.Enabled = true
```

Enable time-of-day plans only after testing the map's traffic-light models and intersection grouping.

## Development roadmap

### Completed in the current development build
- [x] Signal discovery and intersection grouping
- [x] Normal U.S.-style phase sequencing
- [x] Emergency-light-based preemption
- [x] NPC traffic interception
- [x] Roadside/road-node pull-over behavior
- [x] Adaptive queue pressure calculation
- [x] Configurable queue management
- [x] Time-of-day timing plans and optional flashing operation
- [x] Coordinated intersection axis selection
- [x] Pedestrian request/safety framework
- [x] Protected-turn configuration framework

### Next refinement
- Lane-level turn movement detection.
- Dedicated physical left-turn signal-head detection.
- Actual pedestrian signal object detection/control where map assets expose it.
- More precise road-node lane selection for pull-over behavior.
- Multi-intersection corridor definitions rather than proximity-only coordination.
- Railroad crossing integration.
- Admin UI/debug visualization.

## Important technical note

FiveM exposes GTA's vehicle AI through tasks rather than a single replaceable "traffic AI" API. This resource therefore uses a hybrid architecture: GTA retains navigation/pathfinding while Traffic Lights Overhaul controls intersection permission, stopping, queue behavior, and signal phases.
