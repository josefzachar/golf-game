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
	
	# EXTREMELY AGGRESSIVE STONE DETECTION
	# First check if we're directly above stone with low velocity
	var stone_below = false
	var stone_y_pos = 0
	
	# Check up to 5 cells below for stone - more range to catch hovering at any height
	for check_y in range(int(ball_position.y) + 1, int(ball_position.y) + 6):
		if check_y < Constants.GRID_HEIGHT:
			if sand_simulation.get_cell(int(ball_position.x), check_y) == Constants.CellType.STONE:
				stone_below = true
				stone_y_pos = check_y
				break
	
	# If we found stone below us AND we have low velocity, force the ball to rest
	# Only do this for VERY low velocities - let normal bouncing happen at regular speeds
	if stone_below and ball_velocity.length() < 1.2:  # Reduced from 2.0 to allow more bouncing
		# Force the ball to rest directly on top of the stone
		ball_position.y = stone_y_pos - 1  # Position exactly on top of stone
		ball_velocity = Vector2.ZERO       # Complete stop - no velocity at all
		
		# Place ball at this position and exit immediately
		x = int(ball_position.x)
		y = int(ball_position.y)
		sand_simulation.set_cell(x, y, Constants.CellType.BALL)
		return  # Exit physics update - no more calculations needed
	
	# DIRT DETECTION - similar to stone but allowing for rolling
	var dirt_below = false
	var dirt_y_pos = 0
	
	# Check if there's dirt below us (shorter range than stone)
	for check_y in range(int(ball_position.y) + 1, int(ball_position.y) + 3):
		if check_y < Constants.GRID_HEIGHT:
			if sand_simulation.get_cell(int(ball_position.x), check_y) == Constants.CellType.DIRT:
				dirt_below = true
				dirt_y_pos = check_y
				break
	
	# If we found dirt below us with low velocity, position the ball on the dirt
	# but allow for some rolling (don't zero the velocity completely)
	if dirt_below and ball_velocity.length() < 1.0:
		# Position the ball on top of the dirt
		ball_position.y = dirt_y_pos - 1
		
		# Allow for rolling by preserving horizontal velocity with some friction
		ball_velocity.y = 0  # Zero vertical velocity
		ball_velocity.x *= 0.95  # Apply a small amount of friction
		
		# Only stop completely if velocity is extremely low
		if ball_velocity.length() < 0.1:
			ball_velocity = Vector2.ZERO
			
		# Place ball at this position and continue with physics
		x = int(ball_position.x)
		y = int(ball_position.y)
		sand_simulation.set_cell(x, y, Constants.CellType.BALL)
		# We don't return here, allowing the physics to continue
	
	# Continue with normal physics if we're not hovering over stone with low velocity
	
	# Check if ball is in water
	var in_water = false
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
		if sand_simulation.get_cell(x, y) == Constants.CellType.WATER:
			in_water = true
			# Get water cell properties
			var water_properties = sand_simulation.get_cell_properties(x, y)
			if water_properties:
				# Apply strong water resistance based on cell properties
				ball_velocity *= 0.85 * water_properties.dampening  # Immediate strong damping with cell-specific dampening
	
	# Check if ball is resting on a surface
	var on_surface = false
	var check_pos_below = Vector2(round(ball_position.x), round(ball_position.y + 1))
	var surface_properties = null
	
	if check_pos_below.y < Constants.GRID_HEIGHT:
		var cell_below = sand_simulation.get_cell(check_pos_below.x, check_pos_below.y)
		if cell_below == Constants.CellType.SAND or cell_below == Constants.CellType.DIRT or cell_below == Constants.CellType.STONE:
			on_surface = true
			surface_properties = sand_simulation.get_cell_properties(check_pos_below.x, check_pos_below.y)
			
			# Special handling for stone - always stay on top of it
			if cell_below == Constants.CellType.STONE:
				# Make sure we're positioned exactly on top of the stone (not hovering)
				ball_position.y = check_pos_below.y - 1
				
				# INCREASED FRICTION: Apply much stronger horizontal friction on stone
				if abs(ball_velocity.x) > 0.1:
					# Apply strong friction based on velocity
					if abs(ball_velocity.x) > 1.0:
						ball_velocity.x *= 0.8  # Strong friction at higher speeds (was 0.99)
					else:
						ball_velocity.x *= 0.7  # Even stronger friction at lower speeds
				
				# Stone has a lower rest threshold - comes to rest more easily
				if ball_velocity.length() < Constants.REST_THRESHOLD * 2:
					# Come to a more natural stop with stronger friction
					ball_velocity.y = 0  # No vertical movement
					
					# If velocity is now near zero, completely stop
					if ball_velocity.length() < 0.2:
						ball_velocity = Vector2.ZERO
						
						# Place ball at position and exit physics update
						x = int(ball_position.x)
						y = int(ball_position.y)
						sand_simulation.set_cell(x, y, Constants.CellType.BALL)
						return  # Exit physics update since we're resting on stone
			
			# Special handling for dirt - make it behave similarly to stone but with better rolling
			if cell_below == Constants.CellType.DIRT:
				# Make sure we're positioned exactly on top of the dirt
				ball_position.y = check_pos_below.y - 1
				
				# Apply moderate friction for nice rolling behavior
				if abs(ball_velocity.x) > 0.1:
					# Apply friction based on velocity
					if abs(ball_velocity.x) > 1.0:
						ball_velocity.x *= 0.92  # Less friction than stone for better rolling
					else:
						ball_velocity.x *= 0.88  # Less friction than stone for better rolling
				
				# Rest behavior allows for more rolling than stone
				if ball_velocity.length() < Constants.REST_THRESHOLD * 1.5:
					ball_velocity.y = 0  # Stop vertical movement
					
					# Only come to rest when extremely slow
					if ball_velocity.length() < 0.1:  # Lower threshold than stone
						ball_velocity = Vector2.ZERO
			
			# If ball is moving very slowly and on a surface, let it rest
			if ball_velocity.length() < Constants.REST_THRESHOLD:
				ball_velocity = Vector2.ZERO
				
				# When at rest, ensure the ball sits on top of the surface, not inside it
				var rest_y = check_pos_below.y - 1
				if rest_y >= 0 and rest_y < Constants.GRID_HEIGHT:
					ball_position.y = rest_y
			else:
				# Apply friction based on material type and its specific properties
				if surface_properties:
					match cell_below:
						Constants.CellType.SAND:
							# Sand has more friction - use cell-specific dampening
							ball_velocity.x *= 0.95 * surface_properties.dampening
						Constants.CellType.DIRT:
							# Dirt now has virtually no friction - maximizing rolling
							ball_velocity.x *= 0.99  # Almost no friction
						Constants.CellType.STONE:
							# Stone now has MORE friction - significantly reduced from 0.99
							ball_velocity.x *= 0.85  # Much higher friction factor
	
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
		
		# SPECIAL STONE COLLISION CHECK - do this before any other collision checks
		# We'll look ahead along our path for stone blocks and treat them as rigid boundaries
		var path_check_steps = 5  # Check multiple steps along the path
		var stone_collision = false
		var stone_normal = Vector2.ZERO
		var stone_pos = Vector2.ZERO
		
		for step in range(1, path_check_steps + 1):
			var check_fraction = float(step) / path_check_steps
			var check_pos = ball_position + (new_ball_position - ball_position) * check_fraction
			check_pos = Vector2(round(check_pos.x), round(check_pos.y))
			
			if check_pos.x >= 0 and check_pos.x < Constants.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < Constants.GRID_HEIGHT:
				if sand_simulation.get_cell(check_pos.x, check_pos.y) == Constants.CellType.STONE:
					stone_collision = true
					stone_pos = check_pos
					
					# Calculate the normal vector (direction from stone to ball)
					var dir_to_ball = (ball_position - check_pos).normalized()
					
					# Determine the primary collision direction
					if abs(dir_to_ball.x) > abs(dir_to_ball.y):
						stone_normal = Vector2(sign(dir_to_ball.x), 0)
					else:
						stone_normal = Vector2(0, sign(dir_to_ball.y))
					
					break
		
		# If we found a stone collision, handle it like a wall boundary
		if stone_collision:
			# Get bounce properties based on velocity
			var bounce_factor = Constants.BOUNCE_FACTOR * 1.2  # Good bounce but not too extreme
			
			# Check if we should use the anti-hover logic (only for low speeds)
			var is_low_velocity = ball_velocity.length() < 1.2
				
			# If hitting from above, handle specially to prevent hovering
			if stone_normal.y < 0:  # Normal points upward (collision from above)
				new_ball_position.y = stone_pos.y - 1  # Position directly on stone
				
				# If velocity is low enough, just stop completely to prevent hovering
				if is_low_velocity:
					ball_velocity = Vector2.ZERO  # Full stop for low velocities
				else:
					# For medium and high velocities, allow proper bouncing
					ball_velocity.y = -ball_velocity.y * bounce_factor
					
					# Apply MUCH stronger friction to horizontal movement
					ball_velocity.x *= 0.75  # Increased friction (was 0.95)
			# For side collisions, normal bouncing
			elif stone_normal.x != 0:
				# Reflect horizontal velocity with good bounce
				ball_velocity.x = -ball_velocity.x * bounce_factor
				
				# Position away from stone
				new_ball_position.x = stone_pos.x + stone_normal.x
			# For bottom collisions, normal bouncing
			else:
				# Reflect vertical velocity with good bounce
				ball_velocity.y = -ball_velocity.y * bounce_factor
				
				# Position away from stone
				new_ball_position.y = stone_pos.y + stone_normal.y
			
			# Update the ball position here and exit
			ball_position = new_ball_position
			
			# Place ball at new position
			x = int(ball_position.x)
			y = int(ball_position.y)
			sand_simulation.set_cell(x, y, Constants.CellType.BALL)
			return  # Exit immediately after stone collision
		
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
					# ONLY affect sand or dirt, never stone
					var cell_type = sand_simulation.get_cell(check_pos.x, check_pos.y)
					if cell_type == Constants.CellType.SAND:
						sand_simulation.create_sand_crater(check_pos, ball_velocity.length() * 0.2)
						crater_created = true
						break
					elif cell_type == Constants.CellType.DIRT and ball_velocity.length() > 5.0:  # Increased threshold for dirt
						sand_simulation.create_sand_crater(check_pos, ball_velocity.length() * 0.02)  # Smaller craters for dirt
						crater_created = true
						break
		
		# Track if we should create a crater
		var create_crater = false
		var crater_pos = Vector2.ZERO
		var crater_size = 0.0
		
		# Get the direction of travel
		var travel_direction = ball_velocity.normalized()
		
		# Check for materials in the path - SKIP THIS if we already handled stone collision
		var sand_check_pos = Vector2(round(new_ball_position.x + travel_direction.x), 
								round(new_ball_position.y + travel_direction.y))
		
		# Main collision detection
		if sand_check_pos.x >= 0 and sand_check_pos.x < Constants.GRID_WIDTH and sand_check_pos.y >= 0 and sand_check_pos.y < Constants.GRID_HEIGHT:
			var cell_type = sand_simulation.get_cell(sand_check_pos.x, sand_check_pos.y)
			var cell_properties = sand_simulation.get_cell_properties(sand_check_pos.x, sand_check_pos.y)
			
			# NEVER interact with stone here - it's handled by the special stone collision above
			if cell_type == Constants.CellType.STONE:
				# Skip any interaction - stone is handled by the rigid boundary system
				pass
			elif cell_type == Constants.CellType.SAND and cell_properties:
				# Calculate impact force based on velocity, mass, and cell-specific mass
				var impact_force = ball_velocity.length() * Constants.BALL_MASS / cell_properties.mass
				
				# If moving fast enough, plow through the sand
				if impact_force > 1.0:
					# Convert sand to empty
					sand_simulation.set_cell(sand_check_pos.x, sand_check_pos.y, Constants.CellType.EMPTY)
					
					# Slow down based on impact and cell properties, but maintain direction
					ball_velocity *= Constants.MOMENTUM_CONSERVATION * cell_properties.dampening
					
					# Create crater based on impact
					create_crater = true
					crater_pos = sand_check_pos
					crater_size = impact_force * 0.3 * Constants.SAND_DISPLACEMENT_FACTOR
				else:
					# For low-force impacts, we still want some bounce affected by cell properties
					if abs(travel_direction.y) > abs(travel_direction.x):
						# Vertical collision
						ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR * cell_properties.dampening
					else:
						# Horizontal collision
						ball_velocity.x = -ball_velocity.x * Constants.BOUNCE_FACTOR * cell_properties.dampening
					
					ball_velocity *= 0.8 * cell_properties.dampening
			elif cell_type == Constants.CellType.DIRT and cell_properties:
				# Calculate impact force based on velocity, mass, and cell-specific mass
				var impact_force = ball_velocity.length() * Constants.BALL_MASS / cell_properties.mass
				
				# Dirt now requires EXTREMELY high force to dig through - almost exactly like stone
				if impact_force > 15.0:  # DRASTICALLY increased threshold (was 8.0)
					# Convert dirt to empty only with extreme impacts
					sand_simulation.set_cell(sand_check_pos.x, sand_check_pos.y, Constants.CellType.EMPTY)
					
					# Very slight slowdown when passing through dirt
					ball_velocity *= Constants.MOMENTUM_CONSERVATION * cell_properties.dampening * 0.98
					
					# Create extremely tiny crater based on impact (much smaller than sand)
					create_crater = true
					crater_pos = sand_check_pos
					crater_size = impact_force * 0.008 * Constants.SAND_DISPLACEMENT_FACTOR  # Greatly reduced
				else:
					# For less forceful impacts, behave almost exactly like stone - solid bounce
					if abs(travel_direction.y) > abs(travel_direction.x):
						# Vertical collision - enhanced bounce like a firm surface
						ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR * 1.3 * cell_properties.dampening
					else:
						# Horizontal collision - enhanced bounce
						ball_velocity.x = -ball_velocity.x * Constants.BOUNCE_FACTOR * 1.3 * cell_properties.dampening
					
					# Even less velocity reduction (more conservation) - behave more like a solid
					ball_velocity *= 0.95 * cell_properties.dampening
			elif cell_type == Constants.CellType.WATER and cell_properties:
				# Apply water resistance based on cell-specific properties
				ball_velocity /= (1.0 + (Constants.WATER_RESISTANCE * 0.1 * cell_properties.dampening))
				
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
				var cell_type = sand_simulation.get_cell(check_pos.x, check_pos.y)
				var cell_properties = sand_simulation.get_cell_properties(check_pos.x, check_pos.y)
				
				# NEVER interact with stone here - it's handled by the special stone collision above
				if cell_type == Constants.CellType.STONE:
					# This is a failsafe in case stone was missed in earlier detection
					
					# Detect velocity to determine behavior
					var is_low_velocity = ball_velocity.length() < 1.2
					
					if dir.y > 0:  # Stone is below
						if is_low_velocity:
							# Stop all movement for low velocities to prevent hovering
							ball_velocity = Vector2.ZERO
						else:
							# Allow bounce for regular speeds
							ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR * 1.2
						
						# Always position above stone
						new_ball_position.y = check_pos.y - 1
					else:
						# For side or above collisions, use normal bouncing
						if dir.x != 0:
							ball_velocity.x = -ball_velocity.x * Constants.BOUNCE_FACTOR * 1.2
						if dir.y < 0:
							ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR * 1.2
					
					# Update position and exit
					ball_position = new_ball_position
					
					# Place ball at new position
					x = int(ball_position.x)
					y = int(ball_position.y)
					sand_simulation.set_cell(x, y, Constants.CellType.BALL)
					return  # Exit immediately for stone collision
				elif cell_type == Constants.CellType.SAND and cell_properties:
					# Only create strong bounces for side or bottom collisions, not for top
					if dir.y < 0:  # Hitting sand from below (unlikely but possible)
						ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR * cell_properties.dampening
					elif dir.y > 0 and ball_velocity.y > 0.5:  # Hitting sand from above with significant downward motion
						ball_velocity.y *= 0.5 * cell_properties.dampening  # Reduce downward movement but don't stop completely
						# Ensure we're above the sand
						new_ball_position.y = check_pos.y - 1
					
					# Apply resistance based on mass and cell properties
					ball_velocity /= (1.0 + (Constants.SAND_RESISTANCE / Constants.BALL_MASS) * 0.1 * (cell_properties.mass / 1.0))
					
					# If we're moving fast, create additional craters
					if ball_velocity.length() > 0.8 and not create_crater:
						create_crater = true
						crater_pos = check_pos
						crater_size = ball_velocity.length() * 0.2 * Constants.SAND_DISPLACEMENT_FACTOR
				elif cell_type == Constants.CellType.DIRT and cell_properties:
					# Similar bounce handling as stone but with different properties
					if dir.y < 0:  # Hitting dirt from below
						ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR * 1.3 * cell_properties.dampening  # Enhanced bounce
					elif dir.y > 0 and ball_velocity.y > 0.5:  # Hitting dirt from above
						# Lower velocity = more solid bounce like stone
						if ball_velocity.y < 1.5:
							ball_velocity.y = -ball_velocity.y * Constants.BOUNCE_FACTOR * 1.2 * cell_properties.dampening  # More bounce
						else:
							ball_velocity.y *= 0.7 * cell_properties.dampening  # Some absorption at high speeds
						# Ensure we're above the dirt
						new_ball_position.y = check_pos.y - 1
					
					# Apply extremely minimal resistance for effortless rolling on dirt
					ball_velocity /= (1.0 + (Constants.SAND_RESISTANCE * 0.05 / Constants.BALL_MASS) * 0.1 * (cell_properties.mass / 1.0))
					
					# Create smaller craters than sand and only with EXTREMELY high velocity
					if ball_velocity.length() > 12.0 and not create_crater:  # Much higher threshold
						create_crater = true
						crater_pos = check_pos
						crater_size = ball_velocity.length() * 0.01 * Constants.SAND_DISPLACEMENT_FACTOR  # Even smaller craters
				elif cell_type == Constants.CellType.WATER and cell_properties:
					# Apply strong water resistance on direct contact, based on cell properties
					ball_velocity /= (1.0 + (Constants.WATER_RESISTANCE / Constants.BALL_MASS) * 0.05 * cell_properties.dampening)
		
		# Create the crater if needed - NEVER for stone
		if create_crater:
			# Additional safeguard - check if the crater position is not stone
			if crater_pos.x >= 0 and crater_pos.x < Constants.GRID_WIDTH and crater_pos.y >= 0 and crater_pos.y < Constants.GRID_HEIGHT:
				if sand_simulation.get_cell(crater_pos.x, crater_pos.y) != Constants.CellType.STONE:
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
