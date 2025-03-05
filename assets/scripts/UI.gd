extends CanvasLayer

# UI elements for the game
var stroke_label
var message_label 
var restart_button

signal restart_game

func _ready():
	# Get node references
	stroke_label = $MarginContainer/VBoxContainer/StrokeLabel
	message_label = $MarginContainer/VBoxContainer/MessageLabel
	restart_button = $MarginContainer/VBoxContainer/RestartButton
	
	# Ensure UI is visible
	visible = true
	
	# Hide the restart button initially
	restart_button.hide()
	message_label.hide()
	
	# Connect button signal
	restart_button.pressed.connect(_on_restart_pressed)
	
	print("UI initialized successfully")
	

func update_stroke_count(count):
	stroke_label.text = "Strokes: " + str(count)
	

func update_level_name(level_name):
	# If you have a label for level name, update it
	if has_node("MarginContainer/VBoxContainer/LevelNameLabel"):
		$MarginContainer/VBoxContainer/LevelNameLabel.text = level_name
	else:
		# If you don't have a dedicated label, you could append it to the stroke label
		# or simply print for debugging
		print("Level name updated to: " + level_name)

func show_win_message(stroke_count):
	print("UI: Showing win message with " + str(stroke_count) + " strokes")
	message_label.text = "You Won! Strokes: " + str(stroke_count)
	message_label.show()
	restart_button.show()

func _on_restart_pressed():
	# Hide win message and button
	message_label.hide()
	restart_button.hide()
	
	# Reset stroke count
	stroke_label.text = "Strokes: 0"
	
	# Signal to restart the game
	emit_signal("restart_game")
