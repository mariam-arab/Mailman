# 2D Sorting Desk — Experiment Notes

An additive, reversible experiment that replaces the 3D-rendered side-scroller
with a 2D drag-and-drop mail-sorting game in the Papers Please register. The
original 3D game is untouched and remains selectable via a config flag.

## How to run / toggle

- **Flag (durable):** `scripts/sorting/sorting_mode.gd` → `const FLAG`. Set to
  `MODE_SORTING_DESK_2D` (default on this branch) or `MODE_SIDE_SCROLLER_3D`.
- **Hotkey (session-only):** `F1` swaps between the two modes without a restart.
- Both modes share a single `project.godot` entry point
  (`scenes/sorting/mode_bootstrap.tscn`) that reads the flag and hands off to
  the matching scene. Nothing about the 3D code path was rewired.

## Files added

All live under `scripts/sorting/` and `scenes/sorting/`:

| File | Purpose |
|---|---|
| `scripts/sorting/sorting_mode.gd` | `class_name SortingMode`. Constants: `FLAG`, mode ids, 3D entry path, sorting desk scene path, level pool. |
| `scripts/sorting/mode_bootstrap.gd` | Bootstrap scene script. Reads `SortingMode.FLAG` at startup and `change_scene_to_file`s to the right target. |
| `scripts/sorting/sorting_hotkey.gd` | Autoload. Listens for F1, flips between the 2D desk scene and the original 3D main scene. Session-only. |
| `scripts/sorting/level_extractor.gd` | `class_name SortingLevelExtractor`. Headless reader for the existing 3D level `.tscn` files — extracts house records and letter arrays without ever rendering any 3D. See "Data reuse" below. |
| `scripts/sorting/sorting_desk.gd` | Root controller for the 2D mode. Builds the backdrop procedurally, spawns houses + tray, mediates drag-and-drop, runs end-of-day evaluation. |
| `scripts/sorting/house_card.gd` | One flat 2D house: body rect, roof triangle, windows, door, number plaque. Exposes a drop-target rect centered on the door. |
| `scripts/sorting/letter_card.gd` | One draggable Papers Please-style letter: cream paper, monospace address, stamp, postmark, optional "NOT MY MAIL" stamp overlay. |
| `scripts/sorting/letter_tray.gd` | Fanned tray layout. Computes slot positions and rotations, holds home positions for return-on-miss. |
| `scripts/sorting/end_day_summary.gd` | Stats panel shown after a perfect end-of-day pass. |
| `scenes/sorting/mode_bootstrap.tscn` | Thin scene wrapping `mode_bootstrap.gd`. |
| `scenes/sorting/sorting_desk.tscn` | Thin scene wrapping `sorting_desk.gd` — the desk builds its UI procedurally, so the scene file is intentionally minimal. |
| `scripts/sorting/NOTES.md` | This file. |

## Files edited (existing)

Only one file was touched: `project.godot`, with two minimal changes.

1. `run/main_scene` changed from
   `res://scenes/levels/neighborhood/neighborhood_00_01/neighborhood_00_01.tscn`
   → `res://scenes/sorting/mode_bootstrap.tscn`. The bootstrap immediately
   redirects to the original 3D scene when the flag is set to `sideScroller3D`,
   so this is functionally transparent.
2. `[autoload]` gained a new line:
   `SortingHotkey="*res://scripts/sorting/sorting_hotkey.gd"` — exists purely
   so F1 works across scene changes. No other autoloads were touched.

No other existing file was modified, renamed, deleted, moved, or refactored.

## Existing files read from (no edits)

For data reuse only — no includes, no edits, no prefab modifications.

- `scripts/mail/mail.gd` — `Mail` Resource class instantiated to carry
  per-letter data into the 2D scene. Same fields as 3D mode.
- `scripts/game/game_state.gd` — the address-matching rule lives here
  (`letter.correct_house_id == mailbox.house_id` at line 52). Reused verbatim
  inside `sorting_desk.gd::_run_end_of_day`. `GameState` is *not* mutated by
  the 2D mode; the desk manages its own state.
- `scripts/interactables/mailbox.gd` — referenced only for reading the
  address-matching rule.
- `scenes/levels/neighborhood/neighborhood_*.tscn` — read headlessly by
  `SortingLevelExtractor` to pull `house_label`, `house_id`, `body_color`,
  `roof_color`, and z-order per house. Never rendered.
- The `.gd` sidecar next to each `.tscn` (e.g. `neighborhood_00_01.gd`) —
  its `const LETTERS := [...]` array is read via
  `script.get_script_constant_map()`. No instance method is invoked.

## Data reuse — how

