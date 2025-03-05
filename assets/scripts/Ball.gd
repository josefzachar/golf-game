extends Node2D

# Variables
var grid = []  # Reference to the grid from SandSimulation
var ball_position = Vector2(50, 80)  # Default ball starting position in grid coordinates
var default_position = Vector2(50, 80)  # Store the default starting position
var ball_velocity = Vector2.ZERO
var is_shooting = false
var shot_start = Vector2.ZERO
var sand_simulation = null
var main_node = null

# Signals
signal ball_in_hole

func _ready():
	# Get references the old-fashioned way
	var parent = self.get_parent()
	main_node = parent
	if parent.has_node("SandSimulation"):
		sand_simulation = parent.get_node("SandSimulation")
		# Connect to the grid updated signal
		sand_simulation.connect("grid_updated", Callable(self, "_on_grid_updated"))
		
		# In Godot 4+, use a timer node instead of await
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = 0.1
		timer.timeout.connect(func(): update_ball_in_grid())
		add_child(timer)
		timer.start()

func _on_grid_updated(new_grid):
	grid = new_grid
	update_ball_physics()
	queue_redraw()  # Redraw (Godot 4.x)

func reset_position():
	ball_position = default_position
	ball_velocity = Vector2.ZERO
	is_shooting = false
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

func update_ball_physics():
	if not sand_simulation:
		return
		
	# Skip physics update if the game is won
	if main_node and main_node.has_method("get") and main_node.get("game_won"):
		return
		
	# Clear current ball position
	var x = int(ball_position.x)
	var y = int(ball_position.y)
	sand_simulation.set_cell(x, y, Constants.CellType.EMPTY)
	
	# Check if ball is in water
	var in_water = false
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
		if sand_simulation.get_cell(x, y) == Constants.CellType.WATER:
			in_water = true
			# Apply strong water resistance
			ball_velocity *= 0.85  # Immediate strong damping
	
	# Check if ball is resting on a surface
	var on_surface = false
	var check_pos_below = Vector2(round(ball_position.x), round(ball_position.y + 1))
	
	if check_pos_below.y < Constants.GRID_HEIGHT:
		var cell_below = sand_simulation.get_cell(check_pos_below.x, check_pos_below.y)
		if cell_below == Constants.CellType.SAND:
			on_surface = true
			
			# If ball is moving very slowly and on a surface, let it rest
			if ball_velocity.length() < Constants.REST_THRESHOLD:
				ball_velocity = Vector2.ZERO
				
				# When at rest, ensure the ball sits on top of the sand, not inside it
				var rest_y = check_pos_below.y - 1
				if rest_y >= 0 and rest_y < Constants.GRID_HEIGHT:
					ball_position.y = rest_y
			else:
				# Apply mild friction when in contact with sand but still moving
				ball_velocity.x *= 0.95  # Reduced horizontal friction
	
	# Only apply gravity if not resting
	if !on_surface or ball_velocity.length() >= Constants.REST_THRESHOLD:
		# Apply gravity scaled by mass, reduced in water
		var gravity_modifier = 1.0
		if in_water:
			gravity_modifier = 0.3  # Much reduced gravity in water
		ball_velocity.y += Constants.GRAVITY * 0.01 * Constants.BALL_MASS * gravity_modifier
	
	# Calculate new position (only if we have velocity)
	if ball_velocity.length() > 0:
		var new_ball_position = ball_position + ball_velocity * 0.1
		
		# Boundary check with bouncing
		var bounced = false
		
		# Check X boundaries
		if new_ball_position.x <= 0:
			new_ball_position.x = 0
			ball_velocity.x = -ball_velocity.x * Constants.BOUNCE_FACTOR
			bounced = true
		elif new_ball_position.x >= Constants.GRID_WIDTH - 1:
			new_ball_position.x = Constants.GRID_WIDTH - 1
			ball_velocity.x = -ball_velocity.x * Constants.BOUNCE_FACTOR
			bounced = true
			
		# Check Y boundaries
		if new_ball_position.y <= 0:
			new_ball_position.y = 0
			ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR
			bounced = true
		elif new_ball_position.y >= Constants.GRID_HEIGHT - 1:
			new_ball_position.y = Constants.GRID_HEIGHT - 1
			ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR
			bounced = true
		
		# Create a small crater at boundary if bounced with enough force
		if bounced and ball_velocity.length() > 1.0:
			var boundary_pos = Vector2(
				clamp(round(new_ball_position.x), 0, Constants.GRID_WIDTH - 1),
				clamp(round(new_ball_position.y), 0, Constants.GRID_HEIGHT - 1)
			)
			
			# Check if we're near sand to create a crater
			var crater_created = false
			for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var check_pos = boundary_pos + dir
				if check_pos.x >= 0 and check_pos.x < Constants.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < Constants.GRID_HEIGHT:
					if sand_simulation.get_cell(check_pos.x, check_pos.y) == Constants.CellType.SAND:
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
		if sand_check_pos.x >= 0 and sand_check_pos.x < Constants.GRID_WIDTH and sand_check_pos.y >= 0 and sand_check_pos.y < Constants.GRID_HEIGHT:
			if sand_simulation.get_cell(sand_check_pos.x, sand_check_pos.y) == Constants.CellType.SAND:
				# Calculate impact force based on velocity and mass
				var impact_force = ball_velocity.length() * Constants.BALL_MASS
				
				# If moving fast enough, plow through the sand
				if impact_force > 1.0:
					# Convert sand to empty
					sand_simulation.set_cell(sand_check_pos.x, sand_check_pos.y, Constants.CellType.EMPTY)
					
					# Slow down based on impact, but maintain direction
					ball_velocity *= Constants.MOMENTUM_CONSERVATION
					
					# Create crater based on impact
					create_crater = true
					crater_pos = sand_check_pos
					crater_size = impact_force * 0.3 * Constants.SAND_DISPLACEMENT_FACTOR
				else:
					# For low-force impacts, we still want some bounce
					if abs(travel_direction.y) > abs(travel_direction.x):
						# Vertical collision
						ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR
					else:
						# Horizontal collision
						ball_velocity.x = -ball_velocity.x * Constants.BOUNCE_FACTOR
					
					ball_velocity *= 0.8
			# Check for water cells
			elif sand_simulation.get_cell(sand_check_pos.x, sand_check_pos.y) == Constants.CellType.WATER:
				# Apply water resistance (much stronger than sand)
				ball_velocity /= (1.0 + (Constants.WATER_RESISTANCE * 0.1))
				
				# Create ripple effect in water (visual only)
				if randf() > 0.7 and ball_velocity.length() > 0.5:
					# Displace some water around the ball
					for dx in range(-1, 2):
						for dy in range(-1, 2):
							var water_pos = Vector2(sand_check_pos.x + dx, sand_check_pos.y + dy)
							if water_pos.x >= 0 and water_pos.x < Constants.GRID_WIDTH and water_pos.y >= 0 and water_pos.y < Constants.GRID_HEIGHT:
								if sand_simulation.get_cell(water_pos.x, water_pos.y) == Constants.CellType.EMPTY:
									sand_simulation.set_cell(water_pos.x, water_pos.y, Constants.CellType.WATER)
		
		# Now check the standard 4 directions for additional collisions
		# This handles cases where the ball moves diagonally or bounces
		var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		
		for dir in directions:
			var check_pos = Vector2(round(new_ball_position.x + dir.x), round(new_ball_position.y + dir.y))
			if check_pos.x >= 0 and check_pos.x < Constants.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < Constants.GRID_HEIGHT:
				if sand_simulation.get_cell(check_pos.x, check_pos.y) == Constants.CellType.SAND:
					# Only create strong bounces for side or bottom collisions, not for top
					if dir.y < 0:  # Hitting sand from below (unlikely but possible)
						ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR
					elif dir.y > 0 and ball_velocity.y > 0.5:  # Hitting sand from above with significant downward motion
						ball_velocity.y *= 0.5  # Reduce downward movement but don't stop completely
						# Ensure we're above the sand
						new_ball_position.y = check_pos.y - 1
					
					# Apply resistance based on mass
					ball_velocity /= (1.0 + (Constants.SAND_RESISTANCE / Constants.BALL_MASS) * 0.1)
					
					# If we're moving fast, create additional craters
					if ball_velocity.length() > 0.8 and not create_crater:
						create_crater = true
						crater_pos = check_pos
						crater_size = ball_velocity.length() * 0.2 * Constants.SAND_DISPLACEMENT_FACTOR
				
				elif sand_simulation.get_cell(check_pos.x, check_pos.y) == Constants.CellType.WATER:
					# Apply strong water resistance on direct contact
					ball_velocity /= (1.0 + (Constants.WATER_RESISTANCE / Constants.BALL_MASS) * 0.05)
		
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
	sand_simulation.set_cell(x, y, Constants.CellType.BALL)

