# galileo_button.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2019-2026 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield in the US
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
class_name GalileoButton
extends IVPanelButton

## The button that shows and hides Galileo's chat panel, there only while
## Galileo is connected to a model.
##
## Galileo is experimental, so a user who hasn't set it up in Options never sees
## it. Connecting shows this button and opens the panel; disconnecting hides
## both, with [member IVPanelButton.close_panel_when_hidden] set.


func _ready() -> void:
	super()
	var connections := IVAssistant.connections
	visible = connections != null and connections.connection != null
	if connections:
		connections.connection_changed.connect(_on_connection_changed)


func _on_connection_changed() -> void:
	var is_connected_to_model := IVAssistant.connections.connection != null
	if is_connected_to_model and !visible:
		show()
		button_pressed = true
	visible = is_connected_to_model
