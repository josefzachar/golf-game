extends CanvasLayer

# UI elements for the game
var stroke_label
var message_label 
var level_name_label
var message_panel
var win_message_label

# Game control buttons
var restart_button
var edit_button
var menu_button

# Signals
signal restart_game
signal edit_level
signal return_to_menu

func _ready():
	# Get label references
	stroke_label = $MarginContainer/VBoxContainer/StrokeLabel
	level_name_label = $MarginContainer/VBoxContainer/LevelNameLabel
	message_label = $MarginContainer/VBoxContainer/MessageLabel
	
	# Legacy restart button (after winning)
	var legacy_restart_button = $MarginContainer/VBoxContainer/RestartButton
	legacy_restart_button.pressed.connect(_on_restart_pressed)
	legacy_restart_button.hide()
	
	# Get message panel references
	message_panel = $MessagePanel
	win_message_label = $MessagePanel/WinMessageLabel
	message_panel.visible = false
	
	# Set up game control buttons
	restart_button = $GameControls/RestartButton
	edit_button = $GameControls/EditButton
	menu_button = $GameControls/MenuButton
	
	# Connect button signals
	restart_button.pressed.connect(_on_restart_pressed)
	edit_button.pressed.connect(_on_edit_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# Check if we're playing a custom level from the editor
	var level_transfer = get_node_or_null("/root/LevelTransfer")
	if level_transfer and level_transfer.is_level_from_editor():
		# Enable edit button
		edit_button.disabled = false
		edit_button.tooltip_text = "Edit this custom level"
	else:
		# Disable edit button for non-custom levels
		edit_button.disabled = true
		edit_button.tooltip_text = "Edit is only available for custom levels"
	
	# Ensure UI is visible
	visible = true
	
	print("UI initialized with game controls")

func update_stroke_count(count):
	stroke_label.text = "Strokes: " + str(count)

func update_level_name(level_name):
	level_name_label.text = "Level: " + level_name

func show_win_message(stroke_count):
	print("UI: Showing win message with " + str(stroke_count) + " strokes")
	
	# Update the win message panel
	win_message_label.text = "Victory!\nStrokes: " + str(stroke_count) + "\n\nPress Restart to play again"
	message_panel.visible = true
	
	# Legacy support
	message_label.text = "You Won! Strokes: " + str(stroke_count)
	message_label.show()
	$MarginContainer/VBoxContainer/RestartButton.show()

func _on_restart_pressed():
	# Hide win message and legacy button
	message_label.hide()
	$MarginContainer/VBoxContainer/RestartButton.hide()
	message_panel.hide()
	
	# Reset stroke count
	stroke_label.text = "Strokes: 0"
	
	# Signal to restart the game
	emit_signal("restart_game")

func _on_edit_pressed():
	# Signal to edit the current level
	emit_signal("edit_level")

func _on_menu_pressed():
	# Signal to return to main menu
	emit_signal("return_to_menu")
