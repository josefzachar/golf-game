class_name BallCollisionPhysics
extends RefCounted

# Reference to the main ball node
var ball = null
var material_physics = null

func _init(ball_reference):
	ball = ball_reference
	
	# Create material physics instance for material interactions
	material_physics = BallMaterialPhysics.new(ball)

func calculate_new_position():
	var new_ball_position = ball.ball_position + ball.ball_velocity * 0.1
	
	# Handle stone collisions
	if handle_stone_collisions(new_ball_position):
		return
	
	# Boundary check with bouncing
	if handle_boundary_collisions(new_ball_position):
		return
	
	# Check for materials in the path
	handle_material_collisions(new_ball_position)
	
	# Check if ball reached hole
	if new_ball_position.distance_to(ball.sand_simulation.get_hole_position()) < 2:
		ball.emit_signal("ball_in_hole")
		return
	
	# Update ball position
	ball.ball_position = new_ball_position

func handle_stone_collisions(new_ball_position):
	# SPECIAL COLLISION CHECK for stone and dirt (for non-heavy balls)
	# We'll look ahead along our path for stone blocks or dirt and treat them as rigid boundaries
	var path_check_steps = 5  # Check multiple steps along the path
	var collision = false
	var collision_normal = Vector2.ZERO
	var collision_pos = Vector2.ZERO
	
	for step in range(1, path_check_steps + 1):
		var check_fraction = float(step) / path_check_steps
		var check_pos = ball.ball_position + (new_ball_position - ball.ball_position) * check_fraction
		check_pos = Vector2(round(check_pos.x), round(check_pos.y))
		
		if check_pos.x >= 0 and check_pos.x < Constants.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < Constants.GRID_HEIGHT:
			var cell_type = ball.sand_simulation.get_cell(check_pos.x, check_pos.y)
			
			# For STONE, always treat as rigid boundary
			# For DIRT, only treat as rigid boundary if NOT a heavy ball
			if cell_type == Constants.CellType.STONE or (cell_type == Constants.CellType.DIRT and ball.current_ball_type != Constants.BallType.HEAVY):
				collision = true
				collision_pos = check_pos
				
				# Calculate the normal vector (direction from collision to ball)
				var dir_to_ball = (ball.ball_position - check_pos).normalized()
				
				# Determine the primary collision direction
				if abs(dir_to_ball.x) > abs(dir_to_ball.y):
					collision_normal = Vector2(sign(dir_to_ball.x), 0)
				else:
					collision_normal = Vector2(0, sign(dir_to_ball.y))
				
				break
	
	# If we found a collision, handle it like a wall boundary
	if collision:
		handle_stone_bounce(collision_normal, collision_pos, new_ball_position)
		return true
	
	return false

