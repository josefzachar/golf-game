extends Node

# UI elements
var ui_panel: Panel
var cell_label: Label
var property_panel: Panel
var visualization_panel: Panel
var property_labels = {}
var brush_controller
var property_controller
var visualization_controller

# Panel dragging variables
var dragging_panel = false
var drag_start_pos = Vector2.ZERO
var panel_start_pos = Vector2.ZERO

# Reference
var editor

func _ready():
	print("EditorUIController: _ready called")
	
	# We'll call setup_ui directly, but with proper null checks
	call_deferred("delayed_setup")

func delayed_setup():
	print("EditorUIController: delayed_setup called")
	
	# Get controllers directly from editor
	if editor:
		brush_controller = editor.brush_controller
		property_controller = editor.property_controller
		visualization_controller = editor.visualization_controller
		print("EditorUIController: got controller references from editor")
	else:
		print("EditorUIController: ERROR - editor reference is null")
	
	# Proceed with UI setup even if some controllers are missing
	# We'll do proper null checks in the individual UI functions
	setup_ui()

func setup_ui():
	print("EditorUIController: setup_ui called")
	
	# Create the main UI panel
	ui_panel = Panel.new()
	ui_panel.position = Vector2(10, 10)
	ui_panel.size = Vector2(250, 550)
	ui_panel.z_index = 100  # Ensure UI is on top
	ui_panel.name = "EditorUIPanel"  # Give it a specific name for easy identification
	
	# Add the panel directly to the editor if it exists
	if editor and is_instance_valid(editor):
		editor.add_child(ui_panel)
		print("EditorUIController: added UI panel to editor")
	else:
		# Fallback - add to the current scene
		get_tree().current_scene.add_child(ui_panel)
		print("EditorUIController: added UI panel to current scene (fallback)")
	
	# Create drag handle for the panel
	setup_drag_handle()
	
	# Create VBoxContainer for controls
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 30)  # Moved down to make room for drag handle
	vbox.size = Vector2(230, 510)
	ui_panel.add_child(vbox)
	
	# Create label for current tool
	cell_label = Label.new()
	cell_label.text = "Current: Sand"
	vbox.add_child(cell_label)
	
	# Setup main UI panels using the separate UI builder
	var ui_builder = load("res://assets/scripts/EditorUIPanels.gd").new()
	ui_builder.editor = editor
	ui_builder.ui_controller = self
	ui_builder.vbox = vbox
	
	# Build all UI panels with proper error handling
	if ui_builder:
		print("EditorUIController: UI builder loaded")
		
		# Call each UI building function with error handling
		_safe_call(ui_builder, "build_material_buttons")
		_safe_call(ui_builder, "build_brush_controls")
		_safe_call(ui_builder, "build_property_controls")
		_safe_call(ui_builder, "build_visualization_controls")
		_safe_call(ui_builder, "build_metadata_inputs")
		_safe_call(ui_builder, "build_file_operations")
		_safe_call(ui_builder, "build_navigation_buttons")
		
		# Store references to panels created by the builder
		if ui_builder.get("property_panel"):
			property_panel = ui_builder.property_panel
		
		if ui_builder.get("visualization_panel"):
			visualization_panel = ui_builder.visualization_panel
			
		if ui_builder.get("property_labels"):
			property_labels = ui_builder.property_labels
			
		print("EditorUIController: UI panels built successfully")
	else:
		print("EditorUIController: ERROR - Failed to load UI builder")
		# Add a basic fallback UI
		var basic_label = Label.new()
		basic_label.text = "Error: Couldn't load UI builder"
		vbox.add_child(basic_label)

# Helper method to safely call a method on an object
func _safe_call(obj, method_name):
	if obj and obj.has_method(method_name):
		obj.call(method_name)
	else:
		print("EditorUIController: ERROR - Cannot call method " + method_name)

# Setup the drag handle for the panel
func setup_drag_handle():
	var drag_handle = Panel.new()
	drag_handle.position = Vector2(0, 0)
	drag_handle.size = Vector2(250, 25)
	drag_handle.modulate = Color(0.7, 0.7, 0.8)  # Slightly different color for visibility
	ui_panel.add_child(drag_handle)
	
	# Add title label to drag handle
	var title_label = Label.new()
	title_label.position = Vector2(10, 4)
	title_label.text = "Editor Tools - Drag to move"
	title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	drag_handle.add_child(title_label)

# Update status text in the cell label
func update_status(text):
	if cell_label:
		cell_label.text = text
	print("Status: " + text)

# Update the cell type label
func update_type_label(type):
	if not cell_label:
		return
		
	match type:
		Constants.CellType.SAND:
			cell_label.text = "Current: Sand"
		Constants.CellType.DIRT:
			cell_label.text = "Current: Dirt"
		Constants.CellType.STONE:
			cell_label.text = "Current: Stone"
		Constants.CellType.WATER:
			cell_label.text = "Current: Water"
		Constants.CellType.EMPTY:
			cell_label.text = "Current: Empty"
		Constants.CellType.HOLE:
			cell_label.text = "Current: Hole"
		Constants.CellType.BALL_START:
			cell_label.text = "Click to set ball start"

# Update UI with level data
func update_ui_from_level_data():
	# This function would update all the UI elements with current level data
	# For now we'll just update the status
	if editor:
		update_status("Loaded level: " + editor.level_name)

# Check if a point is inside the UI panel
func is_point_in_ui(point: Vector2) -> bool:
	# Check if UI panel exists
	if not ui_panel:
		return false
		
	# Check if within panel boundaries
	var panel_rect = Rect2(ui_panel.position, ui_panel.size)
	return panel_rect.has_point(point)

# Input handling for panel dragging
func _input(event):
	# Skip if UI panel isn't set up yet
	if not ui_panel:
		return
		
	# Get mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Check for panel dragging
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if clicking on the panel's drag handle (top bar)
			var handle_rect = Rect2(ui_panel.position, Vector2(ui_panel.size.x, 25))
			if handle_rect.has_point(mouse_pos):
				dragging_panel = true
				drag_start_pos = mouse_pos
				panel_start_pos = ui_panel.position
				return  # Don't process any other input
		else:  # Button released
			dragging_panel = false
	
	# Handle panel dragging
	if event is InputEventMouseMotion and dragging_panel:
		var offset = mouse_pos - drag_start_pos
		ui_panel.position = panel_start_pos + offset

# Make sure to clean up when this controller is freed
func _exit_tree():
	print("EditorUIController: _exit_tree called")
	
	# Clean up UI panel if it still exists
	if ui_panel and is_instance_valid(ui_panel):
		# Instead of trying to manually remove and free the UI panel,
		# use queue_free() which is safe during scene transitions
		ui_panel.queue_free()
		ui_panel = null
	
	print("EditorUIController: _exit_tree completed safely")
