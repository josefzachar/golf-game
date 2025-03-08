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

# Explosion effect variables
var explosion_particles = []
var explosion_active = false
var explosion_timer = 0.0
var explosion_frames = []  # For storing predefined explosion frame patterns

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
	
	# Initialize explosion frame patterns
	_initialize_explosion_frames()
	
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
	
	# Update explosion particles
	if explosion_active:
		explosion_timer -= delta
		if explosion_timer <= 0:
			explosion_active = false
			explosion_particles.clear()
		else:
			# Update each particle
			for particle in explosion_particles:
				# Skip particles that haven't "appeared" yet based on delay
				if particle.delay > 0:
					particle.delay -= delta
					continue
					
				particle.pos += particle.vel * delta
				
				# Apply pixelated movement (snap to grid occasionally)
				if randf() > 0.7:
					var snap_size = Constants.GRID_SIZE / 2
					particle.pos.x = round(particle.pos.x / snap_size) * snap_size
					particle.pos.y = round(particle.pos.y / snap_size) * snap_size
				
				particle.lifetime -= delta
				
				# Fade out particle as lifetime decreases
				if particle.lifetime < 0.2:
					particle.color.a = particle.lifetime / 0.2  # Linear fade out
				
				if particle.lifetime <= 0:
					particle.color.a = 0  # Make invisible when lifetime ends
	
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

func update_ball_in_grid():
	if not sand_simulation:
		return
		
	# Clear any existing ball from the grid
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if sand_simulation.get_cell(x, y) == Constants.CellType.BALL:
				sand_simulation.set_cell(x, y, Constants.CellType.EMPTY)
	
	# Set the ball's position in the grid (since physics still uses a single cell)
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

# In Ball.gd, update the can_shoot() function to prevent shooting when surrounded by materials
func can_shoot():
	# Don't allow shooting if game is won
	if main_node and main_node.has_method("get") and main_node.get("game_won"):
		return false
		
	# Special case: if at bottom edge, allow shooting regardless of velocity
	if ball_position.y >= Constants.GRID_HEIGHT - 1.5:
		return true
		
	# Use a higher threshold matching REST_THRESHOLD from Constants.gd
	return ball_velocity.length() < Constants.REST_THRESHOLD

# Create predefined pixel-art explosion frames
func _initialize_explosion_frames():
	# Frame 1: Initial blast (center plus cardinal directions)
	var frame1 = [
		Vector2(0, 0),    # Center
		Vector2(1, 0),    # Right
		Vector2(-1, 0),   # Left
		Vector2(0, 1),    # Down
		Vector2(0, -1)    # Up
	]
	
	# Frame 2: Expanding diamond
	var frame2 = [
		Vector2(0, 0),    # Center
		Vector2(1, 0), Vector2(2, 0),  # Right
		Vector2(-1, 0), Vector2(-2, 0), # Left
		Vector2(0, 1), Vector2(0, 2),  # Down
		Vector2(0, -1), Vector2(0, -2), # Up
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1) # Diagonals
	]
	
	# Frame 3: Large pixelated circle/diamond
	var frame3 = []
	for x in range(-3, 4):
		for y in range(-3, 4):
			if abs(x) + abs(y) <= 4:  # Diamond shape
				frame3.append(Vector2(x, y))
	
	# Frame 4: Expanding with gaps (dispersing)
	var frame4 = []
	for x in range(-4, 5):
		for y in range(-4, 5):
			if abs(x) + abs(y) <= 6 and (abs(x) % 2 == 0 or abs(y) % 2 == 0):
				frame4.append(Vector2(x, y))
	
	# Store all frames
	explosion_frames = [frame1, frame2, frame3, frame4]

