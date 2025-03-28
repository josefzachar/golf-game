class_name BallPhysics
extends RefCounted

# Reference to the main ball node
var ball = null

# Sub-systems for physics
var material_physics = null
var collision_physics = null
var surface_physics = null

func _init(ball_reference):
	ball = ball_reference
	
	# Initialize sub-components
	material_physics = BallMaterialPhysics.new(ball)
	collision_physics = BallCollisionPhysics.new(ball)
	surface_physics = BallSurfacePhysics.new(ball)

func update_physics():
	if not ball.sand_simulation:
		return
		
	# Skip physics update if the game is won
	if ball.main_node and ball.main_node.has_method("get") and ball.main_node.get("game_won"):
		return
		
	# EXTREMELY AGGRESSIVE STONE DETECTION - Delegate to surface physics
	if surface_physics.handle_stone_detection():
		return
	
	# Check if ball is in water - Delegate to material physics
	var x = int(ball.ball_position.x)
	var y = int(ball.ball_position.y)
	var in_water = material_physics.handle_water_physics(x, y)
	
	# Check if ball is resting on a surface - Delegate to surface physics
	var on_surface = surface_physics.handle_surface_physics()
	
	# Only apply gravity if not resting - Delegate to material physics
	material_physics.apply_gravity(on_surface, in_water)
	
	# Calculate new position (only if we have velocity)
	if ball.ball_velocity.length() > 0:
		# Delegate to collision physics
		collision_physics.calculate_new_position()
	
	# Update the ball's position in the grid using the optimized method
	ball.update_ball_in_grid()
