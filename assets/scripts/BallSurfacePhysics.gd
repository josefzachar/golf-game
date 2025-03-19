class_name BallSurfacePhysics
extends RefCounted

# Reference to the main ball node
var ball = null

func _init(ball_reference):
	ball = ball_reference

func handle_stone_detection():
	# First check if we're directly above stone with low velocity
	var stone_below = false
	var stone_y_pos = 0
	
	# Check up to 5 cells below for stone - more range to catch hovering at any height
	for check_y in range(int(ball.ball_position.y) + 1, int(ball.ball_position.y) + 6):
		if check_y < Constants.GRID_HEIGHT:
			if ball.sand_simulation.get_cell(int(ball.ball_position.x), check_y) == Constants.CellType.STONE:
				stone_below = true
				stone_y_pos = check_y
				break
	
	# If we found stone below us AND we have low velocity, force the ball to rest
	# Only do this for VERY low velocities - let normal bouncing happen at regular speeds
	if stone_below and ball.ball_velocity.length() < 1.2:  # Reduced from 2.0 to allow more bouncing
		# Force the ball to rest directly on top of the stone
		ball.ball_position.y = stone_y_pos - 1  # Position exactly on top of stone
		
		# Always set to very low velocity instead of zero to allow shooting
		ball.ball_velocity = Vector2(0, 0.01)  # Very tiny velocity to allow shooting
		
		# Update ball position in grid and exit immediately
		ball.update_ball_in_grid()
		return true  # Exit physics update - no more calculations needed
	
	# DIRT DETECTION - similar to stone but allowing for rolling
	return handle_dirt_detection()

func handle_dirt_detection():
	var dirt_below = false
	var dirt_y_pos = 0
	
	# Check if there's dirt below us (shorter range than stone)
	for check_y in range(int(ball.ball_position.y) + 1, int(ball.ball_position.y) + 3):
		if check_y < Constants.GRID_HEIGHT:
			if ball.sand_simulation.get_cell(int(ball.ball_position.x), check_y) == Constants.CellType.DIRT:
				dirt_below = true
				dirt_y_pos = check_y
				break
	
	# If we found dirt below us with low velocity, position the ball on the dirt
	# but allow for some rolling (don't zero the velocity completely)
	if dirt_below and ball.ball_velocity.length() < 1.0:
		# Position the ball on top of the dirt
		ball.ball_position.y = dirt_y_pos - 1
		
		# Different behavior based on ball type
		if ball.current_ball_type == Constants.BallType.STICKY:
			# For sticky ball, set to very low velocity instead of zero
			# This allows shooting while still sticking to the surface
			ball.ball_velocity = Vector2(0, 0.01)  # Very tiny velocity to allow shooting
		else:
			# Allow for rolling by preserving horizontal velocity with some friction
			ball.ball_velocity.y = 0  # Zero vertical velocity
			ball.ball_velocity.x *= 0.95  # Apply a small amount of friction
			
			# Only stop completely if velocity is extremely low
			if ball.ball_velocity.length() < 0.1:
				ball.ball_velocity = Vector2.ZERO
				
		# Update ball position in grid and continue with physics
		ball.update_ball_in_grid()
		# We don't return here, allowing the physics to continue
	
	return false  # Continue with normal physics

func handle_surface_physics():
	# Check if ball is resting on a surface
	var on_surface = false
	var check_pos_below = Vector2(round(ball.ball_position.x), round(ball.ball_position.y + 1))
	var surface_properties = null
	
	if check_pos_below.y < Constants.GRID_HEIGHT:
		var cell_below = ball.sand_simulation.get_cell(check_pos_below.x, check_pos_below.y)
		if cell_below == Constants.CellType.SAND or cell_below == Constants.CellType.DIRT or cell_below == Constants.CellType.STONE:
			on_surface = true
			surface_properties = ball.sand_simulation.get_cell_properties(check_pos_below.x, check_pos_below.y)
			
			# Handle different surface types
			match cell_below:
				Constants.CellType.STONE:
					if handle_stone_surface(check_pos_below):
						return true
				Constants.CellType.DIRT:
					handle_dirt_surface(check_pos_below)
			
			# If ball is moving very slowly and on a surface, let it rest
			if ball.ball_velocity.length() < Constants.REST_THRESHOLD:
				handle_rest_on_surface(check_pos_below)
			else:
				# Apply friction based on material type and its specific properties
				if surface_properties:
					apply_surface_friction(cell_below, surface_properties)
	
	return on_surface

