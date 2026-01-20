# Food Fight Island - Development Roadmap

This document outlines the phased development plan for the prototype, designed for incremental implementation with Claude Code. Each phase builds on the previous, with automated GUT tests validating logic and manual engagement checks validating feel.

---

## Testing Strategy

### Automated Testing (GUT Framework)
Each step that generates new code includes GUT unit tests to verify correctness. Tests live in `res://test/unit/` and can be run via:
- In-editor: Run the `test/gut_runner.tscn` scene
- Command line: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit`

### Engagement Checkpoints
Marked with `[ENGAGE]` - these require running the game and manually verifying the interaction *feels* satisfying. Per the readme philosophy: if it doesn't feel good, we iterate before moving forward.

---

## Phase 0: Project Foundation

**Goal:** Establish project structure, testing infrastructure, and baseline scene.

### Step 0.1: Directory Structure
Create the folder hierarchy:
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

**Test:** Directory structure exists, GUT addon installed.

### Step 0.2: GUT Installation & Configuration
- Install GUT addon (v9.x for Godot 4)
- Create `test/gut_runner.tscn` for running tests
- Create a sample test to verify framework works

**Test:** Run `test_example.gd` - should pass with green output.

### Step 0.3: Game Manager Autoload
Create `GameManager` singleton to track:
- Current game state (PLANNING, EXECUTING, GAME_OVER)
- Turn counter
- Win/lose status

**Test:** `test_game_manager.gd`
- [ ] State transitions work correctly
- [ ] Turn counter increments
- [ ] Win/lose flags set properly

---

## Phase 1: The Grid (Foundational Interaction)

**Goal:** A clickable grid that responds to input. This is the atomic interaction everything else builds on.

### Step 1.1: Grid Data Structure
Create `IslandGrid` class:
- 2D array representing cells
- Cell states: EMPTY, OCCUPIED, BLOCKED
- Methods: `get_cell()`, `set_cell()`, `is_valid_position()`

**Test:** `test_island_grid.gd`
- [ ] Grid initializes with correct dimensions
- [ ] get/set cell works
- [ ] is_valid_position returns correct values
- [ ] Out-of-bounds access handled gracefully

### Step 1.2: Grid Visualization
Create `IslandGridView` scene:
- Draws grid lines
- Renders cell backgrounds based on state
- Configurable cell size and grid dimensions

**Test:** `test_island_grid_view.gd`
- [ ] Grid renders with correct number of cells
- [ ] Cell size matches configuration
- [ ] Grid updates when data changes

### Step 1.3: Grid Input Handling
Add to `IslandGridView`:
- Mouse hover highlights current cell
- Click emits `cell_clicked(grid_pos)` signal
- Visual feedback on hover/click

**Test:** `test_grid_input.gd`
- [ ] Mouse position converts to correct grid coordinates
- [ ] Signal emits with correct position
- [ ] Invalid positions (outside grid) ignored

**[ENGAGE] Checkpoint 1.3:** Run the game with just the grid. Does clicking cells feel responsive? Is the hover feedback satisfying? Adjust timing/colors until it feels good.

---

## Phase 2: Structure Placement (First Real Interaction)

**Goal:** Player can place structures on the grid with satisfying feedback.

### Step 2.1: Structure Base Class
Create `Structure` resource/class:
- Properties: `structure_type`, `attack_priority`, `health`, `grid_position`
- Types enum: HQ, CONDIMENT_CANNON, PICKLE_INTERCEPTOR

**Test:** `test_structure.gd`
- [ ] Structure initializes with correct defaults
- [ ] Properties are readable/writable
- [ ] Attack priority ordering works

### Step 2.2: Structure Scenes
Create scenes for each structure type:
- `headquarters.tscn`
- `condiment_cannon.tscn`
- `pickle_interceptor.tscn`

Each has:
- Sprite placeholder (colored rectangle for now)
- Structure script attached

**Test:** `test_structure_scenes.gd`
- [ ] Each scene instantiates without error
- [ ] Structure data accessible from scene

### Step 2.3: Placement System
Create `PlacementManager`:
- Tracks currently selected structure type (for placing)
- Validates placement (cell empty, within bounds)
- Places structure on grid and updates grid data
- Emits `structure_placed(structure, position)` signal

**Test:** `test_placement_manager.gd`
- [ ] Cannot place on occupied cell
- [ ] Cannot place outside grid
- [ ] Placement updates grid state
- [ ] Signal emits correctly

### Step 2.4: Placement Visuals & Feedback
- Ghost preview of structure follows cursor when placing
- Invalid positions show red tint
- Placement has visual/audio pop (even placeholder sound)

**Test:** `test_placement_visuals.gd`
- [ ] Preview appears when placement mode active
- [ ] Preview position updates with mouse
- [ ] Invalid indicator shows correctly

**[ENGAGE] Checkpoint 2.4:** Place several structures. Does the ghost preview feel right? Is there enough feedback on successful placement? Does invalid placement communicate clearly? Iterate until placing structures is satisfying.

---

## Phase 3: Target Assignment

**Goal:** Player can aim offensive structures at enemy positions.

### Step 3.1: Two-Island Map Layout
Create main game scene with:
- Player island (left)
- Enemy island (right)
- Canal/gap between them
- Camera showing both

**Test:** `test_map_layout.gd`
- [ ] Both grids instantiate
- [ ] Grids positioned correctly relative to each other
- [ ] Camera encompasses both islands

### Step 3.2: Targeting System
Create `TargetingManager`:
- Select an offensive structure
- Click enemy grid to assign target
- Store target assignments: `Dictionary[Structure, Vector2i]`
- Visual line/indicator showing current target

**Test:** `test_targeting_manager.gd`
- [ ] Only offensive structures can be selected for targeting
- [ ] Target must be valid enemy grid position
- [ ] Target assignment stored correctly
- [ ] Can reassign target

### Step 3.3: Targeting UI
- Click own offensive structure to select it
- Selected structure highlighted
- Click enemy cell to assign target
- Line drawn from structure to target
- Right-click or ESC to deselect

**Test:** `test_targeting_ui.gd`
- [ ] Selection highlight visible
- [ ] Target line renders correctly
- [ ] Deselection clears visuals

**[ENGAGE] Checkpoint 3.3:** Select a cannon and assign targets. Does the selection feel clear? Is the targeting line satisfying? Does the flow of select-then-target feel natural?

---

## Phase 4: Turn Execution (The Payoff)

**Goal:** Watch your programmed attacks resolve. This is the core "program then watch" satisfaction.

### Step 4.1: End Turn Button & State Transition
- UI button to end planning phase
- Transitions GameManager to EXECUTING state
- Locks player input during execution

**Test:** `test_turn_flow.gd`
- [ ] Button triggers state change
- [ ] Input disabled during execution
- [ ] State returns to PLANNING after execution

### Step 4.2: Execution Queue
Create `ExecutionManager`:
- Collects all structures with targets (both sides)
- Sorts by attack priority (highest first)
- Processes queue sequentially

**Test:** `test_execution_queue.gd`
- [ ] Structures sorted by priority correctly
- [ ] Higher priority executes first
- [ ] Destroyed structures removed from queue

### Step 4.3: Projectile System
Create `Projectile` scene:
- Travels from source to target position
- Configurable speed
- Emits `arrived(target_pos)` signal

**Test:** `test_projectile.gd`
- [ ] Projectile moves toward target
- [ ] Signal emits on arrival
- [ ] Projectile removed after arrival

### Step 4.4: Hit Resolution
When projectile arrives:
- Check if target cell has structure
- If yes, apply damage
- If structure health <= 0, destroy it
- Visual feedback (hit marker, destruction effect)

**Test:** `test_hit_resolution.gd`
- [ ] Hit on structure deals damage
- [ ] Structure destroyed at 0 health
- [ ] Miss on empty cell handled
- [ ] Destroyed structure removed from grid

### Step 4.5: Execution Pacing
- Delay between each action for readability
- Camera follows action (optional)
- Clear visual separation between attacks

**Test:** `test_execution_pacing.gd`
- [ ] Configurable delay between actions
- [ ] Actions don't overlap

**[ENGAGE] Checkpoint 4.5:** End a turn and watch execution. Is the pacing right? Can you follow what's happening? Is there tension as projectiles fly? Is there satisfaction when they hit? This is the critical engagement moment - iterate heavily here.

---

## Phase 5: Arsenal Expansion

**Goal:** Scale up the battlefield, add economic depth, fog of war, and a diverse arsenal of food-themed weapons and support structures.

### Step 5.1: Larger Grid (32x32)
Expand islands from 6x4 to 32x32:
- Update `IslandGrid` to support configurable dimensions
- Update `IslandGridView` with scrolling/panning or zoom
- Adjust cell size for visibility at larger scale
- Add minimap (optional) for navigation

**Test:** `test_large_grid.gd`
- [ ] 32x32 grid initializes correctly
- [ ] Performance acceptable with 1024 cells
- [ ] Navigation/scrolling works smoothly

### Step 5.2: Economy System
Implement currency mechanics:
- Player starts with $10
- EconomyManager singleton tracks money
- Structures have costs (see structure list below)
- Earning money: $5 per 1 HP damage dealt to enemy
- UI displays current money

**Test:** `test_economy.gd`
- [ ] Starting money is $10
- [ ] Structure purchase deducts money
- [ ] Cannot purchase if insufficient funds
- [ ] Damage dealt awards money correctly

### Step 5.3: Fog of War
Enemy island visibility system:
- Island landmass outline always visible
- Individual cells start hidden (fog)
- Missiles reveal cells as they pass over
- Revealed cells stay visible permanently
- FogManager tracks revealed positions per side

**Test:** `test_fog_of_war.gd`
- [ ] Enemy cells start fogged
- [ ] Missile path reveals cells
- [ ] Revealed cells persist between turns
- [ ] Player island not fogged for player

### Step 5.4: Multiple Bases
Replace single HQ with 3 bases:
- Each player places 3 bases (free cost)
- Game ends when ALL 3 bases destroyed for either side
- Bases have moderate health (3 HP each)
- Update win/lose detection for multi-base logic

**Test:** `test_multi_base.gd`
- [ ] Each player has 3 bases
- [ ] Game continues if 1-2 bases destroyed
- [ ] Game ends when all 3 bases destroyed
- [ ] Correct winner determined

### Step 5.5: Structure - Hot Dog Cannon
Offensive weapon ($5):
- Single projectile, hits one square for 1 HP
- Upgradable: Double Dog ($5), Triple Dog Dare ($5)
- Upgrades add additional projectiles
- Reveals fog along projectile path

**Test:** `test_hot_dog_cannon.gd`
- [ ] Base cannon fires single projectile
- [ ] Upgrade increases projectile count
- [ ] Each projectile deals 1 HP damage
- [ ] Path reveals fog cells

### Step 5.6: Structure - Condiment Station
Area attack weapon ($10):
- Fires mustard blob hitting 3x3 area
- All structures in area take 1 HP damage
- Visual: expanding splash effect

**Test:** `test_condiment_station.gd`
- [ ] Attack hits 3x3 area
- [ ] All structures in area damaged
- [ ] Correct damage amount applied

### Step 5.7: Structure - Coffee Cup Radar
Detection support ($10):
- Detects inbound missiles
- Provides targeting data to nearby Veggie Cannons
- Detection range: configurable radius
- Visual: radar sweep effect during execution

**Test:** `test_radar.gd`
- [ ] Radar detects incoming projectiles in range
- [ ] Detection data available to defensive structures
- [ ] No detection if radar destroyed

### Step 5.8: Structure - Veggie Cannon
Defensive weapon ($5):
- Requires nearby Coffee Cup Radar to function
- Percentage chance to intercept based on:
  - Number of radars in range
  - Upgrade level of Veggie Cannon
- Base intercept: 30% with 1 radar, +20% per additional radar
- Upgradable for better accuracy

**Test:** `test_veggie_cannon.gd`
- [ ] No interception without radar
- [ ] Intercept chance scales with radar count
- [ ] Successful intercept destroys projectile
- [ ] Failed intercept allows projectile through

### Step 5.9: Structure - Lemonade Stand
Economy support ($20):
- Generates $5 per turn
- Upgradable: +$3 per upgrade level
- Passive income during planning phase

**Test:** `test_lemonade_stand.gd`
- [ ] Generates money each turn
- [ ] Upgrade increases generation
- [ ] No generation if destroyed

### Step 5.10: Structure - Salad Bar
Healing support ($20):
- Heals nearby structures each turn
- Heal radius: configurable (default 2 tiles)
- Heal amount: 1 HP per turn to adjacent structures
- Cannot heal self

**Test:** `test_salad_bar.gd`
- [ ] Heals structures in range
- [ ] Does not heal self
- [ ] Respects max health cap
- [ ] No healing if destroyed

### Step 5.11: Structure Registry & UI
Unified structure management:
- StructureRegistry: defines all structure types, costs, stats
- Build menu UI showing available structures with costs
- Greyed out structures if insufficient funds
- Tooltip showing structure details

**Test:** `test_structure_registry.gd`
- [ ] All structures registered with correct stats
- [ ] Cost lookup works
- [ ] UI reflects available funds

**[ENGAGE] Checkpoint 5.11:** Build a diverse base using multiple structure types. Does the economy feel balanced? Is fog of war adding tension? Do the new weapons feel distinct and useful? Can you form strategies around radar + veggie cannon combos?

---

## Phase 6: Defensive Interception (Refinement)

**Goal:** Refine the radar-based interception system, making radar essential for defense and adding tactical depth through detection ranges.

### Core Defensive Behavior
- **Without Radar:** Defensive towers (Veggie Cannon/Pickle Interceptor) do NOTHING - they cannot detect or intercept missiles
- **With Radar:** Defensive towers can intercept missiles that are visible to:
  1. The radar dish itself, OR
  2. Any defensive tower (Veggie Cannon/Pickle Interceptor) that is within the radar's boost range
- **Detection Range:** All units (radar and defensive towers) have a detection/visibility radius of 6 blocks in each direction (13x13 area)
- **Interception Trigger:** When an inbound missile enters the detection range of the radar OR any radar-boosted defensive tower, interception can occur

### Step 6.1: Detection Range System
Implement 6-block detection radius:
- Radar has 6-block detection range (can "see" incoming missiles within 13x13 area centered on radar)
- Defensive towers have 6-block interception range (can intercept missiles within their area)
- Defensive towers only activate when within 6 blocks of a radar (radar boost range)
- Store detection/boost ranges as constants (DETECTION_RANGE = 6)

**Test:** `test_detection_range.gd`
- [ ] Radar detects missiles within 6-block radius
- [ ] Defensive towers within 6 blocks of radar are "boosted"
- [ ] Unboosted defensive towers do not intercept
- [ ] Detection range is consistent regardless of board size

### Step 6.2: Radar-Dependent Interception
Refine interception logic:
- Defensive tower checks: Am I within 6 blocks of any radar?
- If yes, can I see the incoming missile (is it within my 6-block range)?
- If yes, attempt interception
- If no radar nearby, defensive tower is inactive (no interception attempt)

**Test:** `test_radar_dependent_intercept.gd`
- [ ] No interception without radar in range
- [ ] Interception possible when radar + defensive tower positioned correctly
- [ ] Multiple radars can boost same defensive tower
- [ ] Destroying radar disables nearby defensive towers

### Step 6.3: Interception Visual Polish
Enhance interception feedback:
- Radar "ping" visual when detecting incoming
- Veggie Cannon tracking animation before firing
- Clear success/failure indication

**Test:** `test_interception_visuals.gd`
- [ ] Radar shows detection visual
- [ ] Veggie Cannon shows aiming visual
- [ ] Success/failure clearly communicated

### Step 6.4: Multi-Projectile Interception
Handle multiple incoming missiles:
- Each projectile tracked separately
- Veggie Cannon can intercept one projectile per turn
- Multiple Veggie Cannons can intercept multiple projectiles
- Interception priority: closest to impact first

**Test:** `test_multi_projectile_intercept.gd`
- [ ] Each projectile has independent intercept check
- [ ] One Veggie Cannon = one intercept max
- [ ] Remaining projectiles continue to target
- [ ] Closest missiles intercepted first

**[ENGAGE] Checkpoint 6.4:** Set up scenarios with and without radar. Verify defensive towers are useless alone but powerful with radar support. Test detection ranges feel right at 6 blocks.

---

## Phase 7: Win/Lose Conditions

**Goal:** Game ends meaningfully when all bases are destroyed.

### Step 7.1: Multi-Base Destruction Detection
- Track destruction of all 3 bases per side
- Game continues while at least 1 base remains
- Triggers `GameManager.set_winner(side)` when all 3 destroyed
- Transitions to GAME_OVER state

**Test:** `test_win_condition.gd`
- [ ] Player loses when all 3 player bases destroyed
- [ ] Player wins when all 3 enemy bases destroyed
- [ ] Game state transitions to GAME_OVER
- [ ] Partial base destruction does not end game

### Step 7.2: Game Over Screen
- Shows win/lose message
- Displays turn count
- Shows final economy stats (money earned, damage dealt)
- Restart button

**Test:** `test_game_over_screen.gd`
- [ ] Correct message for win/lose
- [ ] Turn count displayed
- [ ] Stats displayed
- [ ] Restart resets game state

**[ENGAGE] Checkpoint 7.2:** Win a game. Lose a game. Does either feel meaningful? Is there satisfaction in victory? Is defeat a clear consequence of your decisions?

---

## Phase 8: AI Opponent

**Goal:** Enemy side makes autonomous decisions with basic strategy.

### Step 8.1: AI Structure Placement
Create `AIController`:
- At game start, places 3 bases strategically (spread out)
- Builds initial offensive/defensive structures within budget
- Prioritizes radar + veggie cannon combos near bases
- Respects grid constraints and economy

**Test:** `test_ai_placement.gd`
- [ ] AI places all 3 bases
- [ ] AI spends starting money on structures
- [ ] No overlapping placements
- [ ] All placements within grid bounds

### Step 8.2: AI Economy Management
- AI earns money from damage like player
- AI decides when to build vs. save
- AI upgrades existing structures when beneficial

**Test:** `test_ai_economy.gd`
- [ ] AI tracks money correctly
- [ ] AI makes purchase decisions
- [ ] AI can upgrade structures

### Step 8.3: AI Target Assignment
- AI prioritizes revealed player structures
- Targets bases when visible
- Spreads attacks to reveal fog
- Targets high-value structures (Lemonade Stands, Radars)

**Test:** `test_ai_targeting.gd`
- [ ] AI targets revealed structures preferentially
- [ ] AI explores fog with some attacks
- [ ] Targeting happens before execution

### Step 8.4: AI Turn Integration
- AI makes decisions instantly (or with brief delay for feel)
- AI decisions made during player planning or at turn start

**Test:** `test_ai_turn_integration.gd`
- [ ] AI ready when player ends turn
- [ ] AI structures participate in execution queue
- [ ] AI can win/lose

**[ENGAGE] Checkpoint 8.4:** Play several turns against the AI. Does it feel like an opponent with a plan? Is there tension not knowing where it will strike? Does AI defense feel threatening?

---

## Phase 9: Visual Polish Pass

**Goal:** Upgrade placeholder visuals to food theme while maintaining engagement.

### Step 9.1: Structure Sprites
Replace placeholder rectangles with food-themed sprites:
- Base: Chef's station or main dish
- Hot Dog Cannon: Hot dog launcher
- Condiment Station: Ketchup/mustard dispenser
- Coffee Cup Radar: Steaming coffee cup with radar dish
- Veggie Cannon: Carrot/celery launcher
- Lemonade Stand: Classic lemonade stand
- Salad Bar: Salad bowl with healing glow

**Test:** Visual inspection - sprites load correctly.

### Step 9.2: Projectile Sprites
- Hot Dog Cannon: Flying hot dogs
- Condiment Station: Mustard blob splash
- Veggie Cannon intercept: Flying vegetables

**Test:** Visual inspection - projectiles render correctly.

### Step 9.3: Hit Effects
- Sauce splatter on impact
- Destruction effect (food explosion)
- Healing effect (green sparkles)
- Money earned effect (floating dollar signs)

**Test:** Visual inspection - effects trigger correctly.

### Step 9.4: Island & UI Theming
- Grid appears as picnic tablecloth or cutting board
- Canal styled as river of soda/juice
- Fog of war as steam/smoke
- Economy UI as cash register display

**Test:** Visual inspection - theme cohesive.

**[ENGAGE] Checkpoint 9.4:** Full playthrough with final visuals. Does the food theme add to engagement or distract? Does it still feel satisfying?

---

## Success Criteria Verification

After all phases, verify the expanded prototype checklist:

### Core Mechanics
- [ ] 32x32 grid-based placement works on both islands
- [ ] Player can assign targets to offensive structures
- [ ] AI opponent places structures and assigns targets strategically
- [ ] Turn execution resolves all actions in priority order

### Economy System
- [ ] Player starts with $10
- [ ] Structures cost money to build
- [ ] $5 earned per HP damage dealt
- [ ] Lemonade Stands generate passive income
- [ ] Cannot build without sufficient funds

### Fog of War
- [ ] Enemy island starts fogged (landmass visible)
- [ ] Missiles reveal cells as they travel
- [ ] Revealed cells stay visible permanently

### Combat & Defense
- [ ] Hot Dog Cannon fires single/multi projectiles based on upgrade
- [ ] Condiment Station hits 3x3 area
- [ ] Coffee Cup Radar detects incoming missiles
- [ ] Veggie Cannon intercepts based on radar proximity (% chance)
- [ ] Salad Bar heals nearby structures

### Win/Lose
- [ ] Each player has 3 bases
- [ ] Game ends when all 3 bases destroyed for one side
- [ ] Correct winner determined

### Visual Feedback
- [ ] Projectile animations clear and readable
- [ ] Interception visuals communicate success/failure
- [ ] Economy changes visible (money earned/spent)
- [ ] Fog reveal feels satisfying

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
- If engagement fails at a checkpoint, iterate on that step before proceeding
- Commit working code after each successful step/phase
