class_name BallMaterialPhysics
extends RefCounted

# Reference to the main ball node
var ball = null

func _init(ball_reference):
	ball = ball_reference

func handle_water_physics(x, y):
	var in_water = false
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
		if ball.sand_simulation.get_cell(x, y) == Constants.CellType.WATER:
			in_water = true
			
			# Special handling for sticky ball in water - float on surface
			if ball.current_ball_type == Constants.BallType.STICKY:
				# Find the highest water cell in this column to float on
				for check_y in range(y, 0, -1):
					if ball.sand_simulation.get_cell(x, check_y) != Constants.CellType.WATER:
						# Position the ball just on top of the water
						ball.ball_position.y = check_y + 1
						ball.ball_velocity.y = 0  # No vertical movement
						ball.ball_velocity.x *= 0.98  # Slight friction for horizontal movement
						break
			else:
				# Get water cell properties
				var water_properties = ball.sand_simulation.get_cell_properties(x, y)
				if water_properties:
					# Apply strong water resistance based on cell properties
					var resistance_factor = 0.85
					
					# Heavy ball moves through water with less resistance
					if ball.current_ball_type == Constants.BallType.HEAVY:
						resistance_factor = 0.95  # Less resistance
					
					ball.ball_velocity *= resistance_factor * water_properties.dampening
	
	return in_water

func apply_gravity(on_surface, in_water):
	# Only apply gravity if not resting
	if !on_surface or ball.ball_velocity.length() >= Constants.REST_THRESHOLD:
		# Apply gravity scaled by mass, reduced in water
		var gravity_modifier = 1.0
		if in_water:
			if ball.current_ball_type == Constants.BallType.STICKY:
				gravity_modifier = 0.0  # No gravity for sticky ball in water (float)
			elif ball.current_ball_type == Constants.BallType.HEAVY:
				gravity_modifier = 0.6  # More gravity for heavy ball in water (sink faster)
			else:
				gravity_modifier = 0.3  # Normal reduced gravity in water
		
		# Get ball mass from properties
		var ball_mass = ball.ball_properties.get("mass", Constants.BALL_MASS)
		ball.ball_velocity.y += Constants.GRAVITY * 0.01 * ball_mass * gravity_modifier

# Functions for handling specific material interactions

func apply_water_resistance(cell_properties):
	# Apply water resistance based on ball type
	if ball.current_ball_type == Constants.BallType.STICKY:
		# Sticky ball floats on water, almost no resistance to horizontal movement
		ball.ball_velocity.y = 0  # No vertical movement
		ball.ball_velocity.x *= 0.98  # Minimal horizontal resistance
	elif ball.current_ball_type == Constants.BallType.HEAVY:
		# Heavy ball experiences less water resistance
		ball.ball_velocity /= (1.0 + (Constants.WATER_RESISTANCE / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.03 * cell_properties.dampening)
	else:
		# Standard ball - normal water resistance
		ball.ball_velocity /= (1.0 + (Constants.WATER_RESISTANCE / ball.ball_properties.get("mass", Constants.BALL_MASS)) * 0.05 * cell_properties.dampening)

# Inner class to store sand collision results
class SandCollisionResult:
	var create_crater = false
	var crater_size = 0.0
	
	func _init(create_crater_value = false, crater_size_value = 0.0):
		create_crater = create_crater_value
		crater_size = crater_size_value

func handle_sand_collision(impact_force, cell_properties, sand_check_pos):
	var result = SandCollisionResult.new()
	
	# Heavy ball has increased impact force
	var penetration_factor = 1.0
	if ball.current_ball_type == Constants.BallType.HEAVY:
		penetration_factor = ball.ball_properties.get("penetration_factor", 1.0)
	
	# If moving fast enough, plow through the sand
	if impact_force > 1.0 or ball.current_ball_type == Constants.BallType.HEAVY:
		# Convert sand to empty
		ball.sand_simulation.set_cell(sand_check_pos.x, sand_check_pos.y, Constants.CellType.EMPTY)
		
		# Slow down based on impact and cell properties, but maintain direction
		if ball.current_ball_type == Constants.BallType.HEAVY:
			# Heavy ball maintains more momentum through sand
			ball.ball_velocity *= (Constants.MOMENTUM_CONSERVATION + 0.1) * cell_properties.dampening
		else:
			ball.ball_velocity *= Constants.MOMENTUM_CONSERVATION * cell_properties.dampening
		
		result.create_crater = true
		result.crater_size = impact_force * (0.3 if ball.current_ball_type == Constants.BallType.HEAVY else 0.2) * Constants.SAND_DISPLACEMENT_FACTOR
	else:
		# For low-force impacts, we still want some bounce affected by cell properties
		if ball.current_ball_type == Constants.BallType.STICKY:
			# Sticky ball stops when hitting sand
			ball.ball_velocity = Vector2.ZERO
		else:
			# Standard bouncing behavior
			var travel_direction = ball.ball_velocity.normalized()
			if abs(travel_direction.y) > abs(travel_direction.x):
				# Vertical collision
				ball.ball_velocity.y = -ball.ball_velocity.y * ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR) * cell_properties.dampening
			else:
				# Horizontal collision
				ball.ball_velocity.x = -ball.ball_velocity.x * ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR) * cell_properties.dampening
			
			ball.ball_velocity *= 0.8 * cell_properties.dampening
	
	return result

