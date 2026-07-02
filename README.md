# Familiar's Call

Mobile autobattler MVP built in **Godot 4.x** (GDScript).

## How to run

1. Install [Godot 4.3+](https://godotengine.org/download) (4.7 recommended per design docs).
2. Open Godot → **Import** → select `project.godot` in this folder.
3. Press **F5** (Run Project).

## What's included (Phase 1 MVP)

- **40 familiars** across 5 schools with full stats and passives
- **Headless battle simulator** with synergy system and event log
- **Squad Builder** — pick 5 familiars, front/back formation, live synergy preview
- **Rift Trials** — 5 PvE encounters with Dust rewards
- **Pack Opening** — Common Page (Dust) and Sealed Tome (Lumen) with pity
- **Grimoire** — collection tracker + Bound Pages combo wins
- **Shop** — debug Lumen grants (real IAP deferred)
- **Local save** — `user://save.json`

## Controls

All mouse-driven. Battles can be **played** (step-through log) or **skipped** to results.

## Project structure

```
data/           JSON content (familiars, economy, synergies, trials)
scripts/
  autoloads/    GameState, BattleSimulator, SaveManager, EconomyManager
  resources/    FamiliarData, FamiliarInstance
  ui/           Screen scripts + shared UI components
scenes/         One scene per screen
```

## Design docs

Based on `familiars-call-gdd.md` and `familiars-call-build-spec.md`. Phase 2 (async PvP, real IAP, Battle Pass) is not implemented.
