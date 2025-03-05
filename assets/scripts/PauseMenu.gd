# PauseMenu.gd
extends CanvasLayer

signal resume_game
signal return_to_main_menu

func _ready():
	# Hide the menu initially
	visible = false
	
	# Connect button signals
	$Panel/VBoxContainer/ResumeButton.pressed.connect(func(): emit_signal("resume_game"))
	$Panel/VBoxContainer/MainMenuButton.pressed.connect(func(): emit_signal("return_to_main_menu"))

func show_menu():
	visible = true
	get_tree().paused = true

func hide_menu():
	visible = false
	get_tree().paused = false
