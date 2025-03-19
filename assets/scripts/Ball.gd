extends Node2D

# Core variables
var grid = []  # Reference to the grid from SandSimulation
var ball_position = Vector2(50, 80)  # Default ball starting position in grid coordinates
var default_position = Vector2(50, 80)  # Store the default starting position
var ball_velocity = Vector2.ZERO
var sand_simulation = null
var main_node = null
var current_grid_pos = Vector2(-1, -1)  # Track current grid position for efficient updates

# References to component scripts
var physics_handler = null
var special_abilities = null
var aiming_system = null

# Ball type variables
var current_ball_type = Constants.BallType.STANDARD
var ball_properties = null

# Rolling animation variables
var ball_rotation = 0.0  # Current rotation angle in radians
var last_position = Vector2.ZERO  # Track last position to calculate movement
var ball_radius = 1.5  # Ball radius in grid cells (slightly larger than default)
var ball_pixels = []  # Array to store the pixels that make up the ball

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
	
	# Initialize ball pixels pattern
	_initialize_ball_pixels()
	
	# Initialize last position
	last_position = ball_position

# Initialize the pixels that make up our larger ball
func _initialize_ball_pixels():
	ball_pixels.clear()
	
	# Create a circular pattern of pixels
	var pixel_size = Constants.GRID_SIZE / 1  # Size of each component pixel
	var visual_radius = ball_radius * Constants.GRID_SIZE / pixel_size
	
	# Create the ball pixel pattern
	for x in range(-int(visual_radius)-1, int(visual_radius)+2):
		for y in range(-int(visual_radius)-1, int(visual_radius)+2):
			var dist = Vector2(x, y).length()
			if dist <= visual_radius:
				# Determine color based on position (create some pattern)
				var pattern_value = (x + y) % 2 == 0  # Checkerboard pattern
				
				# Add this pixel to our ball
				ball_pixels.append({
					"offset": Vector2(x, y) * pixel_size,
					"size": pixel_size,
					"pattern": pattern_value
				})

func _process(delta):
	# Update aiming system
	if aiming_system:
		aiming_system.update()
	
	# Update ball rotation based on horizontal velocity
	update_ball_rotation(delta)
	
	# Handle ceiling stick timer for sticky ball
	if current_ball_type == Constants.BallType.STICKY and has_meta("ceiling_stick_time"):
		var time_left = get_meta("ceiling_stick_time") - delta
		if time_left <= 0:
			# Time's up, remove the meta and apply gravity
			remove_meta("ceiling_stick_time")
			ball_velocity.y = 0.1  # Small initial velocity to start falling
		else:
			# Update the timer
			set_meta("ceiling_stick_time", time_left)
	
	# Request redraw for visual updates
	queue_redraw()

func update_ball_rotation(delta):
	# Only update if we have a valid position
	if last_position != Vector2.ZERO:
		# Calculate movement since last frame
		var movement = ball_position - last_position
		
		# Update rotation based on horizontal movement
		var roll_factor = 8.0  # Controls how fast the ball rotates
		
		# Simplified calculation that doesn't rely on Constants.GRID_SIZE
		var rotation_amount = movement.x * roll_factor / (ball_radius * 8.0)  # Use 8.0 as a fixed value instead
		
		# Adjust rotation based on speed (faster = more rotation)
		ball_rotation += rotation_amount
		
		# Keep rotation within 0 to 2π
		if ball_rotation > 2 * PI:
			ball_rotation -= 2 * PI
		elif ball_rotation < 0:
			ball_rotation += 2 * PI
	
	# Store current position for next frame
	last_position = ball_position

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

# Optimized ball position tracking
func update_ball_in_grid():
	if not sand_simulation:
		return
		
	# Clear previous ball position if valid
	if current_grid_pos.x >= 0 and current_grid_pos.y >= 0 and current_grid_pos.x < Constants.GRID_WIDTH and current_grid_pos.y < Constants.GRID_HEIGHT:
		sand_simulation.set_cell(current_grid_pos.x, current_grid_pos.y, Constants.CellType.EMPTY)
	
	# Set the ball's position in the grid (only a single cell)
	var x = int(ball_position.x)
	var y = int(ball_position.y)
	
	# Only set the ball cell if it's within bounds
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
		sand_simulation.set_cell(x, y, Constants.CellType.BALL)
		current_grid_pos = Vector2(x, y)
	else:
		current_grid_pos = Vector2(-1, -1)

