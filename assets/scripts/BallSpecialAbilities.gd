class_name BallSpecialAbilities
extends RefCounted

# Reference to the main ball node
var ball = null
var explosion_particles = []  # Store explosion particles for rendering

func _init(ball_reference):
	ball = ball_reference

# Explosive ball behavior with enhanced pixelated explosion effect
func explode():
	if ball.sand_simulation:
		print("BOOM! Explosive ball detonated!")
		# Increase explosion radius for a bigger explosion
		var explosion_radius = ball.ball_properties.get("explosion_radius", 8.0)  # Increased from 5.0 to 8.0
		
		# Create more craters for a bigger explosion effect
		for i in range(5):  # Increased from 3 to 5 craters
			var offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))  # Increased offset range
			var crater_pos = ball.ball_position + offset
			var crater_size = explosion_radius * randf_range(1.0, 1.5)  # Increased size multiplier
			ball.sand_simulation.create_sand_crater(crater_pos, crater_size)
		
		# Trigger visual explosion effect
		ball.create_explosion(explosion_radius)
		
		# Reset to standard ball after explosion
		ball.call_deferred("switch_ball_type", Constants.BallType.STANDARD)
		
# Generate explosion particles for pixelated effect
func generate_explosion_particles(radius):
	var base_radius = radius * Constants.GRID_SIZE
	var particle_count = int(radius * 40)  # More particles for bigger explosion
	
	# Create particles in a circular pattern with pixelated offsets
	for i in range(particle_count):
		# Random angle and distance from center
		var angle = randf() * 2 * PI
		var distance = randf() * base_radius
		
		# Create a pixelated grid-aligned position
		var pixel_size = max(1, Constants.GRID_SIZE / 4)  # Smaller pixels for more detail
		var raw_pos = Vector2(
			cos(angle) * distance,
			sin(angle) * distance
		)
		
		# Quantize to grid for pixelated look
		var grid_pos = Vector2(
			round(raw_pos.x / pixel_size) * pixel_size,
			round(raw_pos.y / pixel_size) * pixel_size
		)
		
		# Calculate particle lifetime and speed
		var lifetime = randf_range(0.3, 0.8)
		var speed = distance / lifetime * randf_range(0.8, 1.2)
		var direction = grid_pos.normalized()
		
		# Create color variations - orange/red/yellow for fire effect
		var r = randf_range(0.8, 1.0)  # Red component
		var g = randf_range(0.1, 0.7)  # Green component (varies more for fire effect)
		var b = randf_range(0.0, 0.1)  # Minimal blue
		var a = randf_range(0.7, 1.0)  # Alpha for glow effect
		
		# Create particle data structure
		var particle = {
			"position": ball.ball_position * Constants.GRID_SIZE + grid_pos,
			"velocity": direction * speed,
			"size": randf_range(1, 3) * pixel_size,
			"lifetime": lifetime,
			"max_lifetime": lifetime,
			"color": Color(r, g, b, a)
		}
		
		explosion_particles.append(particle)

# Draw the explosion effect
func draw_explosion(canvas):
	if explosion_particles.empty():
		# If no particles, disconnect from draw signal
		if ball.is_connected("draw", Callable(self, "draw_explosion")):
			ball.disconnect("draw", Callable(self, "draw_explosion"))
		return
	
	# Update and draw all particles
	var particles_to_remove = []
	
	for i in range(explosion_particles.size()):
		var particle = explosion_particles[i]
		
		# Update lifetime
		particle.lifetime -= 0.02  # Decrease lifetime
		
		if particle.lifetime <= 0:
			particles_to_remove.append(i)
			continue
		
		# Update position based on velocity
		particle.position += particle.velocity * 0.5
		
		# Calculate fade based on lifetime
		var fade_ratio = particle.lifetime / particle.max_lifetime
		var color = particle.color
		color.a = fade_ratio * particle.color.a
		
		# Draw pixelated particle (square for pixelated look)
		var size = particle.size * fade_ratio  # Shrink as it fades
		canvas.draw_rect(
			Rect2(particle.position - Vector2(size/2, size/2), Vector2(size, size)),
			color
		)
	
	# Remove dead particles (in reverse order to avoid index issues)
	for i in range(particles_to_remove.size() - 1, -1, -1):
		explosion_particles.remove_at(particles_to_remove[i])

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
