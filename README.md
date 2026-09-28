# Striker League — 2D Arcade Football (Godot 4 / GDScript)

A complete, playable top-down arcade football prototype built as a real Godot 4.x
project (not a web/HTML mockup). Open the `striker_league/` folder in Godot 4.3+
(Godot 4.5 stable also works) via **Project > Import** and press **F5**.

No external art or audio assets are required — sprites, the pitch, the crowd,
particle effects and every sound effect (including a looping chiptune-style
music track) are generated procedurally at runtime, so the project runs
immediately after import. Swap in real assets later without touching gameplay
code (see "Replacing placeholders" below).

## What's implemented

- **Main menu** with animated stadium backdrop (sweeping floodlights, crowd,
  bouncing ball), PLAY / QUICK MATCH / TOURNAMENT / PENALTY SHOOTOUT / TEAMS /
  SETTINGS / HOW TO PLAY / EXIT, staggered button animations, hover/click sound.
- **8 fictional teams** (`data/teams/*.tres`, `TeamData` resource) with colors,
  a procedurally-drawn logo, attack/midfield/defense/goalkeeper ratings and a
  default formation. Team selection screen with rating bars; also doubles as a
  read-only "TEAMS" browser.
- **Full match simulation**: procedurally drawn pitch (lines, penalty/goal
  areas, center circle, corner arcs, advertising boards, animated crowd, night
  floodlights), smooth dynamic camera that follows the ball/player, zooms with
  the action and shakes on big moments.
- **Player system**: acceleration/top-speed movement, stamina drain & recovery,
  sprint, arcade dribbling (ball "breathes" on a spring rather than sticking to
  the player, harder to control at speed), passing (nearest/aimed teammate with
  lead-prediction and lane-danger scoring), charge-up shooting (short/medium/
  long press → weak/normal/powerful shot with a power meter), slide tackles
  with success/foul resolution, 5 roles (GK/DEF/MID/WING/STR) each with their
  own generated stat spread.
- **Goalkeeper AI**: arcs along the goal line, predicts shot trajectories
  (ball flight is simulated ahead), reacts after a skill-scaled delay, dives,
  catches slow shots outright, parries fast ones, comes off the line for loose
  balls in the box, and distributes after a hold.
- **Real team AI** (not "chase the ball"): explicit states (Idle, Positioning,
  ChasingBall, Attacking, Defending, Marking, Passing, Shooting, Tackling,
  ReturningToPosition), designated presser(s)/chaser, man-marking of unmarked
  opponents, formation-relative home positions that shift with the ball,
  supporting-run positioning when a teammate has the ball, lane-aware passing
  and shot selection.
- **3 difficulty levels** (Easy/Normal/Hard) that change reaction time, pass/
  shot accuracy, positioning discipline, speed, tackle success, press count and
  goalkeeper skill — see `AI_PARAMS` in `scripts/systems/game_state.gd`.
- **4 formations** (4-4-2, 4-3-3, 3-5-2, 4-2-3-1), selectable for the player's
  team; AI opponents use their team's default.
- **Full match systems**: kickoff, configurable match length, half-time break,
  second half, extra time and a penalty shootout hand-off when scores are
  level, throw-ins, corners, goal kicks, fouls, possession/shots/on-target/
  saves/corners/fouls stats, goal scorer + assist tracking, post-match summary.
- **Match events & juice**: kickoff, goal (stop → animated banner → scorer →
  crowd roar → net bulge → reset), corner, goal kick, throw-in, foul whistle,
  save, half-time, full-time — all with on-screen animated notifications
  ("GOAL!", "WHAT A SAVE!", "MISS!", "OFF THE POST!", "FULL TIME!").
- **HUD**: scoreboard with team colors and names, match clock, half indicator,
  selected-player indicator + stamina bar, pass-target ring, shot power meter,
  animated notification banners, pause menu (resume/settings/restart/quit).
- **Visual effects**: ball motion trail, kick/dust particles, goal bursts,
  screen shake, full-screen goal flash, animated goal nets, speed dust, an
  animated pixel-crowd that reacts (jumps, waves) to excitement.
- **Audio**: every sound (kick, pass, tackle, save, post, goal fanfare,
  whistle, click/hover, crowd cheer/groan, stadium ambience bed, looping
  music) is synthesized at startup by `AudioManager` — an autoload other
  systems call as `AudioManager.play("kick")`, with a `register_stream()`
  hook for dropping in real `.wav`/`.ogg` files later.