# Function to switch ball type
func switch_ball_type(new_type):
	if new_type == current_ball_type:
		return  # Already using this ball type
	
	# Store the old type for reference
	var old_type = current_ball_type
	
	# Set the new ball type and update properties
	current_ball_type = new_type
	update_ball_properties()
	
	# Remove any ceiling stick timer if changing ball type
	if has_meta("ceiling_stick_time"):
		remove_meta("ceiling_stick_time")
	
	# Special behavior for teleport ball - swap with hole when switched to
	if new_type == Constants.BallType.TELEPORT:
		special_abilities.swap_with_hole()
	
	# Update the ball in the grid to show the new color
	update_ball_in_grid()
	
	# Emit signal for any listeners
	emit_signal("ball_type_changed", new_type)
	
	print("Switched from " + Constants.BALL_PROPERTIES[old_type].name + " to " + ball_properties.name)

# In Ball.gd, update the can_shoot() function to prevent shooting when surrounded by materials
func can_shoot():
	# Don't allow shooting if game is won
	if main_node and main_node.has_method("get") and main_node.get("game_won"):
		return false
		
	# Special case: if at bottom edge, allow shooting regardless of velocity
	if ball_position.y >= Constants.GRID_HEIGHT - 1.5:
		return true
	
	# For sticky ball, always allow shooting
	if current_ball_type == Constants.BallType.STICKY:
		return true
		
	# Use a higher threshold matching REST_THRESHOLD from Constants.gd
	return ball_velocity.length() < Constants.REST_THRESHOLD

# Function for creating an explosion
func create_explosion(radius):
	# Make sure the ball is properly cleared from the grid
	var x = int(ball_position.x)
	var y = int(ball_position.y)
	if sand_simulation:
		# Clear any ball cells that might be left behind
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var check_x = x + dx
				var check_y = y + dy
				if check_x >= 0 and check_x < Constants.GRID_WIDTH and check_y >= 0 and check_y < Constants.GRID_HEIGHT:
					if sand_simulation.get_cell(check_x, check_y) == Constants.CellType.BALL:
						sand_simulation.set_cell(check_x, check_y, Constants.CellType.EMPTY)
	
	# Let the special abilities handler create the fire cells
	if special_abilities:
		special_abilities.create_explosion(ball_position, radius)

func _draw():
	# Draw the larger pixelated rotating ball
	var world_position = Vector2(
		ball_position.x * Constants.GRID_SIZE,
		ball_position.y * Constants.GRID_SIZE
	)
	
	# Get ball color
	var ball_color = ball_properties.get("color", Constants.BALL_COLOR)
	
	# Draw the large rotating ball
	draw_large_rotating_ball(world_position, ball_color)
	
	# Draw aiming line when shooting
	if aiming_system:
		aiming_system.draw(self)

# Draw larger ball made of pixels that rotates as a cohesive unit
func draw_large_rotating_ball(position, base_color):
	# Main ball color
	var main_color = base_color
	
	# Create a slightly darker variant for pattern
	var pattern_color = Color(
		base_color.r * 0.7,
		base_color.g * 0.7,
		base_color.b * 0.7,
		base_color.a
	)
	
	# Create a lighter variant for highlights
	var highlight_color = Color(
		min(1.0, base_color.r * 1.3),
		min(1.0, base_color.g * 1.3),
		min(1.0, base_color.b * 1.3),
		base_color.a
	)
	
	# Center of the ball in world coordinates
	var center = Vector2(
		position.x + Constants.GRID_SIZE / 2,
		position.y + Constants.GRID_SIZE / 2
	)
	
	# Draw each pixel of the large ball
	for pixel in ball_pixels:
		# Apply rotation to the pixel offset
		var rotated_x = pixel.offset.x * cos(ball_rotation) - pixel.offset.y * sin(ball_rotation)
		var rotated_y = pixel.offset.x * sin(ball_rotation) + pixel.offset.y * cos(ball_rotation)
		var rotated_offset = Vector2(rotated_x, rotated_y)
		
		# Calculate pixel position after rotation
		var pixel_pos = center + rotated_offset
		
		# Determine color based on pattern
		var pixel_color
		if pixel.pattern:
			pixel_color = main_color
		else:
			pixel_color = pattern_color
		
		# Create a small 3D effect with highlight - top-left quadrant gets highlight
		var normalized_offset = rotated_offset.normalized()
		if normalized_offset.x < -0.3 and normalized_offset.y < -0.3:
			pixel_color = highlight_color
		
		# Draw pixel as a rectangle
		draw_rect(Rect2(
			pixel_pos - Vector2(pixel.size/2, pixel.size/2),
			Vector2(pixel.size, pixel.size)
		), pixel_color, true)
