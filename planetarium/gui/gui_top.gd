# gui_top.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright (c) 2017-2021 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************************
# See comments in ivoyager/gui_example/example_game_gui.gd to understand what's
# going on here.

extends Control
class_name GUITop
const SCENE := "res://planetarium/gui/gui_top.tscn"

var selection_manager: SelectionManager

onready var _SelectionManager_: Script = Global.script_classes._SelectionManager_

func _project_init() -> void:
	Global.connect("project_builder_finished", self, "_on_project_builder_finished")
	Global.connect("system_tree_built_or_loaded", self, "_on_system_tree_built_or_loaded")
	Global.connect("simulator_exited", self, "_on_simulator_exited")
	hide()

func _ready():
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(1.0, 1.0, 1.0, 0.05) # almost transparent
	for child in get_children():
		var panel_container := child as PanelContainer
		if !panel_container:
			continue
		panel_container.set("custom_styles/panel", style_box)
	var set_date_time: Button = find_node("SetDateTime")
	set_date_time.connect("pressed", $TimeSetPopup, "popup")

func _on_project_builder_finished() -> void:
	theme = Global.themes.main

func _on_system_tree_built_or_loaded(is_new_game: bool) -> void:
	if is_new_game:
		selection_manager = _SelectionManager_.new()
	show()

func _on_simulator_exited() -> void:
	hide()
