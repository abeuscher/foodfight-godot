# Food Fight Island - Development Roadmap

This document outlines the phased development plan for the prototype, designed for incremental implementation with Claude Code. Each phase builds on the previous, with automated GUT tests validating logic and manual playtesting validating balance and engagement.

**Development Priority Order:**
1. **Gameplay & Balance** (Current Focus) - Phases 0-9
2. **AI Opponent** - Phase 10
3. **Graphics & Views** - Phase 11-12

---

## Testing Strategy

### Automated Testing (GUT Framework)
Each step that generates new code includes GUT unit tests to verify correctness. Tests live in `res://test/unit/` and can be run via:
- In-editor: Run the `test/gut_runner.tscn` scene
- Command line: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit`

### Engagement Checkpoints
Marked with `[ENGAGE]` - these require running the game and manually verifying the interaction *feels* satisfying. Per the readme philosophy: if it doesn't feel good, we iterate before moving forward.

### Balance Checkpoints
Marked with `[BALANCE]` - these require multiple playthroughs testing specific unit combinations and strategies. Document findings in `balance-notes.md`.

---

## Phase 0: Project Foundation [COMPLETED]

**Goal:** Establish project structure, testing infrastructure, and baseline scene.

### Step 0.1: Directory Structure
```
res://
├── addons/gut/          # GUT testing framework
├── assets/
│   ├── sprites/
│   └── fonts/
├── scenes/
│   ├── main/
│   ├── structures/
│   ├── projectiles/
│   └── ui/
├── scripts/
│   ├── autoload/        # Singletons (GameManager, etc.)
│   ├── resources/       # Custom resource classes
│   └── components/      # Reusable logic
├── test/
│   ├── unit/
│   └── gut_runner.tscn
└── project.godot
```

### Step 0.2: GUT Installation & Configuration
- GUT addon installed (v9.x for Godot 4)
- `test/gut_runner.tscn` created for running tests

### Step 0.3: Game Manager Autoload
`GameManager` singleton tracks:
- Current game phase (BASE_PLACEMENT, PLACEMENT, TARGETING, FIGHT, GAME_OVER)
- Turn counter
- Win/lose status

---

## Phase 1: The Grid [COMPLETED]

**Goal:** A clickable grid that responds to input.

### Step 1.1: Grid Data Structure
`IslandGrid` class with:
- 2D array representing cells
- Cell states: EMPTY, OCCUPIED, BLOCKED
- Methods: `get_cell()`, `set_cell()`, `is_valid_position()`

### Step 1.2: Grid Visualization
`IslandGridView` scene:
- Draws grid lines
- Renders cell backgrounds based on state
- Configurable cell size and grid dimensions

### Step 1.3: Grid Input Handling
- Mouse hover highlights current cell
- Click emits `cell_clicked(grid_pos)` signal
- Visual feedback on hover/click

---

## Phase 2: Structure Placement [COMPLETED]

**Goal:** Player can place structures on the grid with satisfying feedback.

### Step 2.1: Structure Base Class
`Structure` resource with:
- Properties: `type`, `health`, `max_health`, `attack_priority`, `attack_damage`
- Additional properties: `interception_range`, `area_attack_radius`, `income_per_turn`, `heal_radius`, `heal_amount`, `radar_range`, `jam_radius`
- Jamming state: `is_jammed`, `jam_turns_remaining`

### Step 2.2: Structure Types
```
Type Enum: BASE, HOT_DOG_CANNON, CONDIMENT_CANNON, CONDIMENT_STATION,
           PICKLE_INTERCEPTOR, COFFEE_RADAR, VEGGIE_CANNON,
           LEMONADE_STAND, SALAD_BAR, RADAR_JAMMER