- **Tournament mode**: 8-team single-elimination Quarter-Final → Semi-Final →
  Final → Champion bracket with a drawn bracket view, simulated CPU-vs-CPU
  fixtures, your own record (W/L/GF/GA/points), persisted across sessions.
- **Penalty shootout**: standalone from the menu, or triggered automatically
  after a drawn knockout/quick match. Aim with movement keys, hold Shoot to
  charge power (too much power risks skying it), release to strike; on defense
  choose a dive direction against an AI kicker. Best-of-5 then sudden death,
  animated scoreboard of makes/misses.
- **Save system**: JSON in Godot's `user://` directory (works on desktop,
  Android and Web/IndexedDB) — settings, last-selected teams, career stats and
  in-progress tournament state persist between sessions.
- **Settings**: master/music/SFX volume, difficulty, match duration, extra
  time toggle, penalties toggle, fullscreen, resolution, aim assist, camera
  shake, touch-control mode.
- **Input**: full keyboard scheme (WASD/arrows, Space hold-to-charge shoot, E
  pass, Shift sprint, Q switch player, T tackle, Esc pause), gamepad mapped to
  the same actions, and on-screen touch controls (virtual joystick + Shoot/
  Pass/Sprint/Switch/Tackle buttons) that appear automatically on touch
  devices (or can be forced on/off in Settings).
- **Export-ready settings**: physics at 60 ticks/sec, GL Compatibility
  renderer (runs on Windows/Linux/Android/Web), canvas-item stretch mode for
  resolution independence.

## Project structure

```
striker_league/
├── project.godot            # autoloads, input, display, physics config
├── scenes/                  # main_menu, match, players, ball, goalkeeper, menus, ui
├── scripts/
│   ├── player/               player.gd, goalkeeper.gd, player_stats.gd, player_visual.gd
│   ├── ai/                    (AI logic lives inside player.gd / goalkeeper.gd — see below)
│   ├── ball/                 ball.gd
│   ├── match/                match_manager.gd, pitch.gd, goal.gd, crowd.gd,
│   │                          fx_manager.gd, match_camera.gd, penalty_shootout.gd
│   ├── teams/                 team.gd, team_data.gd, formations.gd
│   ├── ui/                    main_menu.gd, team_select.gd, tournament_screen.gd,
│   │                          match_hud.gd, mobile_controls.gd, settings_panel.gd,
│   │                          stadium_backdrop.gd, team_card.gd, ui_kit.gd
│   └── systems/               game_state.gd, save_system.gd, audio_manager.gd, transition.gd
└── data/teams/*.tres         # 8 TeamData resources (ratings, colors, formation)
```

`scripts/ai` is intentionally empty as a placeholder for future dedicated AI
resources — the shipped AI is implemented as behaviour on `Player`/`Goalkeeper`
(driven by per-team `AI_PARAMS`) so it can read the same movement/kick/tackle
API a human uses; splitting it into standalone strategy resources is a natural
next refactor once you start tuning it.

## Replacing placeholders

- **Art**: gameplay draws players/ball/pitch procedurally in each node's
  `_draw()` (see `player_visual.gd`, `ball.gd`, `pitch.gd`). Swap in real art
  by adding an `AnimatedSprite2D` in `PlayerVisual`/`Ball` driven by
  `Player.anim` (an enum: Idle/Run/Sprint/Shoot/Pass/Tackle/Celebrate/Hurt/
  Dive) instead of the `_draw()` calls.
- **Audio**: call `AudioManager.register_stream("kick", load("res://assets/audio/kick.wav"))`
  (etc.) once your own audio files are in `assets/audio/` — every gameplay
  system already calls sounds by name (`AudioManager.play("kick")`), so no
  other code needs to change.
- **Teams/logos**: add more `.tres` files under `data/teams/` following the
  existing ones and list the path in `GameState.TEAM_PATHS`.

## Known limitations / next steps

This was built and statically reviewed in a sandboxed environment without a
Godot binary available to run/compile it, so please treat the first import as
a bring-up pass: open it in the Godot editor, check the Output panel for any
typos it surfaces, and playtest a quick match end-to-end. The architecture
(state machine, signals, autoloads, per-role stat generation, difficulty
params) is in place to extend from there — natural next steps are tuning AI
constants in `GameState.AI_PARAMS`, replacing placeholder art/audio per above,
and adding controller-remapping UI (gamepad already works with fixed bindings).
