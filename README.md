# Traffic Lights Overhaul

A FiveM traffic-signal controller designed around realistic U.S.-style intersection timing and emergency-vehicle preemption.

## Current v0.1.0

- Automatically discovers GTA traffic-light objects near active players.
- Groups nearby signal heads into intersections.
- Runs a deterministic signal cycle so clients can converge on the same phase without a server-side timer.
- Uses green -> yellow -> all-red clearance -> opposing green sequencing.
- Detects approaching Class 18 emergency vehicles with an active siren.
- Determines the emergency vehicle's approach and gives that signal axis priority.
- Returns to the normal cycle after the emergency vehicle clears.
- `/tlo_debug` toggles client-side intersection diagnostics.
- `/tlo_status` reports resource status.

## Installation

1. Put the `Traffic-Lights-Overhaul` folder in the server's resources directory.
2. Add `ensure Traffic-Lights-Overhaul` to `server.cfg`.
3. Restart the resource/server.
4. Enter the city and use `/tlo_debug` while testing.

## Important limitation

This first implementation controls the GTA traffic-light entities through `SetEntityTrafficlightOverride`. GTA's pedestrian/vehicle AI is not guaranteed to obey a visual signal override. The next development stage should add an AI traffic-control layer that detects NPC vehicles at controlled junctions and makes them stop, queue, and proceed according to the controller state.

## Configuration

`config.lua` controls:

- Normal green/yellow/all-red timing.
- Signal discovery radius.
- Intersection grouping distance.
- Emergency detection radius.
- Emergency minimum speed.
- Emergency approach heading tolerance.
- Emergency hold/clear timing.
- Supported traffic-light models.

## Development roadmap

### Phase 1 - Signal controller
- [x] Automatic signal discovery
- [x] Intersection grouping
- [x] Deterministic normal cycle
- [x] Yellow and all-red clearance

### Phase 2 - Emergency preemption
- [x] Emergency vehicle detection
- [x] Approach direction detection
- [x] Priority signal phase
- [x] Return-to-normal behavior

### Phase 3 - AI traffic compliance
- [ ] Detect NPC traffic approaching controlled signals
- [ ] Stop NPC traffic at red/yellow signals
- [ ] Prevent red-light running caused by GTA's native junction logic
- [ ] Resume queued traffic after green
- [ ] Intersection box/queue management

### Phase 4 - Advanced U.S. traffic behavior
- [ ] Protected left-turn phases
- [ ] Pedestrian phases
- [ ] Vehicle-actuated signals
- [ ] Time-of-day timing plans
- [ ] Coordinated corridors
- [ ] Flashing red/yellow modes
- [ ] Railroad/emergency special phases
- [ ] Admin/debug tooling

## Notes

The resource is intentionally built in stages. Signal rendering/control and NPC traffic compliance are separate systems because changing a GTA traffic-light entity does not by itself guarantee that GTA's native traffic AI will obey the new state.