```

### Step 2.3: Placement System
`PlacementManager`:
- Tracks structures placed on grid
- Validates placement (cell empty, within bounds)
- Emits placement signals

### Step 2.4: Placement Visuals
- Ghost preview follows cursor
- Invalid positions show red tint

---

## Phase 3: Target Assignment [COMPLETED]

**Goal:** Player can aim offensive structures at enemy positions.

### Step 3.1: Two-Island Map Layout
- Player island (left)
- Enemy island (right)
- Canal/gap between them (height scales with grid size)

### Step 3.2: Targeting System
`TargetingManager`:
- Select offensive structure
- Click enemy grid to assign target
- Store assignments: `Dictionary[Structure, Vector2i]`
- Visual targeting lines

### Step 3.3: Fog of War
- Enemy cells start hidden
- Missiles reveal cells along flight path
- Revealed cells persist between turns
- Dev toggle to disable fog for testing

---

## Phase 4: Turn Execution [COMPLETED]

**Goal:** Watch programmed attacks resolve with satisfying feedback.

### Step 4.1: Turn Flow
Game phases: BASE_PLACEMENT → PLACEMENT → TARGETING → FIGHT
- End phase button transitions between phases
- Auto-advance when conditions met (e.g., all bases placed)

### Step 4.2: Execution Queue
`ExecutionManager`:
- Collects all structures with targets
- Sorts by attack priority (highest first)
- Processes queue sequentially

### Step 4.3: Projectile System
- Projectiles travel from source to target
- Configurable speed
- Emits arrival signal

### Step 4.4: Hit Resolution
- Check target cell for structures
- Apply damage to all structures in area (based on `area_attack_radius`)
- Destroy structures at 0 health

---

## Phase 5: Arsenal Expansion [COMPLETED]

**Goal:** Diverse arsenal of food-themed weapons and support structures.

### Current Structure Stats (All structures have 5+ HP)

| Structure | Cost | HP | Special |
|-----------|------|-----|---------|
| Base | Free | 5 | Critical - lose all 3 to lose game |
| Hot Dog Cannon | $5 | 5 | 1 dmg, 3x3 area |
| Condiment Cannon | $5 | 5 | 1 dmg, 3x3 area |
| Condiment Station | $10 | 5 | 1 dmg, 3x3 area |
| Pickle Interceptor | $5 | 5 | Defensive, requires radar |
| Coffee Radar | $10 | 5 | 20-block detection, +5% intercept chance |
| Veggie Cannon | $5 | 5 | Defensive, requires radar |
| Lemonade Stand | $20 | 5 | $5 passive income/turn |
| Salad Bar | $20 | 5 | Heals 1 HP/turn in 3x3 area |
| Radar Jammer | $15 | 5 | Jams radar for 3 turns, cannot be intercepted |

### Step 5.1: Economy System
- Player starts with $30
- Enemy has fixed arsenal (no economy)
- $5 earned per HP damage dealt (player only)
- Lemonade Stands generate passive income

### Step 5.2: Multiple Bases
- Each player places 3 bases (free)
- Game ends when ALL 3 bases destroyed
- Base placement phase auto-ends when all bases placed

---

## Phase 6: Defensive System [COMPLETED]

**Goal:** Radar-based interception with tactical depth.

### Step 6.1: Interception Mechanics
- **Base intercept chance:** 50%
- **Radar bonus:** +5% per active (non-jammed) radar
- Defensive towers require radar within range to function
- Intercept point: 70% of missile path (past canal)

### Step 6.2: Radar Jamming
- Radar Jammer missiles cannot be intercepted
- Jammed radars disabled for 3 turns
- Jam countdown decrements each turn
- Jammed radars don't contribute to intercept bonus

### Step 6.3: Loss Conditions
- All bases destroyed = lose
- No offensive structures AND no money = lose (cannot attack or buy)

---

## Phase 7: Win/Lose Polish [COMPLETED]

**Goal:** Clean game end states.

### Step 7.1: Game Over Detection
- Track destruction of all 3 bases per side
- Detect no-offense-no-money loss condition
- Transition to GAME_OVER state

### Step 7.2: Game Over Screen
- Win/lose message
- "Play Again" returns to intro screen
- Restart functionality

---

## Phase 8: Ground Combat System [NOT STARTED]

**Goal:** Add transport units, ground troops, and ground-based defense creating a second combat layer.

### Reference Behavior
The game being mimicked features:
- Transport units carry ground troops across the canal to the enemy island
- Ground troops act autonomously to destroy enemy installations
- Ground defense units (stationary or mobile) defend against invading troops
- This creates tension between air superiority (missiles) and ground control

### Step 8.1: Transport Unit
Create `TRANSPORT` structure type:
- Cost: $25
- HP: 5
- Capacity: 3 ground units
- Behavior: During FIGHT phase, travels across canal to enemy island
- Can be intercepted by defensive missiles (uses normal intercept chance)
- If destroyed, all carried units are lost
- If arrives, deploys carried units at landing zone

**Test:** `test_transport.gd`
- [ ] Transport can be placed on player grid
- [ ] Transport stores reference to carried units
- [ ] Transport can be targeted by enemy defenses
- [ ] Transport destruction destroys carried units
- [ ] Successful landing deploys units

### Step 8.2: Ground Unit Base Class
Create `GroundUnit` resource extending from base unit concept:
- Properties: `unit_type`, `health`, `max_health`, `attack_damage`, `movement_speed`, `attack_range`
- State: `current_position`, `target_structure`, `is_deployed`
- Ground units exist on the enemy's island after transport landing

**Test:** `test_ground_unit.gd`
- [ ] Ground unit initializes with correct stats
- [ ] Ground unit tracks position on enemy grid
- [ ] Ground unit can acquire targets
- [ ] Ground unit can take damage and be destroyed

### Step 8.3: Infantry Unit
Basic attacking ground unit:
- Cost: $5 (loaded into transport)
- HP: 3
- Attack: 1 damage per turn to adjacent structures
- Movement: 1 cell per turn
- Behavior: Move toward nearest enemy structure, attack when adjacent
- Priority targets: Radar > Defensive > Offensive > Economic > Base

**Test:** `test_infantry.gd`
- [ ] Infantry moves toward nearest target
- [ ] Infantry attacks adjacent structures
- [ ] Infantry follows target priority
- [ ] Infantry pathfinding avoids obstacles

### Step 8.4: Demolition Unit
Specialized anti-structure ground unit:
- Cost: $10
- HP: 2 (fragile)
- Attack: 3 damage (one-time explosion, destroys self)
- Movement: 2 cells per turn (fast)
- Behavior: Rush to highest-value target, detonate on arrival
- Priority targets: Base > Radar > Economic > Defensive > Offensive

**Test:** `test_demolition.gd`
- [ ] Demolition unit moves 2 cells per turn
- [ ] Demolition unit self-destructs on attack
- [ ] Attack deals 3 damage
- [ ] Follows correct target priority

### Step 8.5: Stationary Ground Defense - Turret
Ground-based defensive structure:
- Cost: $10
- HP: 5
- Attack: 1 damage to ground units within 2-cell range
- Behavior: Automatically targets and fires at enemy ground units each turn
- Cannot move, cannot attack structures or missiles

**Test:** `test_turret.gd`
- [ ] Turret attacks ground units in range
- [ ] Turret ignores missiles and structures
- [ ] Turret fires once per turn
- [ ] Turret prioritizes closest enemy

### Step 8.6: Mobile Ground Defense - Patrol Unit
Mobile defensive ground unit:
- Cost: $15
- HP: 4
- Attack: 1 damage to adjacent ground units
- Movement: 1 cell per turn
- Behavior: Patrols between two points OR pursues nearest enemy ground unit
- Mode toggle: Patrol vs. Pursue (set during placement)

**Test:** `test_patrol_unit.gd`
- [ ] Patrol unit moves along patrol path
- [ ] Patrol unit switches to pursuit when enemy detected
- [ ] Patrol unit attacks adjacent enemies
- [ ] Patrol unit returns to patrol after enemy eliminated

### Step 8.7: Ground Combat Resolution
Integrate ground combat into FIGHT phase:
1. Missiles fire and resolve (existing system)
2. Transports travel (can be intercepted)
3. Surviving transports deploy units
4. Ground units act in initiative order:
   - All ground units move simultaneously
   - All ground units attack simultaneously
   - Resolve damage after all attacks
5. Repeat ground unit phase until:
   - All attacking ground units destroyed, OR
   - All defending ground units destroyed AND attackers reach targets

**Test:** `test_ground_combat_flow.gd`
- [ ] Ground phase occurs after missile phase
- [ ] Units move before attacking
- [ ] Damage resolves after all attacks
- [ ] Ground combat ends correctly

### Step 8.8: Transport Loading UI
Allow player to load units into transports:
- Select transport during PLACEMENT phase
- Choose units to load (up to capacity)
- Visual indicator showing transport contents
- Cost of loaded units paid on loading

**Test:** `test_transport_loading.gd`
- [ ] Player can select transport
- [ ] Player can add units up to capacity
- [ ] Cannot exceed capacity
- [ ] Unit cost deducted on load
- [ ] Units removed from available pool

**[ENGAGE] Checkpoint 8.8:** Load a transport with infantry, send it across. Does the transport journey feel tense? Is it satisfying when units deploy? Does ground combat feel like a meaningful second front?

---

## Phase 9: Balance Refinement [NOT STARTED]

**Goal:** Extensive playtesting to ensure all units are viable and strategies are diverse.

### Balance Philosophy
- No dominant strategy should exist
- Every unit should have a counter
- Economic structures should be risky but rewarding
- Defense should be strong but not impenetrable
- Ground assault should be high-risk high-reward

### Step 9.1: Offense vs. Defense Balance
Test scenarios:
1. All-offense strategy (missiles only)
2. Balanced offense/defense
3. Heavy defense + ground assault
4. Economic boom into late-game dominance

For each scenario, play 5 games and document:
- Win rate
- Average game length
- Turning points
- Frustration moments

**[BALANCE] Checkpoint 9.1:** No single strategy should win >70% of games. If one does, adjust costs or stats.

### Step 9.2: Intercept Chance Tuning
Current: 50% base + 5% per radar

Test variations:
- 40% base + 10% per radar (radar more valuable)
- 60% base + 3% per radar (radar less critical)
- Cap at 80% or 90%?

**[BALANCE] Checkpoint 9.2:** Defense should feel meaningful but not frustrating. Adjust until missiles feel threatening but not unstoppable.

### Step 9.3: Ground Unit Balance
Test ground-only strategies:
- Mass infantry rush
- Demolition strike team
- Mixed ground force

Vs. ground defense:
- Turret wall
- Mobile patrol network
- Mixed defense

**[BALANCE] Checkpoint 9.3:** Ground assault should be viable but counterable. Transport loss should be painful but not game-ending.

### Step 9.4: Economic Balance
Test economic strategies:
- Early Lemonade Stand rush
- Salad Bar healing efficiency
- Income vs. direct combat spending

**[BALANCE] Checkpoint 9.4:** Economic structures should be worth protecting. Ignoring economy should be a valid aggressive strategy.

### Step 9.5: Radar Jammer Balance
Test jammer effectiveness:
- Single jammer impact
- Multi-jammer saturation
- Recovery from jam (3 turn duration)

**[BALANCE] Checkpoint 9.5:** Jammers should create windows of opportunity but not guarantee success.

### Step 9.6: Health and Damage Balance
All structures: 5 HP
All missiles: 1 damage, 3x3 area

Test variations:
- Higher HP structures (7-10)?
- Variable damage by weapon type?
- Smaller/larger area effects?

**[BALANCE] Checkpoint 9.6:** Battles should last multiple turns. One-shot kills should be rare. Attrition should matter.

### Step 9.7: Cost Tuning
Review all costs relative to effectiveness:

| Unit | Current Cost | Effectiveness Notes |
|------|--------------|---------------------|
| Hot Dog Cannon | $5 | Basic offense |
| Condiment Cannon | $5 | Same as Hot Dog? Differentiate? |
| Condiment Station | $10 | Worth 2x basic? |
| Pickle Interceptor | $5 | Defensive value |
| Coffee Radar | $10 | Intercept bonus value |
| Veggie Cannon | $5 | Defensive value |
| Lemonade Stand | $20 | Income ROI (4 turns to profit) |
| Salad Bar | $20 | Healing value |
| Radar Jammer | $15 | Anti-defense value |
| Transport | $25 | Ground assault value |
| Infantry | $5 | Ground offense |
| Demolition | $10 | Burst damage value |
| Turret | $10 | Ground defense |
| Patrol | $15 | Mobile defense value |

**[BALANCE] Checkpoint 9.7:** All units should see play in optimal strategies. No unit should be "never buy."

### Step 9.8: Unit Differentiation
Hot Dog Cannon vs Condiment Cannon are currently identical. Options:
1. Different damage patterns (1x1 vs 3x3)
2. Different fire rates (attack priority)
3. Different costs
4. Remove one

**[BALANCE] Checkpoint 9.8:** Every unit should have a unique role. No two units should be interchangeable.

### Step 9.9: Final Balance Pass
After all adjustments, play 20 games using varied strategies:
- Document each game's strategy and outcome
- Identify any remaining dominant strategies
- Identify any unused units
- Make final adjustments

**[BALANCE] Checkpoint 9.9:** Game should feel fair, strategic, and replayable. Multiple viable paths to victory.

---

## Phase 10: AI Opponent [FUTURE - NOT DETAILED]

**Goal:** Enemy side makes autonomous decisions with basic strategy.

*This phase will be detailed after gameplay is locked in.*

### Planned Components
- AI Structure Placement (strategic base and defense positioning)
- AI Economy Management (purchase decisions)
- AI Target Assignment (prioritization logic)
- AI Ground Combat (transport loading, unit deployment)
- AI Difficulty Levels (easy/medium/hard)

---

## Phase 11: View System [FUTURE - NOT DETAILED]

**Goal:** Implement distinct views for different game phases.

*This phase will be detailed after AI is complete.*

### Planned Views
- **Placement View:** Isometric, player's island only
- **Targeting View:** Top-down grid, both islands visible
- **Execution View:** Isometric, action playback with camera following projectiles/units

---

## Phase 12: Visual Polish [FUTURE - NOT DETAILED]

**Goal:** Upgrade placeholder visuals to food theme.

*This phase will be detailed after view system is complete.*

### Planned Polish
- Structure sprites (food-themed)
- Projectile sprites and trails
- Hit effects and explosions
- Ground unit sprites and animations
- Island and UI theming
- Sound effects and music

---

## Current Game State Summary

### What Works
- 8x8 grids for both islands
- Base placement phase (3 bases each)
- Structure placement with economy ($30 starting money)
- Targeting system with fog of war
- Turn execution with missiles
- Interception system (50% + 5% per radar)
- Radar jamming (3 turn duration)
- Area damage (3x3 for all missiles)
- Win/lose detection
- Dev toolbar (fog toggle, restart)
- Left-side toolbar with info panel

### What's Next
- Ground combat system (Phase 8)
- Balance refinement (Phase 9)

---

## Running Tests

### All Unit Tests
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

### Specific Test File
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_game_manager.gd -gexit
```

### In-Editor
1. Open `test/gut_runner.tscn`
2. Run scene (F6)
3. Click "Run All" or select specific tests

---

## Notes for Claude Code Sessions

- Complete one step before moving to the next
- Run relevant GUT tests after each step
- At `[ENGAGE]` checkpoints, pause for manual playtesting
- At `[BALANCE]` checkpoints, play multiple games and document findings
- If engagement or balance fails at a checkpoint, iterate before proceeding
- Commit working code after each successful step/phase
- Keep `balance-notes.md` updated with playtest findings
- Focus on gameplay feel before visual polish