func handle_stone_bounce(stone_normal, stone_pos, new_ball_position):
	# Check if this is an explosive ball collision
	if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
		# Trigger explosion on collision with stone
		ball.special_abilities.explode()
		return
		
	# Get bounce properties based on velocity and ball type
	var bounce_factor = ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR)
	
	# Sticky ball doesn't bounce off stone, it sticks
	if ball.current_ball_type == Constants.BallType.STICKY:
		bounce_factor = 0.0
		
	# Check if we should use the anti-hover logic (only for low speeds)
	var is_low_velocity = ball.ball_velocity.length() < 1.2
		
	# If hitting from above, handle specially to prevent hovering
	if stone_normal.y < 0:  # Normal points upward (collision from above)
		new_ball_position.y = stone_pos.y - 1  # Position directly on stone
		
		# For sticky ball, always stop
		if ball.current_ball_type == Constants.BallType.STICKY:
			ball.ball_velocity = Vector2.ZERO
		else:
			# If velocity is low enough, just stop completely to prevent hovering
			if is_low_velocity:
				ball.ball_velocity = Vector2.ZERO  # Full stop for low velocities
			else:
				# For medium and high velocities, allow proper bouncing
				ball.ball_velocity.y = -ball.ball_velocity.y * bounce_factor
				
				# Apply MUCH stronger friction to horizontal movement
				ball.ball_velocity.x *= 0.75  # Increased friction (was 0.95)
	# For side collisions, normal bouncing or sticking
	elif stone_normal.x != 0:
		if ball.current_ball_type == Constants.BallType.STICKY:
			# Sticky ball stops at the stone boundary
			ball.ball_velocity = Vector2.ZERO
			# Position adjacent to stone
			new_ball_position.x = stone_pos.x + stone_normal.x
		else:
			# Reflect horizontal velocity with good bounce
			ball.ball_velocity.x = -ball.ball_velocity.x * bounce_factor
			
			# Position away from stone
			new_ball_position.x = stone_pos.x + stone_normal.x
	# For bottom collisions, normal bouncing or sticking
	else:
		if ball.current_ball_type == Constants.BallType.STICKY:
			# Sticky ball stops and sticks to ceiling
			ball.ball_velocity = Vector2.ZERO
			# Position adjacent to stone
			new_ball_position.y = stone_pos.y + stone_normal.y
		else:
			# Reflect vertical velocity with good bounce
			ball.ball_velocity.y = -ball.ball_velocity.y * bounce_factor
			
			# Position away from stone
			new_ball_position.y = stone_pos.y + stone_normal.y
	
	# Update the ball position here and exit
	ball.ball_position = new_ball_position
	
	# Place ball at new position
	var x = int(ball.ball_position.x)
	var y = int(ball.ball_position.y)
	ball.sand_simulation.set_cell(x, y, Constants.CellType.BALL)

func handle_boundary_collisions(new_ball_position):
	var bounced = false
	
	# Note: Explosive ball no longer explodes on boundary collision
	
	# Get bounce factor based on ball type
	var bounce_factor = ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR)
	
	# Check X boundaries
	if new_ball_position.x <= 0:
		new_ball_position.x = 0
		if ball.current_ball_type == Constants.BallType.STICKY:
			ball.ball_velocity = Vector2.ZERO  # Sticky ball sticks to boundary
		else:
			ball.ball_velocity.x = -ball.ball_velocity.x * bounce_factor
		bounced = true
	elif new_ball_position.x >= Constants.GRID_WIDTH - 1:
		new_ball_position.x = Constants.GRID_WIDTH - 1
		if ball.current_ball_type == Constants.BallType.STICKY:
			ball.ball_velocity = Vector2.ZERO  # Sticky ball sticks to boundary
		else:
			ball.ball_velocity.x = -ball.ball_velocity.x * bounce_factor
		bounced = true
		
	# Check Y boundaries
	if new_ball_position.y <= 0:
		new_ball_position.y = 0
		if ball.current_ball_type == Constants.BallType.STICKY:
			ball.ball_velocity = Vector2.ZERO  # Sticky ball sticks to ceiling
		else:
			ball.ball_velocity.y = -ball.ball_velocity.y * bounce_factor
		bounced = true
	elif new_ball_position.y >= Constants.GRID_HEIGHT - 1:
		new_ball_position.y = Constants.GRID_HEIGHT - 1
		if ball.current_ball_type == Constants.BallType.STICKY:
			ball.ball_velocity = Vector2.ZERO  # Sticky ball sticks to floor
		else:
			# Apply strong horizontal friction at the bottom edge
			ball.ball_velocity.x *= 0.8  # Add significant friction to horizontal movement
			
			# If moving slowly, stop completely to allow shooting
			if ball.ball_velocity.length() < 0.5:
				ball.ball_velocity = Vector2.ZERO
			else:
				ball.ball_velocity.y = -ball.ball_velocity.y * bounce_factor
		bounced = true
	
	# Create a small crater at boundary if bounced with enough force
	if bounced and ball.ball_velocity.length() > 1.0:
		create_impact_crater(new_ball_position)
	
	# Update the ball position if we bounced
	if bounced:
		ball.ball_position = new_ball_position
		return true
		
	return false

