# Food Fight Island - Stage Two Development Roadmap

This document continues development from the completed prototype (Phases 0-8) into refinement focused on making the game fun, strategic, and thematically cohesive.

---

## Completed Work Summary (Phases 0-8)

### Phase 0-1: Foundation & Grid
- Project structure with GUT testing framework
- GameManager singleton tracking phases: BASE_PLACEMENT → PLACEMENT → TARGETING → FIGHT → GAME_OVER
- 8x8 clickable grid with cell states (EMPTY, OCCUPIED, BLOCKED)
- Mouse hover/click feedback

### Phase 2-3: Placement & Targeting
- Structure base class with health, damage, and special properties
- Placement validation and ghost preview
- Two-island layout (player left, enemy right, canal between)
- Targeting system with visual lines
- Fog of war (revealed by missiles, persists between turns)

### Phase 4: Turn Execution
- Execution queue sorted by attack priority
- Projectile travel animation
- Hit resolution with area damage (3x3 for missiles)
- Structure destruction at 0 HP

### Phase 5: Arsenal & Economy
- Player starts with $30
- $5 earned per HP damage dealt
- 3 bases per side (free), lose all 3 = game over

**Current Structure Stats:**

| Structure | Cost | HP | Function |
|-----------|------|-----|----------|
| Base | Free | 5 | Lose all 3 = lose game |
| Hot Dog Cannon | $5 | 5 | Offensive, 1 dmg, 3x3 area |
| Condiment Cannon | $5 | 5 | Offensive, 1 dmg, 3x3 area |
| Condiment Station | $10 | 5 | Offensive, 1 dmg, 3x3 area |
| Pickle Interceptor | $5 | 5 | Defensive, requires radar |
| Coffee Radar | $10 | 5 | 20-block detection, +5% intercept |
| Veggie Cannon | $5 | 5 | Defensive, requires radar |
| Lemonade Stand | $20 | 5 | $5 passive income/turn |
| Salad Bar | $20 | 5 | Heals 1 HP/turn in 3x3 |
| Radar Jammer | $15 | 5 | Jams radar 3 turns, uninterceptable |

### Phase 6-7: Defense & Win/Lose
- Interception: 50% base + 5% per active radar
- Intercept point at 70% of missile path
- Radar jamming disables radar for 3 turns
- Game over detection and restart flow

### Phase 8: Ground Combat (Completed)

**Transport ($25, 5 HP)**
- Capacity: 3 ground units
- Loaded during PLACEMENT, targeted during TARGETING
- 10% interception chance (harder to hit than missiles)
- Must land on empty cell

**Turret ($10, 5 HP)**
- Range: 2 cells
- Auto-attacks enemy ground units in range
- Stationary defense

**Ground Units:**

| Unit | Cost | HP | Damage | Speed | Behavior |
|------|------|-----|--------|-------|----------|
| Infantry | $5 | 3 | 1 | 1/turn | Attacks structures; priority: Radar > Defensive > Offensive > Economic > Base |
| Demolition | $10 | 2 | 3 | 2/turn | Suicide attack; priority: Base > Radar > Economic |
| Patrol | $15 | 4 | 1 | 1/turn | Targets enemy ground units, not structures |

**Operation Range:** Units operate within 7x7 area (3 cells any direction) from landing site. Units return to transport when no valid targets in range. Surviving units persist for next turn.

**Ground Combat Flow:**
1. Missiles fire (existing)
2. Transports travel (can be intercepted at 10%)
3. Surviving transports deploy at landing zone
4. Turrets fire at ground units in range
5. All units move toward targets
6. All units attack adjacent targets
7. Damage resolves
8. Repeat until ground combat ends

---

## Stage Two: Making It Fun

### Design Goals
- **3-5 minute matches** at small scale (current 8x8)
- **Decisions matter** more than dice rolls
- **Thematic coherence** — food behaviors make intuitive sense
- **Asymmetric situations solvable** with clever play

### Key Problems to Solve
1. Things are too hard to kill → battles drag, outcomes feel random
2. No resource tension → fire everything every turn, no interesting choices
3. Viewport too zoomed out → can't read positions, targeting is cluttered
4. Enemy is predictable → success feels like luck not skill

---

## Phase 9: Lethality & Weapon Identity

**Goal:** Make weapons feel impactful. Structures should die in 1-2 hits from appropriate weapons. Each weapon should have a distinct role.

### 9.1: Health Rebalance

Reduce HP across the board so engagements resolve faster:

| Structure | Old HP | New HP | Rationale |
|-----------|--------|--------|-----------|
| Base | 5 | 4 | Still tanky, but killable |
| Offensive weapons | 5 | 2 | Glass cannons — hit hard, die fast |
| Defensive weapons | 5 | 3 | Slightly tougher |
| Economic/Support | 5 | 2 | High value targets, fragile |
| Transport | 5 | 3 | Meaningful to lose |
| Turret | 5 | 3 | Can survive a hit |

