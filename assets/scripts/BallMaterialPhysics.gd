class_name BallMaterialPhysics
extends RefCounted

# Reference to the main ball node
var ball = null

func _init(ball_reference):
	ball = ball_reference

# Generic function to handle any liquid material (water, lava, etc.)
func handle_liquid_physics(x, y):
	var in_liquid = false
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
		var cell_type = ball.sand_simulation.get_cell(x, y)
		var cell_properties = ball.sand_simulation.get_cell_properties(x, y)
		
		if cell_properties and cell_properties.has("material_type") and cell_properties.material_type == Constants.MaterialType.LIQUID:
			in_liquid = true
			
			# Special handling for sticky ball in liquids - float on surface
			if ball.current_ball_type == Constants.BallType.STICKY:
				# Find the highest liquid cell in this column to float on
				for check_y in range(y, 0, -1):
					var check_cell = ball.sand_simulation.get_cell(x, check_y)
					var check_props = ball.sand_simulation.get_cell_properties(x, check_y)
					if not check_props or check_props.material_type != Constants.MaterialType.LIQUID:
						# Position the ball just on top of the liquid
						ball.ball_position.y = check_y + 1
						# Set to very small velocity to allow shooting from water
						ball.ball_velocity.y = 0.01  # Tiny vertical velocity to allow shooting
						ball.ball_velocity.x *= (1.0 - cell_properties.friction * 0.1)  # Minimal friction
						break
			else:
				# Apply resistance based on liquid properties
				var resistance_factor = 1.0 - cell_properties.viscosity * 0.5
				
				# Heavy ball moves through liquids with less resistance
				if ball.current_ball_type == Constants.BallType.HEAVY:
					resistance_factor = 1.0 - cell_properties.viscosity * 0.3  # Less resistance
				
				ball.ball_velocity *= resistance_factor * cell_properties.dampening
	
	return in_liquid

# Backward compatibility function
func handle_water_physics(x, y):
	return handle_liquid_physics(x, y)

func apply_gravity(on_surface, in_liquid):
	# Only apply gravity if not resting
	if !on_surface or ball.ball_velocity.length() >= Constants.REST_THRESHOLD:
		# Apply gravity scaled by mass, reduced in liquids
		var gravity_modifier = 1.0
		
		if in_liquid:
			var cell_properties = ball.sand_simulation.get_cell_properties(
				int(ball.ball_position.x), int(ball.ball_position.y))
			
			if cell_properties:
				# Calculate buoyancy based on liquid density vs ball mass
				var ball_mass = ball.ball_properties.get("mass", Constants.BALL_MASS)
				var liquid_density = cell_properties.density
				
				if ball.current_ball_type == Constants.BallType.STICKY:
					gravity_modifier = 0.0  # No gravity for sticky ball in liquids (float)
				elif ball.current_ball_type == Constants.BallType.HEAVY:
					# Heavy ball sinks faster, but still affected by liquid density
					gravity_modifier = max(0.4, 1.0 - (liquid_density / ball_mass) * 0.5)
				else:
					# Normal buoyancy calculation
					gravity_modifier = max(0.1, 1.0 - (liquid_density / ball_mass) * 0.8)
		
		# Get ball mass from properties
		var ball_mass = ball.ball_properties.get("mass", Constants.BALL_MASS)
		
		# For sticky ball in mid-air (not on surface and not in liquid), apply normal gravity
		if ball.current_ball_type == Constants.BallType.STICKY and !on_surface and !in_liquid:
			# Make sure we're not slowing down in mid-air
			gravity_modifier = 1.0  # Full gravity for sticky ball in mid-air
		
		ball.ball_velocity.y += Constants.GRAVITY * 0.01 * ball_mass * gravity_modifier

# Apply resistance from any material based on its properties
func apply_material_resistance(cell_properties):
	if not cell_properties:
		return
		
	if not cell_properties.has("material_type"):
		return
		
	match cell_properties.material_type:
		Constants.MaterialType.LIQUID:
			apply_liquid_resistance(cell_properties)
		Constants.MaterialType.GRANULAR:
			apply_granular_resistance(cell_properties)
		Constants.MaterialType.SOLID:
			apply_solid_resistance(cell_properties)