func create_impact_crater(position):
	var boundary_pos = Vector2(
		clamp(round(position.x), 0, Constants.GRID_WIDTH - 1),
		clamp(round(position.y), 0, Constants.GRID_HEIGHT - 1)
	)
	
	# Check if we're near sand to create a crater
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var check_pos = boundary_pos + dir
		if check_pos.x >= 0 and check_pos.x < Constants.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < Constants.GRID_HEIGHT:
			# ONLY affect sand or dirt, never stone
			var cell_type = ball.sand_simulation.get_cell(check_pos.x, check_pos.y)
			
			# Heavy ball creates larger craters
			var size_multiplier = 1.0
			var threshold_multiplier = 1.0
			
			if ball.current_ball_type == Constants.BallType.HEAVY:
				size_multiplier = 1.5
				threshold_multiplier = 0.7  # Lower threshold (easier to create craters)
			
			if cell_type == Constants.CellType.SAND:
				ball.sand_simulation.create_sand_crater(check_pos, ball.ball_velocity.length() * 0.2 * size_multiplier)
				return
			elif cell_type == Constants.CellType.DIRT and ball.ball_velocity.length() > 5.0 * threshold_multiplier:
				ball.sand_simulation.create_sand_crater(check_pos, ball.ball_velocity.length() * 0.02 * size_multiplier)
				return

func handle_material_collisions(new_ball_position):
	# Track if we should create a crater
	var create_crater = false
	var crater_pos = Vector2.ZERO
	var crater_size = 0.0
	
	# Get the direction of travel
	var travel_direction = ball.ball_velocity.normalized()
	
	# Check for materials in the path
	var sand_check_pos = Vector2(round(new_ball_position.x + travel_direction.x), 
								round(new_ball_position.y + travel_direction.y))
	
	# Main collision detection
	if sand_check_pos.x >= 0 and sand_check_pos.x < Constants.GRID_WIDTH and sand_check_pos.y >= 0 and sand_check_pos.y < Constants.GRID_HEIGHT:
		var cell_type = ball.sand_simulation.get_cell(sand_check_pos.x, sand_check_pos.y)
		var cell_properties = ball.sand_simulation.get_cell_properties(sand_check_pos.x, sand_check_pos.y)
		
		# Get ball mass and penetration factor
		var ball_mass = ball.ball_properties.get("mass", Constants.BALL_MASS)
		
		# NEVER interact with stone here - it's handled by the special stone collision above
		if cell_type == Constants.CellType.STONE:
			# Skip any interaction - stone is handled by the rigid boundary system
			pass
		elif cell_type == Constants.CellType.SAND and cell_properties:
			# Calculate impact force based on velocity, mass, and cell-specific mass
			var impact_force = ball.ball_velocity.length() * ball_mass / cell_properties.mass
			if ball.current_ball_type == Constants.BallType.HEAVY:
				impact_force *= ball.ball_properties.get("penetration_factor", 1.0)
			
			# Handle sand collision via material physics
			var sand_result = material_physics.handle_sand_collision(impact_force, cell_properties, sand_check_pos)
			if sand_result.create_crater:
				create_crater = true
				crater_pos = sand_check_pos
				crater_size = sand_result.crater_size
				
		elif cell_type == Constants.CellType.DIRT and cell_properties:
			# Calculate impact force based on velocity, mass, and cell-specific mass
			var impact_force = ball.ball_velocity.length() * ball_mass / cell_properties.mass
			if ball.current_ball_type == Constants.BallType.HEAVY:
				impact_force *= ball.ball_properties.get("penetration_factor", 1.0)
			
			# Handle dirt collision via material physics
			var dirt_result = material_physics.handle_dirt_collision(impact_force, cell_properties, sand_check_pos)
			if dirt_result.create_crater:
				create_crater = true
				crater_pos = sand_check_pos
				crater_size = dirt_result.crater_size
				
		elif cell_type == Constants.CellType.WATER and cell_properties:
			# Check if this is an explosive ball collision with water
			if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
				# Trigger explosion on collision with water
				ball.special_abilities.explode()
				return
			
			# Apply water resistance via material physics
			material_physics.apply_water_resistance(cell_properties)
	
	# Now check the standard 4 directions for additional collisions
	check_additional_collisions(new_ball_position, create_crater, crater_pos, crater_size)
	
	# Create the crater if needed - NEVER for stone
	if create_crater:
		# Additional safeguard - check if the crater position is not stone
		if crater_pos.x >= 0 and crater_pos.x < Constants.GRID_WIDTH and crater_pos.y >= 0 and crater_pos.y < Constants.GRID_HEIGHT:
			if ball.sand_simulation.get_cell(crater_pos.x, crater_pos.y) != Constants.CellType.STONE:
				ball.sand_simulation.create_sand_crater(crater_pos, crater_size)