Ground units stay as-is (already lower HP).

### 9.2: Damage & Area Differentiation

Currently all missiles do 1 damage to 3x3 area. Differentiate:

| Weapon | Damage | Area | New Behavior |
|--------|--------|------|--------------|
| Hot Dog Cannon | 2 | 1x1 | Precision strike, cheap |
| Condiment Cannon | 1 | 3x3 | Area denial, splash |
| Condiment Station | 2 | 2x2 | Balanced, more expensive |
| Radar Jammer | 0 | 1x1 | Jams only, no damage |

**Thematic logic:**
- Hot dogs are solid, dense — they punch through one target
- Condiments (ketchup, mustard) splatter — wide but thin damage
- Condiment Station is a concentrated burst — more damage, moderate spread

### 9.3: Weapon Weaknesses (Food Logic)

Introduce vulnerability types that create soft counters:

| Weapon Type | Strong Against | Weak Against | Food Logic |
|-------------|---------------|--------------|------------|
| Hot Dog (solid) | Single targets | Interceptors | Dense, easy to track and swat |
| Condiment (liquid) | Clusters | Spread-out targets | Splatters, but dilutes over area |
| Veggie (healthy) | Ground units | — | Nutritious defense |
| Coffee (hot) | Detection | Radar Jammer | Alertness, but can be "put to sleep" |

**Implementation option:** Hot Dogs have +10% intercept chance against them (easy to hit). Condiments have -10% (harder to intercept splatter).

### 9.4: Targeting UX Fix

- Show only active weapon's targeting arrow during TARGETING phase
- Other assigned weapons show small indicator dot
- "Review All" button temporarily shows all arrows
- Clear visual feedback for valid/invalid targets

**[ENGAGE] Checkpoint 9.4:** Does targeting feel cleaner? Can you quickly assign targets without visual overload?

### 9.5: Playtest & Tune

Play 5 matches with new lethality. Document:
- Average turns to destroy a structure
- Does the attacker or defender feel advantaged?
- Are any weapons now useless or overpowered?

**[BALANCE] Checkpoint 9.5:** Structures should die in 1-2 hits from appropriate counters. Matches should feel faster and more decisive.

---

## Phase 10: Energy System

**Goal:** Introduce a second resource (Energy) that gates actions per turn, forcing meaningful choices about what to power.

### 10.1: Energy Concept

**Thematic framing:** "Kitchen Power" — you need heat/power to cook and launch food.

- Energy is generated per turn by power structures
- Energy is consumed when weapons fire or defenses activate
- If you don't have enough energy, some things don't work this turn
- Energy does NOT accumulate — use it or lose it each turn

This creates the core tension: you can BUILD more than you can POWER. So you must choose what matters this turn.

### 10.2: Energy Generation

| Structure | Energy/Turn | Notes |
|-----------|-------------|-------|
| Base | +2 | Each base provides baseline power |
| Lemonade Stand | +3 | Now generates energy AND $3/turn (reduced from $5) |
| *New: Generator* | +5 | Dedicated power structure, see 10.3 |

Starting energy per turn (3 bases): 6 energy

### 10.3: New Structure — Food Truck Generator

| Stat | Value |
|------|-------|
| Cost | $15 |
| HP | 2 |
| Energy | +5/turn |
| Notes | High value target, fragile |

**Thematic logic:** Food truck powers the kitchen. Destroy the enemy's generators to cripple their offense.

### 10.4: Energy Costs

| Action | Energy Cost | Notes |
|--------|-------------|-------|
| Hot Dog Cannon fire | 2 | Cheap, spammable |
| Condiment Cannon fire | 2 | Same as hot dog |
| Condiment Station fire | 4 | Premium weapon |
| Radar Jammer fire | 3 | Tactical strike |
| Transport launch | 4 | Significant investment |
| Pickle Interceptor (per intercept attempt) | 1 | Defense has ongoing cost |
| Veggie Cannon (per intercept attempt) | 1 | Defense has ongoing cost |
| Coffee Radar (passive) | 1 | Must be powered to give bonus |
| Turret (per attack) | 1 | Ground defense costs |

### 10.5: Energy UI

- Display current energy and energy/turn on HUD
- During TARGETING, show running total of energy committed
- Weapons that can't be powered this turn are grayed out
- Warning if committing more energy than available (partial execution)

### 10.6: Partial Execution Rules

If player commits more energy than available:
- Weapons fire in priority order until energy runs out
- Remaining weapons do not fire (but keep their targets for next turn)
- Player is warned during TARGETING phase

This lets players "queue up" attacks but forces prioritization.

### 10.7: Enemy Energy

