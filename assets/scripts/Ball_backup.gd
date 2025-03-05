extends Node2D

# Constants
const GRID_SIZE = 8  # Size of each pixel cell
const GRAVITY = 50.0
const BALL_COLOR = Color(1.0, 1.0, 1.0)  # White ball
const BALL_MASS = 1.0  # Ball mass (higher value = heavier ball)
const BOUNCE_FACTOR = 0.5  # How bouncy the ball is (0-1) - reduced for less bouncing
const MOMENTUM_CONSERVATION = 0.85  # How much momentum is preserved when hitting sand (higher = more conservation)
const SAND_RESISTANCE = 5  # How much sand slows the ball (reduced to allow more movement)
const REST_THRESHOLD = 0.25  # Below this velocity magnitude, the ball will rest on surfaces
const SAND_DISPLACEMENT_FACTOR = 0.5  # How much sand spreads (higher = more spread)

# Variables
var grid = []  # Reference to the grid from SandSimulation
var ball_position = Vector2(50, 110)  # Ball starting position in grid coordinates
var ball_velocity = Vector2.ZERO
var is_shooting = false
var shot_start = Vector2.ZERO

# Cell types enum reference (needs to match SandSimulation.gd)
enum CellType {
	EMPTY = 0,
	SAND = 1,
	BALL = 2,
	HOLE = 3
}

# References to other nodes
var sand_simulation

# Signals
signal ball_in_hole

func _ready():
	# Get references
	sand_simulation = get_parent().get_node("SandSimulation")
	
	# Connect to the grid updated signal (Godot 4.x syntax)
	sand_simulation.grid_updated.connect(_on_grid_updated)
	
	# Wait a moment to ensure grid is initialized
	await get_tree().create_timer(0.1).timeout
	
	# Set initial ball position in the grid
	update_ball_in_grid()

func _on_grid_updated(new_grid):
	grid = new_grid
	update_ball_physics()
	queue_redraw()  # Redraw (Godot 4.x)

func reset_position():
	ball_position = Vector2(50, 50)
	ball_velocity = Vector2.ZERO
	is_shooting = false
	update_ball_in_grid()

func update_ball_in_grid():
	# Clear any existing ball from the grid
	for x in range(sand_simulation.GRID_WIDTH):
		for y in range(sand_simulation.GRID_HEIGHT):
			if sand_simulation.get_cell(x, y) == CellType.BALL:
				sand_simulation.set_cell(x, y, CellType.EMPTY)
	
	# Set the ball's position in the grid
	var x = int(ball_position.x)
	var y = int(ball_position.y)
	sand_simulation.set_cell(x, y, CellType.BALL)