Houses are hand-placed inside 3D level scenes, not stored as a parallel data
file. To avoid authoring a second per-level data file (or forking the 3D
scenes), the sorting desk extracts house + letter data headlessly at load:

1. `load(path)` returns a `PackedScene`.
2. `packed.instantiate()` materialises the node tree in memory. Because the
   resulting root is never added to `SceneTree`, `_ready()` does not fire
   on the level or any descendant node. No 3D renders, no autoloads run
   against the fake tree, no audio triggers.
3. The detached tree is walked; any node carrying `house_label` +
   `body_color` + `roof_color` is treated as a house, any node carrying
   `house_label` + `house_id` as a mailbox. They're correlated by label.
4. The level script's `LETTERS` constant is read via
   `get_script_constant_map()` and materialised into `Mail` resources.
5. The detached root is `queue_free`'d immediately.

This keeps the 2D mode zero-touch on the existing 3D scene files.

## Design choices made

- **Tray layout: fanned.** Rows felt too rigid once letter count exceeded 4;
  a gentle arc with per-card rotation reads more like a pile of documents
  being worked through. Overlap grows as letter count grows — the tray never
  scrolls and never hides any letter, per spec.
- **Drop target: front door.** Alternatives considered were mailbox and
  whole-house footprint. The door is centrally located on every house,
  visually unambiguous, and leaves room for the letter to tilt against it
  without obscuring the house number above the roof.
- **House number placement: above the roof (plaque).** The 3D game puts
  the label on the house facade, but in 2D, placing it on a sky-backdrop
  plaque above the roof keeps the number readable at a glance regardless
  of house body colour, which was the spec's highest priority.
- **First-level help hint:** only shown on the default starting level. On
  any other level, or after the first successful drag of the session, it
  disappears.
- **End-of-day auto-trigger:** when the tray becomes empty after a drop,
  evaluation runs automatically. The manual "End Day" button is always
  visible for the "I think I'm done, but I may not be" case — a half-filled
  board can also trigger evaluation.

## What end-of-day does (explicitly)

1. For every placed letter, compare `letter.correct_house_id` to the
   `house_id` of the house it's stuck to.
2. Correct letters stay put.
3. Wrong letters detach from their house, receive a red "NOT MY MAIL"
   stamp (fading in over ~0.45s), and tween back to their tray slot.
4. If no letters are wrong AND the tray is empty, the summary panel
   appears with totals (total / first-try correct / re-delivered /
   final correctness).
5. The player can drag the stamped letters back to different houses and
   trigger evaluation again. Stamps clear automatically on re-attachment.

## Correctness-feedback contract (invariant)

The 2D mode deliberately gives **no real-time correctness feedback**:

- Hovering a house while dragging pulses *every* house — the pulse says
  "droppable", not "correct". This is uniform regardless of whether the
  letter's address matches the house.
- Drops succeed on any house. Whether the placement is right is never
  shown until end-of-day evaluation.
- There is no green outline, no matching-address highlight, no auto-sort.

See `house_card.gd::set_hover` and `sorting_desk.gd::on_letter_drag_moved`
— neither function looks at `letter.correct_house_id`.

## Assumptions and deferrals

- **House colour source.** The extractor reads `body_color` / `roof_color`
  off the existing 3D House nodes. If the 3D art direction changes, the
  2D houses recolour automatically. If a future level introduces a
  non-House node as a building, the extractor will skip it — fine for now.
- **Obscured addresses.** Some levels have `address_line = "?? Maple…"`
  for elimination-puzzle letters. Those render in the tray unchanged;
  the player can still drop them anywhere, and end-of-day still uses
  `correct_house_id` for evaluation — so those puzzles remain solvable.
- **Touch input.** Mouse-only. The original game has no touch path either.
- **Audio.** No SFX in the 2D mode. The spec allowed a soft click on a
  correct drop "if audio hooks exist"; there's no shared audio bus, so
  it's skipped.
- **Sprites.** None. Every 2D element is drawn with `Control` nodes,
  `ColorRect`s, `Polygon2D`s, and `_draw()`. No new textures introduced.

## Rolling this experiment back

1. Set `scripts/sorting/sorting_mode.gd::FLAG` to `MODE_SIDE_SCROLLER_3D`
   → 3D side-scroller restored, hotkey still available.
2. To delete the experiment entirely:
   - Delete the `scripts/sorting/` and `scenes/sorting/` folders.
   - In `project.godot`, revert `run/main_scene` to
     `res://scenes/levels/neighborhood/neighborhood_00_01/neighborhood_00_01.tscn`.
   - In `project.godot`, remove the `SortingHotkey` autoload line.
   - No other files need revisiting — the 3D code path was never modified.
