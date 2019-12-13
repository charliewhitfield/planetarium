# planetarium.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2019 Charlie Whitfield
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
# This extension can run either the standalone Planetarium "app" or web-based
# planetarium. In production HTML5 export, the web version is triggered by
# presence of ivoyager_assets_web and absence of ivoyager_assets. However, the
# web version can also be forced by setting FORCE_WEB_BUILD = true.
#
# For functional HTML5 export, you must set GLES2!

extends Reference

const EXTENSION_NAME := "Planetarium"
const EXTENSION_VERSION := "0.0.3 development"
const EXTENSION_VERSION_YMD := 20191109

const USE_PLANETARIUM_GUI := true
const FORCE_WEB_BUILD := false # for dev only; production uses assets detection

var _is_web_build := false
var _use_web_assets := false

func extension_init() -> void:
	ProjectBuilder.connect("project_objects_instantiated", self, "_on_project_objects_instantiated")
	Global.connect("about_to_add_environment", self, "_on_about_to_add_environment")
	var has_base_assets := FileHelper.is_valid_dir("res://ivoyager_assets")
	var has_web_assets := FileHelper.is_valid_dir("res://ivoyager_assets_web")
	_is_web_build = FORCE_WEB_BUILD or (!has_base_assets and has_web_assets)
	_use_web_assets = _is_web_build and has_web_assets
	print("is_web_build = ", _is_web_build, "; use_web_assets = ", _use_web_assets)
	if USE_PLANETARIUM_GUI:
		ProjectBuilder.gui_top_nodes._ProjectGUI_ = PlanetariumGUI
	ProjectBuilder.gui_top_nodes.erase("_LoadDialog_")
	ProjectBuilder.gui_top_nodes.erase("_SaveDialog_")
	ProjectBuilder.program_references.erase("_SaverLoader_")
	Global.project_name = "I, Voyager Planetarium"
	Global.enable_save_load = false
	Global.allow_time_reversal = true
	if _is_web_build:
		ProjectBuilder.gui_top_nodes.erase("_SplashScreen_")
		ProjectBuilder.gui_top_nodes.erase("_MainMenu_")
		ProjectBuilder.gui_top_nodes.erase("_MainProgBar_")
		Global.use_threads = false
		Global.skip_splash_screen = true
		Global.asteroid_mag_cutoff_override = 14.0
		Global.vertecies_per_orbit = 200
	if _use_web_assets:
		Global.asset_replacement_dir = "ivoyager_assets_web"
		Global.asset_paths.starfield = "res://ivoyager_assets/starfields/starmap_8k.jpg"

func _on_project_objects_instantiated() -> void:
	var tree_manager: TreeManager = Global.objects.TreeManager
	tree_manager.show_labels = true
	tree_manager.show_orbits = true
	if _is_web_build:
		var input_map_manager: InputMapManager = Global.objects.InputMapManager
		# warning-ignore:unused_variable
		var default_map := input_map_manager.defaults
		var settings_manager: SettingsManager = Global.objects.SettingsManager
		var default_settings := settings_manager.defaults
		default_settings.gui_size = SettingsManager.GUISizes.GUI_LARGE
		default_settings.planet_orbit_color =  Color(0.6,0.6,0.2)
		default_settings.dwarf_planet_orbit_color = Color(0.1,0.9,0.2)
		default_settings.moon_orbit_color = Color(0.3,0.3,0.9)
		default_settings.minor_moon_orbit_color = Color(0.6,0.2,0.6)
	else:
		Global.objects.ProjectGUI.hide()

func _on_about_to_add_environment(environment: Environment, _is_world_env: bool) -> void:
	if _is_web_build:
		# GLES2 lighting is very different than GLES3!
		environment.background_energy = 1.0
		environment.ambient_light_energy = 0.1

