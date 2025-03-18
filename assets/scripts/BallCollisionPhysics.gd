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
				ball.sand_simulation.create_impact_crater(check_pos, ball.ball_velocity.length() * 0.2 * size_multiplier)
				return
			elif cell_type == Constants.CellType.DIRT and ball.ball_velocity.length() > 5.0 * threshold_multiplier:
				ball.sand_simulation.create_impact_crater(check_pos, ball.ball_velocity.length() * 0.02 * size_multiplier)
				return

func handle_material_collisions(new_ball_position):
	# Track if we should create a crater
	var create_crater = false
	var crater_pos = Vector2.ZERO
	var crater_size = 0.0
	
	# Get the direction of travel
	var travel_direction = ball.ball_velocity.normalized()
	
	# Check for materials in the path
	var check_pos = Vector2(round(new_ball_position.x + travel_direction.x), 
							round(new_ball_position.y + travel_direction.y))
	
	# Main collision detection
	if check_pos.x >= 0 and check_pos.x < Constants.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < Constants.GRID_HEIGHT:
		var cell_type = ball.sand_simulation.get_cell(check_pos.x, check_pos.y)
		var cell_properties = ball.sand_simulation.get_cell_properties(check_pos.x, check_pos.y)
		
		if cell_properties:
			# Get material type for universal handling
			var material_type = cell_properties.material_type
			
			# Get ball mass
			var ball_mass = ball.ball_properties.get("mass", Constants.BALL_MASS)
			
			# Calculate impact force based on velocity, mass, and cell properties
			var impact_force = ball.ball_velocity.length() * ball_mass / cell_properties.mass
			
			# Apply penetration factor for heavy ball
			if ball.current_ball_type == Constants.BallType.HEAVY:
				impact_force *= ball.ball_properties.get("penetration_factor", 1.0)
			
			# Check for explosive ball collision with any material
			if ball.current_ball_type == Constants.BallType.EXPLOSIVE and material_type != Constants.MaterialType.NONE:
				# Trigger explosion on collision with any material
				ball.special_abilities.explode()
				return
			
			# Handle collision based on material type
			var collision_result = material_physics.handle_material_collision(impact_force, cell_properties, check_pos)
			
			# Update crater info if needed
			if collision_result.create_crater:
				create_crater = true
				crater_pos = check_pos
				crater_size = collision_result.crater_size
	
	# Now check the standard 4 directions for additional collisions
	check_additional_collisions(new_ball_position, create_crater, crater_pos, crater_size)
	
	# Create the crater if needed
	if create_crater:
		# Additional safeguard - check if the crater position is valid
		if crater_pos.x >= 0 and crater_pos.x < Constants.GRID_WIDTH and crater_pos.y >= 0 and crater_pos.y < Constants.GRID_HEIGHT:
			var cell_type = ball.sand_simulation.get_cell(crater_pos.x, crater_pos.y)
			var cell_properties = ball.sand_simulation.get_cell_properties(crater_pos.x, crater_pos.y)
			
			# Only create craters in materials that allow displacement
			if cell_properties and cell_properties.displacement > 0:
				ball.sand_simulation.create_impact_crater(crater_pos, crater_size)



func check_additional_collisions(new_ball_position, create_crater, crater_pos, crater_size):
	# This handles cases where the ball moves diagonally or bounces
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	
	for dir in directions:
		var check_pos = Vector2(round(new_ball_position.x + dir.x), round(new_ball_position.y + dir.y))
		if check_pos.x >= 0 and check_pos.x < Constants.GRID_WIDTH and check_pos.y >= 0 and check_pos.y < Constants.GRID_HEIGHT:
			var cell_type = ball.sand_simulation.get_cell(check_pos.x, check_pos.y)
			var cell_properties = ball.sand_simulation.get_cell_properties(check_pos.x, check_pos.y)
			
			if not cell_properties:
				continue
				
			# Get bounce factor for this ball type
			var dir_bounce_factor = ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR)
			
			# Check if material_type property exists
			if not cell_properties.has("material_type"):
				# Fall back to handling based on cell type
				var current_cell_type = ball.sand_simulation.get_cell(check_pos.x, check_pos.y)
				
				if current_cell_type == Constants.CellType.STONE:
					handle_stone_direction_collision(check_pos, dir, dir_bounce_factor)
					return
				elif current_cell_type == Constants.CellType.DIRT:
					if ball.current_ball_type != Constants.BallType.HEAVY:
						handle_stone_direction_collision(check_pos, dir, dir_bounce_factor)
					else:
						handle_dirt_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater)
					return
				elif current_cell_type == Constants.CellType.SAND:
					handle_sand_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater)
					return
				elif current_cell_type == Constants.CellType.WATER:
					if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
						ball.special_abilities.explode()
						return
					material_physics.apply_water_resistance(cell_properties)
					return
				
				continue
			
			# Get material type for universal handling
			var material_type = cell_properties.material_type
			
			# Check for explosive ball collision with any material
			if ball.current_ball_type == Constants.BallType.EXPLOSIVE and material_type != Constants.MaterialType.NONE:
				# Trigger explosion on collision with any material
				ball.special_abilities.explode()
				return
			
			# Handle collision based on material type
			match material_type:
				Constants.MaterialType.SOLID:
					# Handle solid materials (stone, etc.)
					handle_solid_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties)
					return  # Exit immediately for solid collision
					
				Constants.MaterialType.GRANULAR:
					# For granular materials (sand, dirt, etc.)
					if cell_type == Constants.CellType.DIRT and ball.current_ball_type != Constants.BallType.HEAVY:
						# For non-HEAVY balls, treat dirt like a solid
						handle_solid_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties)
						return
					else:
						# For sand or HEAVY ball with dirt
						handle_granular_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater)
					
				Constants.MaterialType.LIQUID:
					# For liquid materials (water, etc.)
					# Apply resistance based on liquid properties
					material_physics.apply_material_resistance(cell_properties)