func can_shoot():
	# Don't allow shooting if game is won
	if main_node and main_node.has_method("get") and main_node.get("game_won"):
		return false
	return ball_velocity.length() < 0.1

func start_shooting():
	is_shooting = true
	shot_start = get_global_mouse_position()

func end_shooting():
	is_shooting = false
	var end_point = get_global_mouse_position()
	var force = (shot_start - end_point) * 0.08
	ball_velocity = force

func _draw():
	# Draw the ball
	var x = ball_position.x
	var y = ball_position.y
	var rect = Rect2(x * Constants.GRID_SIZE, y * Constants.GRID_SIZE, Constants.GRID_SIZE, Constants.GRID_SIZE)
	draw_rect(rect, Constants.BALL_COLOR, true)
	
	# Draw aiming line when shooting
	if is_shooting:
		var start_point = ball_position * Constants.GRID_SIZE + Vector2(Constants.GRID_SIZE/2, Constants.GRID_SIZE/2)
		var end_point = get_global_mouse_position()
		
		# Calculate the distance from start to end point
		var distance = start_point.distance_to(end_point)
		
		# Determine the line length based on distance (power)
		# Maximum power at 200 pixels, match this with the aiming line length
		var max_distance = 600.0
		var line_length = min(distance, max_distance)
		
		# Get direction as a normalized vector
		var direction = (start_point - end_point).normalized()
		
		# Draw the line with length representing power
		draw_line(start_point, start_point + direction * line_length, Color(1, 0, 0), 2.0)