func check_additional_collisions(new_ball_position, create_crater, crater_pos, crater_size):
	# This handles cases where the ball moves diagonally or bounces
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	
	for dir in directions:
		var check_pos = Vector2(round(new_ball_position.x + dir.x), round(new_ball_position.y + dir.y))
		if check_pos.x >= 0 and check_pos.x < Constants.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < Constants.GRID_HEIGHT:
			var cell_type = ball.sand_simulation.get_cell(check_pos.x, check_pos.y)
			var cell_properties = ball.sand_simulation.get_cell_properties(check_pos.x, check_pos.y)
			
			# Get bounce factor for this ball type
			var dir_bounce_factor = ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR)
			
			# Handle different cell types
			if cell_type == Constants.CellType.STONE:
				handle_stone_direction_collision(check_pos, dir, dir_bounce_factor)
				return  # Exit immediately for stone collision
				
			elif cell_type == Constants.CellType.DIRT:
				# For non-HEAVY balls, treat dirt exactly like stone
				if ball.current_ball_type != Constants.BallType.HEAVY:
					handle_stone_direction_collision(check_pos, dir, dir_bounce_factor)
					return  # Exit immediately for dirt collision (just like stone)
				else:
					# For HEAVY ball, use the existing dirt collision behavior
					handle_dirt_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater)
				
			elif cell_type == Constants.CellType.SAND and cell_properties:
				handle_sand_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater)
				
			elif cell_type == Constants.CellType.WATER and cell_properties:
				# Check if this is an explosive ball collision with water
				if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
					# Trigger explosion on collision with water
					ball.special_abilities.explode()
					return
					
				# Apply water resistance based on ball type
				material_physics.apply_water_resistance(cell_properties)

func handle_stone_direction_collision(check_pos, dir, dir_bounce_factor):
	# This is a failsafe in case stone was missed in earlier detection
	
	# Check if this is an explosive ball collision with stone
	if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
		# Trigger explosion on collision with stone
		ball.special_abilities.explode()
		return
	
	# Detect velocity to determine behavior
	var is_low_velocity = ball.ball_velocity.length() < 1.2
	
	if ball.current_ball_type == Constants.BallType.STICKY:
		# Sticky ball always stops when hitting stone
		ball.ball_velocity = Vector2.ZERO
		
		# Ensure proper position based on collision direction
		if dir.y > 0:  # Stone is below
			ball.ball_position.y = check_pos.y - 1
		elif dir.y < 0:  # Stone is above
			ball.ball_position.y = check_pos.y + 1
		elif dir.x != 0:  # Stone is to the side
			ball.ball_position.x = check_pos.x - dir.x
	else:
		if dir.y > 0:  # Stone is below
			if is_low_velocity:
				# Stop all movement for low velocities to prevent hovering
				ball.ball_velocity = Vector2.ZERO
			else:
				# Allow bounce for regular speeds
				ball.ball_velocity.y = -ball.ball_velocity.y * dir_bounce_factor * 1.2
			
			# Always position above stone
			ball.ball_position.y = check_pos.y - 1
		else:
			# For side or above collisions, use normal bouncing
			if dir.x != 0:
				ball.ball_velocity.x = -ball.ball_velocity.x * dir_bounce_factor * 1.2
			if dir.y < 0:
				ball.ball_velocity.y = -ball.ball_velocity.y * dir_bounce_factor * 1.2
	
	# Update position
	# Place ball at new position
	var x = int(ball.ball_position.x)
	var y = int(ball.ball_position.y)
	ball.sand_simulation.set_cell(x, y, Constants.CellType.BALL)

