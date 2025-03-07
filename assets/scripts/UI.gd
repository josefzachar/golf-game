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

# Ball selection controls
var ball_selector_container
var ball_type_buttons = []
var ball_type_tooltip
var current_ball_type = Constants.BallType.STANDARD

# Signals
signal restart_game
signal edit_level
signal return_to_menu
signal switch_ball_type(type)

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
	
	# Create the ball selector UI
	create_ball_selector()
	
	# Ensure UI is visible
	visible = true
	
	print("UI initialized with game controls and ball selector")

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
	
func create_ball_selector():
	# Create container for the ball selector at the bottom of the screen
	ball_selector_container = HBoxContainer.new()
	
	# Set up proper anchoring to position at bottom
	var control = Control.new()
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.anchor_left = 0.0
	control.anchor_right = 1.0
	control.offset_top = -80  # Height from bottom
	control.offset_bottom = -20  # Margin from bottom
	control.offset_left = 20  # Margin from left
	control.offset_right = -20  # Margin from right
	add_child(control)
	
	# Add the container to the control
	ball_selector_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ball_selector_container.add_theme_constant_override("separation", 10)
	control.add_child(ball_selector_container)
	
	# Create tooltip label for ball descriptions
	ball_type_tooltip = Label.new()
	ball_type_tooltip.anchor_top = 1.0
	ball_type_tooltip.anchor_bottom = 1.0
	ball_type_tooltip.anchor_left = 0.0
	ball_type_tooltip.anchor_right = 1.0
	ball_type_tooltip.offset_top = -105  # Position above buttons
	ball_type_tooltip.offset_bottom = -85
	ball_type_tooltip.offset_left = 20
	ball_type_tooltip.offset_right = -20
	ball_type_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ball_type_tooltip.text = "Select a ball type"
	add_child(ball_type_tooltip)
	
	# Create buttons for each ball type
	for type in Constants.BallType.values():
		var button = Button.new()
		var props = Constants.BALL_PROPERTIES[type]
		
		# Set button properties
		button.text = props.name
		button.custom_minimum_size = Vector2(100, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Add color indication (modify button text color to match ball color)
		var color = props.color
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = props.color.darkened(0.3)
		button_style.border_width_bottom = 3
		button_style.border_color = props.color
		button_style.corner_radius_top_left = 5
		button_style.corner_radius_top_right = 5
		button_style.corner_radius_bottom_left = 5
		button_style.corner_radius_bottom_right = 5
		
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		
		# Connect signal
		var type_value = type  # Create a local copy for the lambda
		button.pressed.connect(func(): _on_ball_type_selected(type_value))
		button.mouse_entered.connect(func(): _on_ball_button_hover(type_value))
		button.mouse_exited.connect(func(): _on_ball_button_exit())
		
		# Add to container
		ball_selector_container.add_child(button)
		ball_type_buttons.append(button)
	
	# Highlight current selection
	update_ball_selection_ui(Constants.BallType.STANDARD)
	
	print("Ball selector created with " + str(ball_type_buttons.size()) + " buttons")

func _on_ball_type_selected(type):
	current_ball_type = type
	update_ball_selection_ui(type)
	
	# Emit signal to switch ball type
	emit_signal("switch_ball_type", type)
	
	# Update tooltip to show current ball info
	var props = Constants.BALL_PROPERTIES[type]
	ball_type_tooltip.text = props.description

func _on_ball_button_hover(type):
	# Show description when hovering
	var props = Constants.BALL_PROPERTIES[type]
	ball_type_tooltip.text = props.description

func _on_ball_button_exit():
	# Restore current ball description when not hovering
	var props = Constants.BALL_PROPERTIES[current_ball_type]
	ball_type_tooltip.text = props.description

func update_ball_selection_ui(selected_type):
	# Update button visuals to reflect current selection
	for i in range(ball_type_buttons.size()):
		var type = Constants.BallType.values()[i]
		var button = ball_type_buttons[i]
		var props = Constants.BALL_PROPERTIES[type]
		
		if type == selected_type:
			# Selected button - brighter with thicker border
			var selected_style = StyleBoxFlat.new()
			selected_style.bg_color = props.color
			selected_style.border_width_bottom = 5
			selected_style.border_color = Color.WHITE
			selected_style.corner_radius_top_left = 5
			selected_style.corner_radius_top_right = 5
			selected_style.corner_radius_bottom_left = 5
			selected_style.corner_radius_bottom_right = 5
			
			button.add_theme_stylebox_override("normal", selected_style)
			button.add_theme_color_override("font_color", Color.BLACK)
		else:
			# Unselected button - darker
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = props.color.darkened(0.3)
			normal_style.border_width_bottom = 3
			normal_style.border_color = props.color
			normal_style.corner_radius_top_left = 5
			normal_style.corner_radius_top_right = 5
			normal_style.corner_radius_bottom_left = 5
			normal_style.corner_radius_bottom_right = 5
			
			button.add_theme_stylebox_override("normal", normal_style)
			button.add_theme_color_override("font_color", Color.WHITE)
