extends Node2D

# Core variables
var grid = []  # Reference to the grid from SandSimulation
var ball_position = Vector2(50, 80)  # Default ball starting position in grid coordinates
var default_position = Vector2(50, 80)  # Store the default starting position
var ball_velocity = Vector2.ZERO
var sand_simulation = null
var main_node = null

# References to component scripts
var physics_handler = null
var special_abilities = null
var aiming_system = null

# Ball type variables
var current_ball_type = Constants.BallType.STANDARD
var ball_properties = null

# Signals
signal ball_in_hole
signal ball_type_changed(type)

func _ready():
	# Initialize components
	physics_handler = BallPhysics.new(self)
	special_abilities = BallSpecialAbilities.new(self)
	aiming_system = load("res://assets/scripts/BallAiming.gd").new(self)
	
	# Initialize ball properties
	update_ball_properties()
	
	# Get references to parent nodes
	var parent = self.get_parent()
	main_node = parent
	if parent.has_node("SandSimulation"):
		sand_simulation = parent.get_node("SandSimulation")
		# Connect to the grid updated signal
		sand_simulation.connect("grid_updated", Callable(self, "_on_grid_updated"))
		
		# In Godot 4+, use a timer node instead of await
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = 0.2
		timer.timeout.connect(func(): update_ball_in_grid())
		add_child(timer)
		timer.start()

func _process(_delta):
	# Update aiming system
	if aiming_system:
		aiming_system.update()
	
	# Request redraw for visual updates
	queue_redraw()

func _input(event):
	# Handle input in the aiming system
	if aiming_system:
		aiming_system.handle_input(event)

func update_ball_properties():
	ball_properties = Constants.BALL_PROPERTIES[current_ball_type]

func _on_grid_updated(new_grid):
	grid = new_grid
	if physics_handler:
		physics_handler.update_physics()
	queue_redraw()

func reset_position():
	ball_position = default_position
	ball_velocity = Vector2.ZERO
	if aiming_system:
		aiming_system.reset()
	update_ball_in_grid()

func set_start_position(position):
	default_position = position
	ball_position = position
	update_ball_in_grid()
	print("Ball starting position set to: ", position)

func update_ball_in_grid():
	if not sand_simulation:
		return
		
	# Clear any existing ball from the grid
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if sand_simulation.get_cell(x, y) == Constants.CellType.BALL:
				sand_simulation.set_cell(x, y, Constants.CellType.EMPTY)
	
	# Set the ball's position in the grid
	var x = int(ball_position.x)
	var y = int(ball_position.y)
	sand_simulation.set_cell(x, y, Constants.CellType.BALL)

# Function to switch ball type
func switch_ball_type(new_type):
	if new_type == current_ball_type:
		return  # Already using this ball type
	
	# Store the old type for reference
	var old_type = current_ball_type
	
	# Set the new ball type and update properties
	current_ball_type = new_type
	update_ball_properties()
	
	# Special behavior for explosive ball - explode when switched to
	if new_type == Constants.BallType.EXPLOSIVE:
		special_abilities.explode()
	
	# Special behavior for teleport ball - swap with hole when switched to
	elif new_type == Constants.BallType.TELEPORT:
		special_abilities.swap_with_hole()
	
	# Update the ball in the grid to show the new color
	update_ball_in_grid()
	
	# Emit signal for any listeners
	emit_signal("ball_type_changed", new_type)
	
	print("Switched from " + Constants.BALL_PROPERTIES[old_type].name + " to " + ball_properties.name)

func can_shoot():
	# Don't allow shooting if game is won
	if main_node and main_node.has_method("get") and main_node.get("game_won"):
		return false
	return ball_velocity.length() < 0.1

func _draw():
	# Draw the ball with current ball type color
	var x = ball_position.x
	var y = ball_position.y
	var rect = Rect2(x * Constants.GRID_SIZE, y * Constants.GRID_SIZE, Constants.GRID_SIZE, Constants.GRID_SIZE)
	
	# Use the color from the ball properties
	var ball_color = ball_properties.get("color", Constants.BALL_COLOR)
	draw_rect(rect, ball_color, true)
	
	# Draw aiming line when shooting
	if aiming_system:
		aiming_system.draw(self)
