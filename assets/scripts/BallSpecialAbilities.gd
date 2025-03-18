class_name BallSpecialAbilities
extends RefCounted

# Reference to the main ball node
var ball = null

func _init(ball_reference):
	ball = ball_reference

# Main explosion function called by Ball.gd
func explode():
	if ball.sand_simulation:
		print("BOOM! Explosion detonated!")
		
		# Get explosion radius from ball properties
		var explosion_radius = ball.ball_properties.get("explosion_radius", 12.0) * 2.0  # Double the radius
		
		# Create the explosion
		create_explosion(ball.ball_position, explosion_radius)
		
		# Reset to standard ball after explosion
		ball.call_deferred("switch_ball_type", Constants.BallType.STANDARD)

# Create an explosion with fire cells
func create_explosion(position, radius):
	# Create a central crater
	ball.sand_simulation.create_impact_crater(position, radius * 1.2)
	
	# Create a ball of fire cells
	var explosion_radius = radius * 1.5  # Slightly larger than the crater
	
	# Loop through a square area around the explosion center
	for x in range(int(position.x - explosion_radius), int(position.x + explosion_radius + 1)):
		for y in range(int(position.y - explosion_radius), int(position.y + explosion_radius + 1)):
			# Skip out-of-bounds cells
			if x < 0 or x >= Constants.GRID_WIDTH or y < 0 or y >= Constants.GRID_HEIGHT:
				continue
				
			# Calculate distance from explosion center
			var distance = Vector2(x, y).distance_to(position)
			
			# Only process cells within the explosion radius
			if distance <= explosion_radius:
				# Get current cell type
				var cell_type = ball.sand_simulation.get_cell(x, y)
				
				# Don't modify stone or ball cells
				if cell_type != Constants.CellType.STONE and cell_type != Constants.CellType.BALL:
					# Higher chance of fire near the center, lower at the edges
					var fire_chance = 0.8 * (1.0 - distance / explosion_radius)
					
					if randf() < fire_chance:
						# Create a fire cell
						ball.sand_simulation.set_cell(x, y, Constants.CellType.FIRE)
					else:
						# Clear the cell
						ball.sand_simulation.set_cell(x, y, Constants.CellType.EMPTY)

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