# Universal handler for solid materials (stone, ice, etc.)
func handle_solid_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties):
	# Check if this is an explosive ball collision
	if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
		# Trigger explosion on collision with solid
		ball.special_abilities.explode()
		return
	
	# Get elasticity from material properties
	var elasticity = cell_properties.elasticity
	var bounce_multiplier = 1.0 + elasticity * 0.5  # Higher elasticity = more bounce
	
	# Detect velocity to determine behavior
	var is_low_velocity = ball.ball_velocity.length() < 1.2
	
	if ball.current_ball_type == Constants.BallType.STICKY:
		# Sticky ball always stops when hitting solid materials
		ball.ball_velocity = Vector2.ZERO
		
		# Ensure proper position based on collision direction
		if dir.y > 0:  # Solid is below
			ball.ball_position.y = check_pos.y - 1
		elif dir.y < 0:  # Solid is above
			ball.ball_position.y = check_pos.y + 1
		elif dir.x != 0:  # Solid is to the side
			ball.ball_position.x = check_pos.x - dir.x
	else:
		if dir.y > 0:  # Solid is below
			if is_low_velocity:
				# Stop all movement for low velocities to prevent hovering
				ball.ball_velocity = Vector2.ZERO
			else:
				# Allow bounce for regular speeds, using material elasticity
				ball.ball_velocity.y = -ball.ball_velocity.y * dir_bounce_factor * bounce_multiplier
				
				# Apply friction to horizontal movement based on material properties
				ball.ball_velocity.x *= (1.0 - cell_properties.friction * 0.5)
			
			# Always position above solid
			ball.ball_position.y = check_pos.y - 1
		else:
			# For side or above collisions, use normal bouncing with material elasticity
			if dir.x != 0:
				ball.ball_velocity.x = -ball.ball_velocity.x * dir_bounce_factor * bounce_multiplier
			if dir.y < 0:
				ball.ball_velocity.y = -ball.ball_velocity.y * dir_bounce_factor * bounce_multiplier
	
	# Update position
	# Place ball at new position
	var x = int(ball.ball_position.x)
	var y = int(ball.ball_position.y)
	ball.sand_simulation.set_cell(x, y, Constants.CellType.BALL)

# Universal handler for granular materials (sand, dirt, etc.)
func handle_granular_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater):
	# Check if this is an explosive ball collision
	if ball.current_ball_type == Constants.BallType.EXPLOSIVE:
		# Trigger explosion on collision with granular material
		ball.special_abilities.explode()
		return
	
	# Get material properties
	var strength = cell_properties.strength
	var elasticity = cell_properties.elasticity
	var friction = cell_properties.friction
	
	# Only create strong bounces for side or bottom collisions, not for top
	if ball.current_ball_type == Constants.BallType.STICKY:
		# Sticky ball stops when colliding with granular materials
		ball.ball_velocity = Vector2.ZERO
		
		# Position appropriately based on collision direction
		if dir.y > 0:  # Material below
			ball.ball_position.y = check_pos.y - 1
	else:
		if dir.y < 0:  # Hitting from below (unlikely but possible)
			ball.ball_velocity.y = -ball.ball_velocity.y * dir_bounce_factor * elasticity
		elif dir.y > 0 and ball.ball_velocity.y > 0.5:  # Hitting from above with significant downward motion
			ball.ball_velocity.y *= 0.5 * cell_properties.dampening  # Reduce downward movement but don't stop completely
			# Ensure we're above the material
			ball.ball_position.y = check_pos.y - 1
	
	# Apply resistance based on material properties
	var resistance = cell_properties.density * friction
	
	if ball.current_ball_type == Constants.BallType.HEAVY:
		# Heavy ball experiences less resistance
		ball.ball_velocity /= (1.0 + (resistance / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.3)
	else:
		ball.ball_velocity /= (1.0 + (resistance / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.6)
	
	# If we're moving fast, create additional craters based on material displacement property
	if ball.ball_velocity.length() > 0.8 and not create_crater and cell_properties.displacement > 0:
		material_physics.create_impact_crater(
			check_pos, 
			ball.ball_velocity.length() * cell_properties.displacement * (0.3 if ball.current_ball_type == Constants.BallType.HEAVY else 0.2)
		)

# Backward compatibility functions
func handle_stone_direction_collision(check_pos, dir, dir_bounce_factor):
	var cell_properties = ball.sand_simulation.get_cell_properties(check_pos.x, check_pos.y)
	handle_solid_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties)

func handle_sand_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater):
	handle_granular_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater)

func handle_dirt_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater):
	if ball.current_ball_type == Constants.BallType.HEAVY:
		handle_granular_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties, create_crater)
	else:
		handle_solid_direction_collision(check_pos, dir, dir_bounce_factor, cell_properties)