func handle_sand_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater):
	# Check if this is an explosive ball collision with sand
	if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
		# Trigger explosion on collision with sand
		ball.special_abilities.explode()
		return
		
	# Only create strong bounces for side or bottom collisions, not for top
	if ball.current_ball_type == Constants.BallType.STICKY:
		# Sticky ball stops when colliding with sand
		ball.ball_velocity = Vector2.ZERO
		
		# Position appropriately based on collision direction
		if dir.y > 0:  # Sand below
			ball.ball_position.y = check_pos.y - 1
	else:
		if dir.y < 0:  # Hitting sand from below (unlikely but possible)
			ball.ball_velocity.y = -ball.ball_velocity.y * dir_bounce_factor * cell_properties.dampening
		elif dir.y > 0 and ball.ball_velocity.y > 0.5:  # Hitting sand from above with significant downward motion
			ball.ball_velocity.y *= 0.5 * cell_properties.dampening  # Reduce downward movement but don't stop completely
			# Ensure we're above the sand
			ball.ball_position.y = check_pos.y - 1
	
	# Apply resistance based on mass and cell properties
	if ball.current_ball_type == Constants.BallType.HEAVY:
		# Heavy ball experiences less resistance
		ball.ball_velocity /= (1.0 + (Constants.SAND_RESISTANCE / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.05 * (cell_properties.mass / 1.0))
	else:
		ball.ball_velocity /= (1.0 + (Constants.SAND_RESISTANCE / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.1 * (cell_properties.mass / 1.0))
	
	# If we're moving fast, create additional craters
	if ball.ball_velocity.length() > 0.8 and not create_crater:
		material_physics.create_impact_crater(
			check_pos, 
			ball.ball_velocity.length() * (0.3 if ball.current_ball_type == Constants.BallType.HEAVY else 0.2) * Constants.SAND_DISPLACEMENT_FACTOR
		)

func handle_dirt_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater):
	# Check if this is an explosive ball collision with dirt
	if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
		# Trigger explosion on collision with dirt
		ball.special_abilities.explode()
		return
		
	# For HEAVY ball, keep existing behavior
	if ball.current_ball_type == Constants.BallType.HEAVY:
		handle_sand_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater)
	else:
		# For all other balls, treat dirt exactly like stone
		# This function now mirrors handle_stone_direction_collision for non-HEAVY balls
		
		# Detect velocity to determine behavior
		var is_low_velocity = ball.ball_velocity.length() < 1.2
		
		if ball.current_ball_type == Constants.BallType.STICKY:
			# Sticky ball always stops when hitting dirt
			ball.ball_velocity = Vector2.ZERO
			
			# Ensure proper position based on collision direction
			if dir.y > 0:  # Dirt is below
				ball.ball_position.y = check_pos.y - 1
			elif dir.y < 0:  # Dirt is above
				ball.ball_position.y = check_pos.y + 1
			elif dir.x != 0:  # Dirt is to the side
				ball.ball_position.x = check_pos.x - dir.x
		else:
			if dir.y > 0:  # Dirt is below
				if is_low_velocity:
					# Stop all movement for low velocities to prevent hovering
					ball.ball_velocity = Vector2.ZERO
				else:
					# Allow bounce for regular speeds
					ball.ball_velocity.y = -ball.ball_velocity.y * dir_bounce_factor * 1.2
				
				# Always position above dirt
				ball.ball_position.y = check_pos.y - 1
			else:
				# For side or above collisions, use normal bouncing
				if dir.x != 0:
					ball.ball_velocity.x = -ball.ball_velocity.x * dir_bounce_factor * 1.2
				if dir.y < 0:
					ball.ball_velocity.y = -ball.ball_velocity.y * dir_bounce_factor * 1.2
		
		# Update position
		# Place ball at new position
		var x = int(ball.ball_position.x)
		var y = int(ball.ball_position.y)
		ball.sand_simulation.set_cell(x, y, Constants.CellType.BALL)