# Inner class to store dirt collision results
class DirtCollisionResult:
	var create_crater = false
	var crater_size = 0.0
	
	func _init(create_crater_value = false, crater_size_value = 0.0):
		create_crater = create_crater_value
		crater_size = crater_size_value

func handle_dirt_collision(impact_force, cell_properties, sand_check_pos):
	var result = DirtCollisionResult.new()
	
	# Calculate impact force based on velocity, mass, and cell-specific mass
	var penetration_factor = 1.0
	if ball.current_ball_type == Constants.BallType.HEAVY:
		penetration_factor = ball.ball_properties.get("penetration_factor", 1.0)
	
	# For HEAVY ball - same behavior as before
	if ball.current_ball_type == Constants.BallType.HEAVY:
		# Threshold for penetrating dirt (only for HEAVY ball)
		var dirt_threshold = 12.0
		
		# Only heavy ball can dig through dirt with high impact
		if impact_force > dirt_threshold:
			# Convert dirt to empty only with extreme impacts
			ball.sand_simulation.set_cell(sand_check_pos.x, sand_check_pos.y, Constants.CellType.EMPTY)
			
			# Significant slowdown when passing through dirt
			ball.ball_velocity *= Constants.MOMENTUM_CONSERVATION * cell_properties.dampening * 0.85
			
			# Create small crater
			result.create_crater = true
			result.crater_size = impact_force * 0.01 * Constants.SAND_DISPLACEMENT_FACTOR
		else:
			# For less forceful impacts, solid bounce
			var travel_direction = ball.ball_velocity.normalized()
			if abs(travel_direction.y) > abs(travel_direction.x):
				ball.ball_velocity.y = -ball.ball_velocity.y * ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR) * 1.3 * cell_properties.dampening
			else:
				ball.ball_velocity.x = -ball.ball_velocity.x * ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR) * 1.3 * cell_properties.dampening
			
			ball.ball_velocity *= 0.95 * cell_properties.dampening
	else:
		# For ALL OTHER BALLS - treat dirt exactly like stone (no penetration)
		if ball.current_ball_type == Constants.BallType.STICKY:
			# Sticky ball stops when hitting dirt
			ball.ball_velocity = Vector2.ZERO
		else:
			# Strong bounce just like stone
			var travel_direction = ball.ball_velocity.normalized()
			if abs(travel_direction.y) > abs(travel_direction.x):
				ball.ball_velocity.y = -ball.ball_velocity.y * ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR) * 1.3 * cell_properties.dampening
			else:
				ball.ball_velocity.x = -ball.ball_velocity.x * ball.ball_properties.get("bounce_factor", Constants.BOUNCE_FACTOR) * 1.3 * cell_properties.dampening
			
			ball.ball_velocity *= 0.95 * cell_properties.dampening
	
	return result

func create_impact_crater(position, size):
	ball.sand_simulation.create_sand_crater(position, size)
