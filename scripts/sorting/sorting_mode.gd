extends RefCounted
class_name SortingMode
## Mode constants shared by the start screen, the F1/F2 hotkey autoload, and
## the legacy bootstrap scene. The start screen is the durable entry point;
## FLAG remains as a fallback when the bootstrap scene is run directly.
##
## This is a pure-constants helper; nothing here mutates global state.

const MODE_SIDE_SCROLLER_3D := "sideScroller3D"
const MODE_SORTING_DESK_2D  := "sortingDesk2D"

## Default mode used by the legacy bootstrap scene when launched directly.
const FLAG: String = MODE_SIDE_SCROLLER_3D

## Title screen — the project's main_scene.
const START_SCREEN_SCENE := "res://scenes/ui/start_screen.tscn"

## Level selector for the side-scroller mode (lists the two worlds).
const LEVEL_SELECT_SCENE := "res://scenes/ui/level_select.tscn"

## Existing 3D entry point — the prior project.godot run/main_scene.
const SIDE_SCROLLER_ENTRY := "res://scenes/levels/neighborhood/neighborhood_00_01/neighborhood_00_01.tscn"

## 2D sorting desk scene.
const SORTING_DESK_SCENE := "res://scenes/sorting/sorting_desk.tscn"

## Level pool the 2D mode pulls house + letter data from. Each entry is an
## existing 3D level scene — the sorting desk reads its exported house data
## and LETTERS array without ever rendering any 3D from it.
const SORTING_LEVEL_PATHS: Array = [
	"res://scenes/levels/neighborhood/neighborhood_01_03/neighborhood_01_03.tscn",
	"res://scenes/levels/neighborhood/neighborhood_00_01/neighborhood_00_01.tscn",
	"res://scenes/levels/neighborhood/neighborhood_00_02/neighborhood_00_02.tscn",
	"res://scenes/levels/neighborhood/neighborhood_00_03/neighborhood_00_03.tscn",
	"res://scenes/levels/neighborhood/neighborhood_01_01/neighborhood_01_01.tscn",
	"res://scenes/levels/neighborhood/neighborhood_01_02/neighborhood_01_02.tscn",
	"res://scenes/levels/neighborhood/neighborhood_01_04/neighborhood_01_04.tscn",
]

## Default starting level index for the sorting desk.
const DEFAULT_LEVEL_INDEX: int = 0
