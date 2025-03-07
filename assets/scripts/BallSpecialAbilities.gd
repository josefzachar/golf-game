class_name BallSpecialAbilities
extends RefCounted

# Reference to the main ball node
var ball = null

func _init(ball_reference):
	ball = ball_reference

# Explosive ball behavior
func explode():
	if ball.sand_simulation:
		print("BOOM! Explosive ball detonated!")
		var explosion_radius = ball.ball_properties.get("explosion_radius", 5.0)
		
		# Create multiple craters for a bigger explosion effect
		for i in range(3):
			var offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
			var crater_pos = ball.ball_position + offset
			var crater_size = explosion_radius * randf_range(0.8, 1.2)
			ball.sand_simulation.create_sand_crater(crater_pos, crater_size)
		
		# Reset to standard ball after explosion
		ball.call_deferred("switch_ball_type", Constants.BallType.STANDARD)

# Teleport ball behavior
func swap_with_hole():
	if ball.sand_simulation:
		print("Teleporting ball and hole!")
		var old_hole_position = ball.sand_simulation.get_hole_position()
		
		# Clear the ball from the grid
		var x = int(ball.ball_position.x)
		var y = int(ball.ball_position.y)
		ball.sand_simulation.set_cell(x, y, Constants.CellType.EMPTY)
		
		# Set the new hole position (where the ball was)
		ball.sand_simulation.hole_position = ball.ball_position
		
		# Set hole cells in the grid
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var hole_x = x + dx
				var hole_y = y + dy
				if hole_x >= 0 and hole_x < Constants.GRID_WIDTH and hole_y >= 0 and hole_y < Constants.GRID_HEIGHT:
					if Vector2(dx, dy).length() < 1.5:
						ball.sand_simulation.set_cell(hole_x, hole_y, Constants.CellType.HOLE)
		
		# Move the ball to the old hole position
		ball.ball_position = old_hole_position
		
		# Reset original hole cells in the grid
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var ball_x = ball.ball_position.x + dx
				var ball_y = ball.ball_position.y + dy
				if ball_x >= 0 and ball_x < Constants.GRID_WIDTH and ball_y >= 0 and ball_y < Constants.GRID_HEIGHT:
					if Vector2(dx, dy).length() < 1.5:
						ball.sand_simulation.set_cell(ball_x, ball_y, Constants.CellType.EMPTY)
			
		ball.ball_velocity = Vector2.ZERO  # Reset velocity after teleporting
		
		# Reset to standard ball after teleportation
		ball.call_deferred("switch_ball_type", Constants.BallType.STANDARD)
