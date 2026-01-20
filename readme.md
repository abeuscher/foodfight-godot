# Food Fight

A single-player 2D turn-based strategy game prototype inspired by Metal Marines (SNES). You command an island facing off against an AI opponent across a canal, each side trying to destroy the other's headquarters using food-themed weaponry.

**Engine:** Godot 4.x

## Concept

You place offensive and defensive structures on your island's grid, then program your attacks by assigning targets. Once you end your turn, both sides' weapons fire automatically in priority order. Victory requires balancing defensive installations to protect your headquarters while deploying offensive strikes to destroy the enemy's.

## Prototype Goals

The prototype aims to establish the core gameplay loop with minimal complexity:

1. **Two-island battlefield** - A static 2D map showing your island and the AI opponent's island separated by a canal, each with a grid for structure placement
2. **Turn programming** - Place structures and assign targets before ending your turn
3. **Automatic battle resolution** - All actions resolve based on attack priority, with destroyed structures unable to act later in the turn
4. **Win/lose condition** - Destroy the enemy headquarters or lose your own

## Development Philosophy

**The only success metric for this prototype is engagement.**

The goal is modular success: each piece of the game should be satisfying at its own level before building upward. If placing a weapon on the grid doesn't feel good, adding more weapon types won't help. If watching your missile fly toward a target isn't exciting, no amount of visual polish will fix it.

Priorities:

1. **Cellular engagement first** - The smallest interactions must be fun. Placing a structure, selecting a target, watching a projectile resolve. If these atomic actions aren't engaging, the game loop won't be either.

2. **Iterate on the loop before expanding scope** - Resist adding features until the core turn cycle (plan → execute → observe results) feels satisfying. Spend time here.

3. **Fun is the gate** - No feature moves forward unless the foundation is engaging. A working-but-boring prototype is a failed prototype.

This philosophy means development may involve significant time tuning the basics: timing, feedback, visual weight, the rhythm of a turn. That's not wasted time - that's the actual work.

## Core Mechanics (Prototype Scope)

### Turn Structure

Each round consists of two phases:

**1. Planning Phase (player only)**
- Place new structures on your island grid (if available)
- Aim offensive weapons at enemy targets
- End turn when ready

The AI opponent makes its own placement and targeting decisions behind the scenes.

**2. Execution Phase (automatic)**
- All weapons from both sides fire in attack priority order (highest first)
- Defensive structures intercept incoming missiles (if still operational)
- Destroyed structures are removed immediately and cannot act later in the turn
- Damage is tallied and the board state updates

This "program then watch" model means a well-aimed early strike on enemy defenses can open the door for lower-priority missiles to get through.

### Structures

**Offensive:**
- **Condiment Cannon** - Basic missile launcher, targets a single enemy grid cell

**Defensive:**
- **Pickle Interceptor** - Launches seeker projectiles that target incoming missiles within range

**Critical:**
- **Headquarters** - Must be protected; destruction means defeat

Each structure has an **attack priority** stat that determines firing order during execution.

### AI Opponent

The prototype AI is intentionally simple:
- Places structures in valid random positions
- Targets player structures randomly
- No strategic decision-making (that's a future enhancement)

### Prototype Simplifications

- Fixed starting structures (no economy/build queue yet)
- Single offensive weapon type
- Single defensive weapon type (seeker-based)
- Simple random AI
- Minimal animation (projectile paths, hit/miss feedback)
- Static terrain

## Food Theme (Visual Only for Prototype)

- Islands as dinner plates or cutting boards
- Missiles as flying hot dogs, pizza slices, etc.
- Explosions as sauce splatters
- Defensive turrets as condiment bottles

## Success Criteria for Prototype

The prototype is complete when:

- [ ] Grid-based placement works on the player's island
- [ ] Player can assign targets to offensive structures
- [ ] AI opponent places structures and assigns targets
- [ ] Turn execution resolves all actions in priority order
- [ ] Defensive structures intercept missiles (or fail to, if destroyed first)
- [ ] Destroyed structures are removed and cannot act
- [ ] Game ends when either HQ is destroyed
- [ ] Basic visual feedback for projectiles and hits

## Future Considerations (Out of Scope for Prototype)

- Resource/economy system for building new structures
- Multiple weapon types with different priorities and behaviors
- Area-denial defensive structures (alternative to seekers)
- Range/frequency upgrade buildings (tower defense influence)
- Smarter AI with strategic targeting
- Destructible terrain
- Campaign/mission structure
- Sound and music