# Apply resistance from liquid materials (water, lava, etc.)
func apply_liquid_resistance(cell_properties):
	if ball.current_ball_type == Constants.BallType.STICKY:
		# Sticky ball floats on liquids, almost no resistance to horizontal movement
		ball.ball_velocity.y = 0  # No vertical movement
		ball.ball_velocity.x *= (1.0 - cell_properties.friction * 0.1)  # Minimal horizontal resistance
	elif ball.current_ball_type == Constants.BallType.HEAVY:
		# Heavy ball experiences less liquid resistance
		var resistance = cell_properties.viscosity * cell_properties.friction
		ball.ball_velocity /= (1.0 + (resistance / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.5)
	else:
		# Standard ball - normal liquid resistance
		var resistance = cell_properties.viscosity * cell_properties.friction
		ball.ball_velocity /= (1.0 + (resistance / ball.ball_properties.get("mass", Constants.BALL_MASS)))

# Backward compatibility function
func apply_water_resistance(cell_properties):
	apply_liquid_resistance(cell_properties)

# Inner class to store collision results
class CollisionResult:
	var create_crater = false
	var crater_size = 0.0
	
	func _init(create_crater_value = false, crater_size_value = 0.0):
		create_crater = create_crater_value
		crater_size = crater_size_value

# Generic function to handle collision with any material
func handle_material_collision(impact_force, cell_properties, cell_pos):
	if not cell_properties or not cell_properties.has("material_type"):
		return CollisionResult.new()
		
	match cell_properties.material_type:
		Constants.MaterialType.LIQUID:
			return handle_liquid_collision(impact_force, cell_properties, cell_pos)
		Constants.MaterialType.GRANULAR:
			return handle_granular_collision(impact_force, cell_properties, cell_pos)
		Constants.MaterialType.SOLID:
			return handle_solid_collision(impact_force, cell_properties, cell_pos)
	
	return CollisionResult.new()

# Handle collision with granular materials (sand, dirt, etc.)
func handle_granular_collision(impact_force, cell_properties, cell_pos):
	var result = CollisionResult.new()
	
	# Store if this is a grass cell (top dirt)
	var is_grass = cell_properties.is_top_dirt if cell_properties.has("is_top_dirt") else false
	
	# Check if this is dirt (more rigid) or sand (softer)
	var is_dirt = false
	var cell_type = ball.sand_simulation.get_cell(cell_pos.x, cell_pos.y)
	if cell_type == Constants.CellType.DIRT:
		is_dirt = true
	
	# Calculate penetration threshold based on material strength
	var penetration_threshold = cell_properties.strength * 2.0
	
	# Make dirt much more rigid for standard and sticky balls
	if is_dirt:
		if ball.current_ball_type == Constants.BallType.STANDARD or ball.current_ball_type == Constants.BallType.STICKY:
			penetration_threshold *= 5.0  # Much higher threshold for dirt
	
	# Heavy ball has increased impact force
	var penetration_factor = 1.0
	if ball.current_ball_type == Constants.BallType.HEAVY:
		penetration_factor = ball.ball_properties.get("penetration_factor", 1.0)
		if not is_dirt:
			penetration_threshold *= 0.5  # Easier for heavy ball to penetrate (but only for sand, not dirt)
	
	# If moving fast enough or material is weak enough, penetrate the material
	if impact_force * penetration_factor > penetration_threshold:
		# Convert cell to empty
		ball.sand_simulation.set_cell(cell_pos.x, cell_pos.y, Constants.CellType.EMPTY)
		
		# Slow down based on impact and cell properties, but maintain direction
		var momentum_conservation = 1.0 - (cell_properties.density * cell_properties.friction * 0.1)
		
		if ball.current_ball_type == Constants.BallType.HEAVY:
			# Heavy ball maintains more momentum
			ball.ball_velocity *= momentum_conservation * cell_properties.dampening * 1.2
		else:
			ball.ball_velocity *= momentum_conservation * cell_properties.dampening
		
		# Create crater based on material displacement property
		result.create_crater = true
		result.crater_size = impact_force * cell_properties.displacement * (0.3 if ball.current_ball_type == Constants.BallType.HEAVY else 0.2)
	else:
		# For low-force impacts, bounce based on material elasticity
		if ball.current_ball_type == Constants.BallType.STICKY:
			# Sticky ball stops when hitting materials
			ball.ball_velocity = Vector2.ZERO
		else:
			# Bouncing behavior based on material elasticity
			var bounce_factor = ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR) * cell_properties.elasticity
			var travel_direction = ball.ball_velocity.normalized()
			
			if abs(travel_direction.y) > abs(travel_direction.x):
				# Vertical collision
				ball.ball_velocity.y = -ball.ball_velocity.y * bounce_factor
			else:
				# Horizontal collision
				ball.ball_velocity.x = -ball.ball_velocity.x * bounce_factor
			
			# Apply friction
			ball.ball_velocity *= (1.0 - cell_properties.friction * 0.2) * cell_properties.dampening
	
	# Preserve grass state if needed
	if is_grass and result.create_crater:
		# Try to preserve grass appearance in nearby cells
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var nx = cell_pos.x + dx
				var ny = cell_pos.y + dy
				if nx >= 0 and nx < Constants.GRID_WIDTH and ny >= 0 and ny < Constants.GRID_HEIGHT:
					var neighbor_cell = ball.sand_simulation.get_cell(nx, ny)
					if neighbor_cell == Constants.CellType.DIRT:
						var neighbor_props = ball.sand_simulation.get_cell_properties(nx, ny)
						if neighbor_props:
							neighbor_props.is_top_dirt = true
	
	return result

