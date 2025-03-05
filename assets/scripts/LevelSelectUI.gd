extends CanvasLayer

# UI elements for level selection
var level_list
var description_label
var par_label
var play_button
var back_button
var level_manager

signal level_selected(level_data)
signal back_pressed

func _ready():
	# Initialize UI elements
	level_list = $Panel/VBoxContainer/LevelList
	description_label = $Panel/VBoxContainer/DescriptionLabel
	par_label = $Panel/VBoxContainer/ParLabel
	play_button = $Panel/VBoxContainer/PlayButton
	back_button = $Panel/VBoxContainer/BackButton
	
	# Connect signals
	level_list.item_selected.connect(_on_level_selected)
	play_button.pressed.connect(_on_play_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Get the level manager
	level_manager = get_node("/root/LevelManager")

	if not level_manager:
		push_error("LevelManager not found! Level selection won't work properly.")
	
	# Populate the level list
	populate_levels()

func populate_levels():
	if not level_manager:
		return
	
	level_list.clear()
	
	for i in range(level_manager.get_level_count()):
		var level_info = level_manager.get_level_info(i)
		level_list.add_item(level_info.name)
	
	# Select the current level
	level_list.select(level_manager.current_level_index)
	_on_level_selected(level_manager.current_level_index)

func _on_level_selected(index):
	if not level_manager:
		return
	
	var level_info = level_manager.get_level_info(index)

	if level_info:
		description_label.text = level_info.description
		par_label.text = "Par: " + str(level_info.par)
		
		# Enable play button
		play_button.disabled = false

func _on_play_pressed():
	var selected_index = level_list.get_selected_items()[0]
	var level_info = level_manager.select_level(selected_index)
	
	if level_info:
		emit_signal("level_selected", level_info)

func _on_back_pressed():
	emit_signal("back_pressed")

func add_level(level_info):
	level_list.add_item(level_info.name)
	level_list.select(level_list.get_item_count() - 1)
	_on_level_selected(level_list.get_item_count() - 1)