Enemy also has energy constraints:
- Enemy generates energy from their bases and generators
- Enemy AI must choose what to power each turn
- Destroying enemy generators weakens their offense/defense

### 10.8: Playtest & Tune

Play 5 matches with energy system. Document:
- How often do you run out of energy?
- Does it feel like a meaningful constraint or just annoying?
- Is generator a high-priority target?

**[BALANCE] Checkpoint 10.8:** Players should sometimes have to choose between offense and defense. Energy should feel tight but not crippling.

### 10.9: Energy Balance Tuning

Adjust if needed:
- If energy feels too tight: increase base generation or reduce costs
- If energy feels irrelevant: reduce generation or increase costs
- Target: players should power 60-80% of their structures each turn

---

## Phase 11: Viewport & Camera

**Goal:** Create distinct visual modes for different phases that improve clarity and feel.

### 11.1: Design Intent

| Phase | View | Shows | Feel |
|-------|------|-------|------|
| BASE_PLACEMENT | Isometric | Player island only | Building your home |
| PLACEMENT | Isometric | Player island only | Preparing for battle |
| TARGETING | Top-down grid | Both islands | Strategic planning |
| FIGHT | Isometric | Action-focused | Dramatic payoff |

### 11.2: Isometric Placement View

- Camera shows only player island
- Larger cells, more detail visible
- Structure placement feels more tactile
- No need to see enemy during building phase

**Implementation notes:**
- Island fills most of viewport
- Grid cells are larger (more pixels per cell)
- Isometric angle ~30° (standard iso)
- Simple sprites acceptable for now (polish later)

### 11.3: Top-Down Targeting View

- Camera pulls back to show both islands
- Grid-based, clear cell boundaries
- Range indicators for selected weapons
- Fog of war visible on enemy island
- Targeting lines are clean and readable (one at a time per 9.4)

**Implementation notes:**
- This is closest to current view
- May need to zoom out slightly
- Clear visual separation between islands (canal)

### 11.4: Isometric Fight View

- Returns to isometric during FIGHT phase
- Camera can pan to follow action (optional)
- Projectiles travel across the gap
- Explosions and destruction visible
- Ground combat plays out visibly

**Implementation notes:**
- Start simple: just switch to iso view
- Camera following projectiles is stretch goal
- Focus on making hits feel impactful

### 11.5: View Transitions

- Smooth transition between views (0.5s fade or slide)
- Audio cue for phase changes
- Clear UI indication of current phase

### 11.6: Island Shape Exploration

Now that viewport is tighter, island shape matters more:

**Option A: Simple shapes**
```
████████    ██████
████████    ████████
████████    ████████
████████    ████████
```

**Option B: Irregular coastlines**
```
░░██████    ██████░░
████████    ████████
██████░░    ░░██████
████████    ████████
```

**Option C: Terrain features**
```
████████    ████████
███░░███    ███░░███
████████    ████████
████████    ████████
```
(░░ = blocked/mountain cells)

Start with Option A for simplicity. Terrain features can add strategic depth later.

### 11.7: Playtest & Tune

Play 5 matches with new viewport system. Document:
- Does isometric feel better for placement?
- Is top-down clear for targeting?
- Do view transitions feel smooth or jarring?

**[ENGAGE] Checkpoint 11.7:** Each phase should feel distinct. Placement should feel cozy, targeting should feel strategic, fight should feel dramatic.

---

## Phase 12: Enemy Behavior (Sketch)

**Goal:** Make the enemy feel like an opponent, not a random number generator.

*Detailed implementation deferred until core loop is fun.*

### Planned Improvements

**Target Selection:**
- Prioritize damaged structures (finish kills)
- Prioritize radar when attacking defense
- Prioritize generators when energy system is in play

**Adaptive Strategy:**
- If player has strong defense → build more offense or use jammers
- If player has weak defense → press the attack
- If player has generators → target them

**Personality Variants:**
- Aggressive: all offense, minimal defense
- Turtle: heavy defense, slow methodical offense  
- Balanced: adapts to player behavior

**Energy Management:**
- Enemy must also work within energy constraints
- Creates moments where enemy defense is down (opportunity windows)

---

## Phase 13: Campaign Mode & Progression

**Goal:** Create a framework for multi-level progression where the game starts simple and grows in complexity across scenarios.

### 13.1: Campaign Framework

**Core concept:** Instead of jumping straight into a full match, players progress through a campaign of increasingly challenging scenarios. Each level introduces new elements while teaching mechanics organically.

**Initial structure:** 3 levels to start, expandable later.

| Level | Name | Player Setup | Enemy Advantage | New Mechanics Introduced |
|-------|------|--------------|-----------------|--------------------------|
| 1 | First Bite | 2 bases, $100, basic weapons only | 1 base, limited offense | Basic targeting & combat |
| 2 | Heating Up | 2 bases, $125, unlock interceptors | 2 bases, adds radar + defense | Interception & fog of war |
| 3 | Full Kitchen | 3 bases, $150, all structures | 4 bases, 2 generators, full arsenal | Energy management & ground combat |