# Function for creating a pixel-art style explosion
func create_explosion(radius):
	# Reset explosion state
	explosion_particles.clear()
	explosion_active = true
	explosion_timer = 1.0  # Slightly longer duration for frame-by-frame effect
	
	# Pixel size for chunky pixels
	var pixel_size = Constants.GRID_SIZE / 2
	
	# Use the predefined frame patterns to create a more structured pixel explosion
	for frame_idx in range(explosion_frames.size()):
		var frame = explosion_frames[frame_idx]
		var frame_delay = frame_idx * 0.2  # Each frame appears with delay
		
		# Create particles for each position in this frame
		for pos in frame:
			# Scale position by radius
			var scaled_pos = pos * (radius / 3.0) * pixel_size
			
			# Determine color based on position and frame
			var color
			var dist = pos.length()
			
			if frame_idx == 0:
				# Center explosion - white/yellow
				color = Color(1.0, 1.0, 0.8, 0.9)
			elif frame_idx == 1:
				# Second frame - orange
				color = Color(1.0, 0.6, 0.1, 0.8)
			elif dist < 2:
				# Inner particles - red/orange
				color = Color(0.9, 0.3, 0.1, 0.8)
			else:
				# Outer particles - red to dark red
				color = Color(
					0.7 - dist * 0.05,  # Red decreases with distance
					0.2 - dist * 0.03,  # Green decreases with distance
					0.05,               # Minimal blue
					0.7                 # Alpha
				)
			
			# Each pixel has a slight random movement direction away from center
			var vel_scale = (5 - frame_idx) * 5  # Earlier frames move faster
			var movement_dir = pos.normalized() + Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
			
			# Create the particle
			var particle = {
				"pos": scaled_pos,
				"vel": movement_dir.normalized() * vel_scale,
				"size": pixel_size * randf_range(0.9, 1.1),  # Slightly varied sizes
				"color": color,
				"lifetime": 0.8 - frame_delay,  # Earlier frames last longer
				"delay": frame_delay  # When this particle appears
			}
			
			explosion_particles.append(particle)
	
	# Add some random debris particles
	for i in range(int(radius * 5)):
		var angle = randf() * 2 * PI
		var distance = randf() * radius * pixel_size
		
		# Calculate position (aligned to grid for pixel-art look)
		var pos = Vector2(
			round(cos(angle) * distance / pixel_size) * pixel_size,
			round(sin(angle) * distance / pixel_size) * pixel_size
		)
		
		# Add small debris particles with varied movement
		var particle = {
			"pos": pos,
			"vel": pos.normalized() * randf_range(10, 30),
			"size": pixel_size * randf_range(0.5, 1.0),
			"color": Color(0.6, 0.3, 0.1, 0.7),
			"lifetime": randf_range(0.4, 0.8),
			"delay": randf_range(0, 0.4)  # Random delay for staggered appearance
		}
		
		explosion_particles.append(particle)

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
	
	# Draw explosion particles
	if explosion_active:
		for particle in explosion_particles:
			# Skip particles in delay state
			if particle.delay > 0:
				continue
				
			if particle.color.a > 0:  # Only draw visible particles
				# Calculate world position
				var pos = Vector2(
					ball_position.x * Constants.GRID_SIZE,
					ball_position.y * Constants.GRID_SIZE
				) + particle.pos
				
				# Round position to grid for crisp pixel-art look
				pos.x = round(pos.x)
				pos.y = round(pos.y)
				
				# Draw as a perfect square for pixelated look
				var size = particle.size
				if particle.lifetime < 0.3:
					# Make pixels shrink slightly at the end
					size *= (particle.lifetime / 0.3)
				
				# Force size to be an even number for pixel-perfect rendering
				size = round(size / 2) * 2
				if size < 2:
					size = 2  # Minimum size
				
				# Create pixel-perfect rectangle
				var pixel_rect = Rect2(
					Vector2(pos.x - size/2, pos.y - size/2),
					Vector2(size, size)
				)
				
				# Draw perfect square
				draw_rect(pixel_rect, particle.color, true)
				
				# For larger particles, add a pixel-art border
				if size >= 6 and randf() > 0.5:
					var border_color = particle.color
					border_color.a *= 0.7
					draw_rect(pixel_rect, border_color, false, 1.0)

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