func update_ball_physics():
	# Clear current ball position
	var x = int(ball_position.x)
	var y = int(ball_position.y)
	sand_simulation.set_cell(x, y, CellType.EMPTY)
	
	# Check if ball is resting on a surface
	var on_surface = false
	var check_pos_below = Vector2(round(ball_position.x), round(ball_position.y + 1))
	
	if check_pos_below.y < sand_simulation.GRID_HEIGHT:
		var cell_below = sand_simulation.get_cell(check_pos_below.x, check_pos_below.y)
		if cell_below == CellType.SAND:
			on_surface = true
			
			# If ball is moving very slowly and on a surface, let it rest
			if ball_velocity.length() < REST_THRESHOLD:
				ball_velocity = Vector2.ZERO
				
				# When at rest, ensure the ball sits on top of the sand, not inside it
				var rest_y = check_pos_below.y - 1
				if rest_y >= 0 and rest_y < sand_simulation.GRID_HEIGHT:
					ball_position.y = rest_y
			else:
				# Apply mild friction when in contact with sand but still moving
				ball_velocity.x *= 0.95  # Reduced horizontal friction
	
	# Only apply gravity if not resting
	if !on_surface or ball_velocity.length() >= REST_THRESHOLD:
		# Apply gravity scaled by mass
		ball_velocity.y += GRAVITY * 0.01 * BALL_MASS
	
	# Calculate new position (only if we have velocity)
	if ball_velocity.length() > 0:
		var new_ball_position = ball_position + ball_velocity * 0.1
		
		# Boundary check with bouncing
		var bounced = false
		
		# Check X boundaries
		if new_ball_position.x <= 0:
			new_ball_position.x = 0
			ball_velocity.x = -ball_velocity.x * BOUNCE_FACTOR
			bounced = true
		elif new_ball_position.x >= sand_simulation.GRID_WIDTH - 1:
			new_ball_position.x = sand_simulation.GRID_WIDTH - 1
			ball_velocity.x = -ball_velocity.x * BOUNCE_FACTOR
			bounced = true
			
		# Check Y boundaries
		if new_ball_position.y <= 0:
			new_ball_position.y = 0
			ball_velocity.y = -ball_velocity.y * BOUNCE_FACTOR
			bounced = true
		elif new_ball_position.y >= sand_simulation.GRID_HEIGHT - 1:
			new_ball_position.y = sand_simulation.GRID_HEIGHT - 1
			ball_velocity.y = -ball_velocity.y * BOUNCE_FACTOR
			bounced = true
		
		# Create a small crater at boundary if bounced with enough force
		if bounced and ball_velocity.length() > 1.0:
			var boundary_pos = Vector2(
				clamp(round(new_ball_position.x), 0, sand_simulation.GRID_WIDTH - 1),
				clamp(round(new_ball_position.y), 0, sand_simulation.GRID_HEIGHT - 1)
			)
			
			# Check if we're near sand to create a crater
			var crater_created = false
			for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var check_pos = boundary_pos + dir
				if check_pos.x >= 0 and check_pos.x < sand_simulation.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < sand_simulation.GRID_HEIGHT:
					if sand_simulation.get_cell(check_pos.x, check_pos.y) == CellType.SAND:
						sand_simulation.create_sand_crater(check_pos, ball_velocity.length() * 0.2)
						crater_created = true
						break
		
		# Track if we should create a crater
		var create_crater = false
		var crater_pos = Vector2.ZERO
		var crater_size = 0.0
		
		# Get the direction of travel
		var travel_direction = ball_velocity.normalized()
		
		# Check for sand in the path
		var sand_check_pos = Vector2(round(new_ball_position.x + travel_direction.x), 
									round(new_ball_position.y + travel_direction.y))
		
		# Main collision detection
		if sand_check_pos.x >= 0 and sand_check_pos.x < sand_simulation.GRID_WIDTH and sand_check_pos.y >= 0 and sand_check_pos.y < sand_simulation.GRID_HEIGHT:
			if sand_simulation.get_cell(sand_check_pos.x, sand_check_pos.y) == CellType.SAND:
				# Calculate impact force based on velocity and mass
				var impact_force = ball_velocity.length() * BALL_MASS
				
				# If moving fast enough, plow through the sand
				if impact_force > 1.0:
					# Convert sand to empty
					sand_simulation.set_cell(sand_check_pos.x, sand_check_pos.y, CellType.EMPTY)
					
					# Slow down based on impact, but maintain direction
					ball_velocity *= MOMENTUM_CONSERVATION
					
					# Create crater based on impact
					create_crater = true
					crater_pos = sand_check_pos
					crater_size = impact_force * 0.3 * SAND_DISPLACEMENT_FACTOR
				else:
					# For low-force impacts, we still want some bounce
					if abs(travel_direction.y) > abs(travel_direction.x):
						# Vertical collision
						ball_velocity.y = -ball_velocity.y * BOUNCE_FACTOR
					else:
						# Horizontal collision
						ball_velocity.x = -ball_velocity.x * BOUNCE_FACTOR
					
					ball_velocity *= 0.8
		
		# Now check the standard 4 directions for additional collisions
		# This handles cases where the ball moves diagonally or bounces
		var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		
		for dir in directions:
			var check_pos = Vector2(round(new_ball_position.x + dir.x), round(new_ball_position.y + dir.y))
			if check_pos.x >= 0 and check_pos.x < sand_simulation.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < sand_simulation.GRID_HEIGHT:
				if sand_simulation.get_cell(check_pos.x, check_pos.y) == CellType.SAND:
					# Only create strong bounces for side or bottom collisions, not for top
					if dir.y < 0:  # Hitting sand from below (unlikely but possible)
						ball_velocity.y = -ball_velocity.y * BOUNCE_FACTOR
					elif dir.y > 0 and ball_velocity.y > 0.5:  # Hitting sand from above with significant downward motion
						ball_velocity.y *= 0.5  # Reduce downward movement but don't stop completely
						# Ensure we're above the sand
						new_ball_position.y = check_pos.y - 1
					
					# Apply resistance based on mass
					ball_velocity /= (1.0 + (SAND_RESISTANCE / BALL_MASS) * 0.1)
					
					# If we're moving fast, create additional craters
					if ball_velocity.length() > 0.8 and not create_crater:
						create_crater = true
						crater_pos = check_pos
						crater_size = ball_velocity.length() * 0.25 * SAND_DISPLACEMENT_FACTOR
		
		# Create the crater if needed
		if create_crater:
			sand_simulation.create_sand_crater(crater_pos, crater_size)
		
		# Check if ball reached hole
		if new_ball_position.distance_to(sand_simulation.get_hole_position()) < 2:
			emit_signal("ball_in_hole")
			return
		
		# Update ball position
		ball_position = new_ball_position
	
	# Place ball at new position
	x = int(ball_position.x)
	y = int(ball_position.y)
	sand_simulation.set_cell(x, y, CellType.BALL)

func can_shoot():
	return ball_velocity.length() < 0.1

func start_shooting():
	is_shooting = true
	shot_start = get_global_mouse_position()

func end_shooting():
	is_shooting = false
	var end_point = get_global_mouse_position()
	var force = (shot_start - end_point) * 0.05
	ball_velocity = force

func _draw():
	# Draw the ball
	var x = ball_position.x
	var y = ball_position.y
	var rect = Rect2(x * GRID_SIZE, y * GRID_SIZE, GRID_SIZE, GRID_SIZE)
	draw_rect(rect, BALL_COLOR, true)
	
	# Draw aiming line when shooting
	if is_shooting:
		var start_point = ball_position * GRID_SIZE + Vector2(GRID_SIZE/2, GRID_SIZE/2)
		var end_point = get_global_mouse_position()
		var direction = (start_point - end_point).normalized() * min(start_point.distance_to(end_point), 100)
		draw_line(start_point, start_point + direction, Color(1, 0, 0), 2.0)
