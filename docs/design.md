# Penalty Shootout: design

## Overview
Single-player penalty shootout vs an AI opponent. Best of 5 kicks each, then
sudden death. Player aims and sets power; the keeper dives based on its attributes.

## Sides and control
- Each side has one shooter and one keeper.
- The player controls only their own shots (aim and power).
- The AI controls both keepers and its own shooter.
- Player kicks resolve against the opponent's keeper; AI kicks resolve against
  the player's side keeper.
- AI shots pick aim at random and power from a config-driven range.
- Before every match the player picks one preset shooter and one preset keeper;
  the AI gets the presets the player did not pick.
- Player as keeper is out of scope for v1.

## Rules
- A kick has an aim (left/centre/right x high/low) and a shot power (0-100).
  For the player, shot power is their input.
- The keeper picks a dive column (left/centre/right). Higher reaction = more
  often picks the shot's column.
- Outcome per kick: GOAL, SAVED, MISSED (off target), POST.
- Match: 5 rounds each; most goals wins; tie goes to sudden death.

## Shot model
- effectivePower = shotPower x strengthFactor.
- strengthFactor maps shooter strength 1-100 linearly onto
  [strengthFactorMin, strengthFactorMax] from config.
- Higher effectivePower lowers the save chance and raises the miss chance.
- Higher accuracy lowers the miss chance. High aims miss more often than low.
- A fixed share of off-target shots hit the post instead (POST).
- Higher keeper reach raises the save chance when the keeper guesses right.

Resolution order, one RNG draw each:
1. Miss check: if off target, roll POST vs MISSED.
2. Keeper guess: correct column with probability from reaction.
3. If guessed right, save check using reach and effectivePower; else GOAL.

## Data (config, not code)
- Shooter: accuracy, strength (1-100)
- Keeper: reach, reaction (1-100)
- Two preset shooters and two preset keepers
- All tuning numbers in one config module (src/shared/config). Starting values:

| Key | Value | Meaning |
|---|---|---|
| strengthFactorMin / Max | 0.7 / 1.3 | multiplier at strength 1 / 100 |
| missBase | 0.03 | miss chance at low power, perfect accuracy |
| missPowerThreshold | 50 | effectivePower above this starts adding miss chance |
| missPerPower | 0.006 | extra miss chance per point above threshold |
| missAccuracyReduction | 0.6 | accuracy 100 cuts power-based miss chance by 60% |
| missHighAimBonus | 0.05 | extra miss chance for high aims |
| postShareOfMisses | 0.25 | share of off-target shots that hit the post |
| guessBase | 0.33 | correct-column chance at reaction 0 |
| guessPerReaction | 0.004 | added per reaction point (max ~0.73) |
| saveBase | 0.35 | save chance on correct guess before modifiers |
| savePerReach | 0.005 | added per reach point |
| savePerPower | 0.005 | removed per effectivePower point |
| saveMin / saveMax | 0.05 / 0.95 | clamp for save chance |
| aiPowerMin / Max | 55 / 85 | AI shot power range |
| rounds | 5 | kicks per side before sudden death |

## Architecture
- src/shared/logic: pure Luau, no Roblox objects. resolveShot(shot, shooter,
  keeper, rng) returns the outcome. Match state machine (rounds, score, sudden
  death). AI shot picker. Seedable RNG so tests are repeatable.
- src/shared/config: all numbers and presets.
- src/server: owns the match. Resolves every kick (client never decides outcome).
- src/client: input (aim, power), simple ball/keeper animation, HUD.
- One file lists every remote event/message between client and server.

## Milestones and "done" criteria
M1 Logic only: tests pass for resolveShot (same seed = same result; higher
   keeper reaction saves more; higher effectivePower saves less and misses
   more; higher strength raises effectivePower; higher accuracy misses less),
   AI shot picker (stays inside config ranges), and the match state machine
   (5 rounds, tie to sudden death, correct winner, early finish when one side
   can't catch up). No Roblox needed.
M2 Playable: pitch/goal/ball/keeper from simple parts; player can aim, set power,
   take a kick; server resolves; ball moves; score HUD updates; a full match
   can be played to a winner.
M3 Polish: pick screen before every match, result screen (score, kick dots,
   per-side stats), Play again returns to the pick screen with last picks kept.

## Out of scope for v1
Multiplayer, saving, real models/animations, sound, gacha, multiple stadiums,
player as keeper.