func handle_stone_surface(check_pos_below):
	# Special handling for stone - always stay on top of it
	# Make sure we're positioned exactly on top of the stone (not hovering)
	ball.ball_position.y = check_pos_below.y - 1
	
	# Different behavior based on ball type
	if ball.current_ball_type == Constants.BallType.STICKY:
		# For sticky ball, preserve horizontal velocity but set a minimum vertical velocity
		# This allows the ball to be shot while still appearing to stick to the surface
		if ball.ball_velocity.length() < 0.1:  # Only if not already moving significantly
			ball.ball_velocity.y = 0.01  # Tiny value above zero to allow shooting
	else:
		# INCREASED FRICTION: Apply much stronger horizontal friction on stone
		if abs(ball.ball_velocity.x) > 0.1:
			# Apply strong friction based on velocity
			if abs(ball.ball_velocity.x) > 1.0:
				ball.ball_velocity.x *= 0.8  # Strong friction at higher speeds (was 0.99)
			else:
				ball.ball_velocity.x *= 0.7  # Even stronger friction at lower speeds
		
		# Stone has a lower rest threshold - comes to rest more easily
		if ball.ball_velocity.length() < Constants.REST_THRESHOLD * 2:
			# Come to a more natural stop with stronger friction
			ball.ball_velocity.y = 0  # No vertical movement
			
			# If velocity is now near zero, completely stop
			if ball.ball_velocity.length() < 0.2:
				ball.ball_velocity = Vector2.ZERO
				
				# Update ball position in grid and exit physics update
				ball.update_ball_in_grid()
				return true  # Exit physics update since we're resting on stone
				
	return false

func handle_dirt_surface(check_pos_below):
	# Special handling for dirt - make it behave similarly to stone but with better rolling
	# Make sure we're positioned exactly on top of the dirt
	ball.ball_position.y = check_pos_below.y - 1
	
	# Different behavior based on ball type
	if ball.current_ball_type == Constants.BallType.STICKY:
		# For sticky ball, preserve horizontal velocity but set a minimum vertical velocity
		# This allows the ball to be shot while still appearing to stick to the surface
		if ball.ball_velocity.length() < 0.1:  # Only if not already moving significantly
			ball.ball_velocity.y = 0.01  # Tiny value above zero to allow shooting
	else:
		# Apply moderate friction for nice rolling behavior
		if abs(ball.ball_velocity.x) > 0.1:
			# Apply friction based on velocity
			if abs(ball.ball_velocity.x) > 1.0:
				ball.ball_velocity.x *= 0.92  # Less friction than stone for better rolling
			else:
				ball.ball_velocity.x *= 0.88  # Less friction than stone for better rolling
		
		# Rest behavior allows for more rolling than stone
		if ball.ball_velocity.length() < Constants.REST_THRESHOLD * 1.5:
			ball.ball_velocity.y = 0  # Stop vertical movement
			
			# Only come to rest when extremely slow
			if ball.ball_velocity.length() < 0.1:  # Lower threshold than stone
				ball.ball_velocity = Vector2.ZERO

func handle_rest_on_surface(check_pos_below):
	# For sticky ball, use very small velocity instead of zero
	if ball.current_ball_type == Constants.BallType.STICKY:
		ball.ball_velocity = Vector2(0, 0.01)  # Very tiny velocity to allow shooting
	else:
		# Normal ball can rest at low speeds
		ball.ball_velocity = Vector2.ZERO
	
	# When at rest, ensure the ball sits on top of the surface, not inside it
	var rest_y = check_pos_below.y - 1
	if rest_y >= 0 and rest_y < Constants.GRID_HEIGHT:
		ball.ball_position.y = rest_y

func apply_surface_friction(cell_type, surface_properties):
	match cell_type:
		Constants.CellType.SAND:
			# Different friction for different ball types
			if ball.current_ball_type == Constants.BallType.STICKY:
				ball.ball_velocity.x *= 0.8 * surface_properties.dampening  # More friction for sticky
			elif ball.current_ball_type == Constants.BallType.HEAVY:
				ball.ball_velocity.x *= 0.98 * surface_properties.dampening  # Less friction for heavy
			else:
				# Sand has more friction - use cell-specific dampening
				ball.ball_velocity.x *= 0.95 * surface_properties.dampening
		Constants.CellType.DIRT:
			# Different friction for different ball types
			if ball.current_ball_type == Constants.BallType.STICKY:
				ball.ball_velocity.x *= 0.85  # More friction for sticky
			elif ball.current_ball_type == Constants.BallType.HEAVY:
				ball.ball_velocity.x *= 0.99  # Almost no friction for heavy
			else:
				# Dirt now has virtually no friction - maximizing rolling
				ball.ball_velocity.x *= 0.99  # Almost no friction
		Constants.CellType.STONE:
			# Different friction for different ball types
			if ball.current_ball_type == Constants.BallType.STICKY:
				ball.ball_velocity.x *= 0.7  # Much more friction for sticky
			elif ball.current_ball_type == Constants.BallType.HEAVY:
				ball.ball_velocity.x *= 0.9  # Less friction for heavy
			else:
				# Stone now has MORE friction
				ball.ball_velocity.x *= 0.85  # Much higher friction factor