# Backward compatibility functions
func handle_sand_collision(impact_force, cell_properties, sand_check_pos):
	return handle_granular_collision(impact_force, cell_properties, sand_check_pos)

func handle_dirt_collision(impact_force, cell_properties, dirt_check_pos):
	return handle_granular_collision(impact_force, cell_properties, dirt_check_pos)

# Handle collision with solid materials (stone, ice, etc.)
func handle_solid_collision(impact_force, cell_properties, cell_pos):
	var result = CollisionResult.new()
	
	# Calculate penetration threshold based on material strength
	var penetration_threshold = cell_properties.strength * 5.0  # Very high for solids
	
	# Heavy ball has increased impact force
	var penetration_factor = 1.0
	if ball.current_ball_type == Constants.BallType.HEAVY:
		penetration_factor = ball.ball_properties.get("penetration_factor", 1.0)
	
	# Only extremely high impacts or special balls can penetrate solid materials
	if impact_force * penetration_factor > penetration_threshold:
		# Convert solid to empty only with extreme impacts
		ball.sand_simulation.set_cell(cell_pos.x, cell_pos.y, Constants.CellType.EMPTY)
		
		# Significant slowdown when breaking through solid
		ball.ball_velocity *= 0.5 * cell_properties.dampening
		
		# Create small crater
		result.create_crater = true
		result.crater_size = impact_force * 0.05  # Small crater even with high impact
	else:
		# Normal bounce behavior for solids
		if ball.current_ball_type == Constants.BallType.STICKY:
			# Sticky ball stops when hitting solids
			ball.ball_velocity = Vector2.ZERO
		else:
			# Strong bounce based on material elasticity
			var bounce_factor = ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR) * cell_properties.elasticity
			var travel_direction = ball.ball_velocity.normalized()
			
			if abs(travel_direction.y) > abs(travel_direction.x):
				# Vertical collision
				ball.ball_velocity.y = -ball.ball_velocity.y * bounce_factor
			else:
				# Horizontal collision
				ball.ball_velocity.x = -ball.ball_velocity.x * bounce_factor
			
			# Apply friction
			ball.ball_velocity *= (1.0 - cell_properties.friction * 0.1) * cell_properties.dampening
	
	return result

# Handle collision with liquid materials (water, lava, etc.)
func handle_liquid_collision(impact_force, cell_properties, cell_pos):
	var result = CollisionResult.new()
	
	# Apply resistance based on liquid properties
	apply_liquid_resistance(cell_properties)
	
	# Create splash effect based on impact force and liquid displacement
	if impact_force > 1.0:
		result.create_crater = true
		result.crater_size = impact_force * cell_properties.displacement * 0.3
	
	return result

# Apply resistance from granular materials (sand, dirt, etc.)
func apply_granular_resistance(cell_properties):
	var resistance = cell_properties.density * cell_properties.friction
	
	# For sticky ball, don't apply any resistance in mid-air
	if ball.current_ball_type == Constants.BallType.STICKY:
		# Only apply resistance if actually touching the material
		var x = int(ball.ball_position.x)
		var y = int(ball.ball_position.y)
		var cell_below = Vector2(x, y + 1)
		var is_on_material = false
		
		if cell_below.y < Constants.GRID_HEIGHT:
			var cell_type = ball.sand_simulation.get_cell(cell_below.x, cell_below.y)
			if cell_type == Constants.CellType.SAND or cell_type == Constants.CellType.DIRT:
				is_on_material = true
		
		# Only apply resistance if on material
		if is_on_material:
			ball.ball_velocity /= (1.0 + (resistance / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.6)
	elif ball.current_ball_type == Constants.BallType.HEAVY:
		# Heavy ball experiences less resistance
		ball.ball_velocity /= (1.0 + (resistance / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.3)
	else:
		ball.ball_velocity /= (1.0 + (resistance / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.6)

# Apply resistance from solid materials (stone, ice, etc.)
func apply_solid_resistance(cell_properties):
	var friction = cell_properties.friction
	
	if ball.current_ball_type == Constants.BallType.STICKY:
		# Sticky ball stops on solids
		ball.ball_velocity = Vector2.ZERO
	elif ball.current_ball_type == Constants.BallType.HEAVY:
		# Heavy ball maintains more momentum
		ball.ball_velocity *= (1.0 - friction * 0.3)
	else:
		ball.ball_velocity *= (1.0 - friction * 0.5)

func create_impact_crater(position, size):
	ball.sand_simulation.create_impact_crater(position, size)