### 13.2: Level Selection UI

- Campaign screen with level buttons (locked/unlocked)
- Level preview showing enemy setup
- Victory unlocks next level
- Quick Play option bypasses campaign (current behavior)

### 13.3: Level Configuration System

Each level defined by:
- Player starting resources (bases, money, energy)
- Available structure types (some locked in early levels)
- Enemy setup (bases, structures, generators)
- Grid size (smaller grids for early levels)
- Victory conditions (standard: destroy all enemy bases)

**Implementation notes:**
- Level data stored in resource files or dictionary
- LevelManager singleton to track progression
- Save/load campaign progress locally

### 13.4: Enemy Scaling

As levels progress, enemy gains advantages:

| Factor | Level 1 | Level 2 | Level 3 |
|--------|---------|---------|---------|
| Base count | 1 | 2 | 4 |
| Generators | 0 | 0 | 2 |
| Starting structures | 1 cannon | 2 cannons + radar | Full defensive setup |
| AI aggression | Low | Medium | High |

### 13.5: Progression Rewards (Future)

*Deferred for later phases, but design space includes:*
- Unlock new structure types through campaign
- Cosmetic unlocks (different food themes)
- Challenge modes (limited resources, time pressure)

### 13.6: Playtest & Tune

Play through all 3 levels. Document:
- Does difficulty curve feel appropriate?
- Are mechanics introduced at the right pace?
- Is Level 3 a satisfying challenge after learning in 1-2?

**[ENGAGE] Checkpoint 13.6:** Each level should feel like a step up, not a wall. Players should feel prepared for complexity.

---

## Phase 14: Final Balance Pass (Sketch)

*Deferred until Phases 9-11 are complete and playtested.*

### Areas to Revisit
- Cost vs effectiveness for all structures
- Energy costs vs generation rates
- Intercept chances
- Ground combat balance
- Match length (target: 3-5 minutes)

### Success Criteria
- No dominant strategy wins >60% of games
- Multiple viable paths to victory
- Every structure sees play in optimal strategies
- Matches feel decided by skill, not luck

---

## Implementation Order

1. **Phase 9: Lethality** — Fast to implement, immediate feel improvement
2. **Phase 10: Energy** — Biggest strategic impact, requires UI work
3. **Phase 11: Viewport** — Most complex, but builds on solid game loop
4. **Phase 12: Enemy Behavior** — Makes AI feel like a real opponent
5. **Phase 13: Campaign Mode** — Adds progression framework with 3 initial levels
6. **Phase 14: Final Balance** — Polish and balance once core is fun

### Per-Phase Workflow

For each phase:
1. Implement changes
2. Run GUT tests (if applicable)
3. Playtest 3-5 matches
4. Document findings
5. Iterate if needed
6. Move to next phase only when checkpoint passes

---

## Food Theme Reference

### Offensive Weapons (Things That Fly)

| Food | Behavior | Strength | Weakness |
|------|----------|----------|----------|
| Hot Dog | Dense, fast, precise | Single target damage | Easy to intercept (predictable arc) |
| Condiment | Splatters on impact | Area coverage | Damage spread thin |
| (Future) Pizza Slice | Glides, medium speed | Balanced | Average at everything |
| (Future) Meatball | Heavy, slow, devastating | High damage | Very easy to intercept |

### Defensive Weapons (Things That Block)

| Food | Behavior | Strength | Weakness |
|------|----------|----------|----------|
| Pickle | Sour, snappy interception | Reliable defense | Requires radar |
| Veggie | Healthy, resilient | Cheaper defense | Lower intercept rate |
| (Future) Cheese Wall | Melts to absorb hits | Passive defense | One-time use |

### Support Structures

| Food | Behavior | Function |
|------|----------|----------|
| Coffee | Hot, alert | Radar/detection |
| Lemonade | Refreshing | Income + energy |
| Salad Bar | Nutritious | Healing |
| Food Truck | Mobile kitchen | Energy generation |

### Ground Units

| Food | Behavior | Role |
|------|----------|------|
| Infantry | Fork soldiers | Basic attack |
| Demolition | Exploding pepper | Burst damage, suicide |
| Patrol | Spoon guards | Anti-ground defense |

---

## Notes for Claude Code Sessions

- Complete one step before moving to next
- Run GUT tests after each implementation step
- At [ENGAGE] checkpoints, playtest for feel
- At [BALANCE] checkpoints, playtest multiple matches and document
- If checkpoint fails, iterate before proceeding
- Keep this document updated with findings
- Prioritize fun over features — skip ahead if something isn't working