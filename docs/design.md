# Penalty Shootout: design

## Overview
Two-player penalty shootout. The players take turns as shooter and keeper:
5 kicks each, then sudden death. Each kick is a hidden guessing game: the
shooter picks where to aim and how hard, the keeper picks where to dive, at
the same time. Players appear as their own Roblox avatars.

## Players and matchmaking
- A server holds exactly 2 players (Max Players = 2 in Game Settings).
- The match starts when the second player joins; until then the first sees
  "Waiting for an opponent".
- p1 (first to join) shoots first; roles swap every kick.
- If a player leaves mid-match they forfeit and the other player wins. The
  remaining player sees the result, and the next player to join starts a new
  match straight away.
- After a normal finish, a new match starts once both players press Rematch.
- In Studio only, a test bot fills the second slot so one person can test
  (config.studioBot). It picks random choices and never runs in a live game.

## Each kick
- Both players choose at the same time, hidden, within config.choiceTime
  (10 s). A player may change their choice until the kick is resolved.
- Shooter: aim zone (left/centre/right x high/low) and power (0-100, from an
  oscillating power bar).
- Keeper: dive zone (the same 6 zones). The keeper's grid is mirrored on screen
  because they face the other way.
- If time runs out, missing choices use config.defaultShot / defaultDive
  (centre-low at medium power; keeper stays centre-low).
- The kick resolves as soon as both have chosen, or when time runs out.

## Resolving a kick (src/shared/logic/Shot.luau)
1. Miss check: chance rises with power above a threshold; high aims miss more.
   A share of misses hit the post (POST), the rest go wide/over (MISSED).
2. Keeper in the shot's exact zone: save chance 0.9 - 0.003 x power
   (about 75% at power 50).
3. Right column, wrong height: save chance 0.35 - 0.002 x power (about 25%).
4. Wrong column: goal.
- Outcome per kick: GOAL, SAVED, MISSED, POST. All numbers live in config.

## Match (src/shared/logic/Match.luau)
- 5 kicks each; most goals wins; ends early when one side can't catch up.
- Tie after 5 each goes to sudden death, decided after each complete pair.
- A forfeit ends the match for the other side.

## Architecture
- src/shared/logic: pure Luau, no Roblox objects, tested under Lune.
  Shot (resolution), Match (state machine), Duel (one match: roles, hidden
  choices, defaults, forfeit), Summary (result screen data), ShotPath (where
  the ball ends up), Rng (seedable so tests are repeatable).
- src/shared/config: all numbers. src/shared/Stage: where avatars stand.
- src/shared/Remotes: the one list of every client/server message.
- src/server: owns the match (waiting room, choice timer, resolving, rematch,
  forfeits, Studio bot), loads the ball and goal meshes, builds the pitch.
  Clients never decide outcomes.
- src/client: controls, HUD, result screen, camera (shooter view behind the
  ball; keeper view from inside the goal), ball animation, and AvatarRig,
  which poses both avatars from code (keeper ready stance and dives, shooter
  run-up and kick). Works with Motor6D and AnimationConstraint joints.
- src/character: an empty Animate script that replaces Roblox's default so
  avatars are only posed by AvatarRig.
- Avatars are anchored and placed by the server; clients pose them locally.

## Out of scope for v1
Saving, progression, more than 2 players per server, sound, multiple stadiums,
avatar-specific scaling of animations (poses assume a standard-sized R15).
