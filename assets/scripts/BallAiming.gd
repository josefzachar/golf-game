extends RefCounted

# Reference to the main ball node
var ball = null

# Aiming variables
var is_shooting = false
var click_position = Vector2.ZERO  # Store the initial click position
var current_mouse_position = Vector2.ZERO  # Track current mouse position

# Style variables for pixelated look
var pixel_font = null
var pixel_size = 1  # Size of the "pixels" for the pixel art effect

func _init(ball_reference):
	ball = ball_reference
	
	# Set pixel size based on game's grid size
	pixel_size = max(1, int(Constants.GRID_SIZE / 8))

func reset():
	is_shooting = false
	click_position = Vector2.ZERO
	current_mouse_position = Vector2.ZERO

func update():
	# Track current mouse position for drawing
	if is_shooting:
		current_mouse_position = ball.get_global_mouse_position()

func handle_input(event):
	# Only process mouse inputs when the ball can be shot
	if not ball.can_shoot():
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start shooting
				start_shooting()
			elif is_shooting:
				# End shooting
				end_shooting()

func start_shooting():
	is_shooting = true
	click_position = ball.get_global_mouse_position()
	current_mouse_position = click_position
	
func end_shooting():
	if is_shooting:
		# Calculate the force vector from the click position to the current mouse position
		var force = (click_position - current_mouse_position) * 0.08
		
		# Apply the force to the ball
		ball.ball_velocity = force
		
		# Reset shooting state
		is_shooting = false

func draw(canvas):
	# Only draw aiming line when shooting
	if is_shooting:
		# Calculate the direction vectors
		var drag_direction = (current_mouse_position - click_position).normalized()
		var shot_direction = -drag_direction  # Opposite direction for the shot
		
		# Calculate the distance between click and current mouse position
		var distance = click_position.distance_to(current_mouse_position)
		
		# Determine the line length based on distance (power)
		var max_distance = 600.0
		var power_ratio = min(distance / max_distance, 1.0)
		
		# Draw pixelated elements
		
		# 1. Draw drag line (red dotted) - using large pixel dots
		draw_pixelated_dotted_line(canvas, click_position, current_mouse_position, Color(1, 0, 0, 0.8), 8, 12, 4)
		
		# 2. Draw shot prediction line - matching the dotted style but in white
		var opposite_end = click_position + shot_direction * distance
		draw_pixelated_dotted_line(canvas, click_position, opposite_end, Color(1, 1, 1, 0.9), 8, 12, 4)
		
		# 3. Draw pixel-art arrowhead at the end
		draw_pixelated_arrowhead(canvas, opposite_end, shot_direction, Color(1, 1, 1, 0.8), 8)

# Pixelated drawing functions

func draw_pixelated_line(canvas, start_pos, end_pos, color, thickness=1):
	# Draw a pixel-perfect line with larger pixels
	var direction = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	
	# Use larger pixel size for more pronounced pixel art look
	var step_size = max(3, pixel_size * 3)  # Triple the pixel size
	var steps = int(distance / step_size)
	
	# Adjust thickness to be bigger
	var pixel_thickness = max(thickness * 2, 4)  # Minimum thickness of 4
	
	for i in range(steps + 1):
		var t = float(i) / float(steps) if steps > 0 else 0
		var pixel_pos = start_pos.lerp(end_pos, t)
		
		# Round to step_size grid for chunkier pixelated look
		pixel_pos = Vector2(
			round(pixel_pos.x / step_size) * step_size, 
			round(pixel_pos.y / step_size) * step_size
		)
		
		# Draw larger square pixel
		canvas.draw_rect(Rect2(
			pixel_pos - Vector2(pixel_thickness/2, pixel_thickness/2), 
			Vector2(pixel_thickness, pixel_thickness)
		), color)

func draw_pixelated_dotted_line(canvas, start_pos, end_pos, color, dash_length, gap_length, thickness=1):
	var direction = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	var current_distance = 0
	
	# Use larger pixel sizes for more pronounced pixelated look
	var pixel_size_large = max(4, pixel_size * 4)
	dash_length = max(pixel_size_large, dash_length * 2)  # Make dashes larger
	gap_length = max(pixel_size_large, gap_length * 2)    # Make gaps larger
	
	# Draw individual square "dots" for a chunkier look
	while current_distance < distance:
		var dot_pos = start_pos + direction * current_distance
		
		# Round to pixel grid
		dot_pos = Vector2(
			round(dot_pos.x / pixel_size_large) * pixel_size_large,
			round(dot_pos.y / pixel_size_large) * pixel_size_large
		)
		
		# Draw a single large square "dot"
		var dot_size = max(thickness * 3, 6)  # Significantly larger dots
		canvas.draw_rect(Rect2(
			dot_pos - Vector2(dot_size/2, dot_size/2),
			Vector2(dot_size, dot_size)
		), color)
		
		# Move to next dot position
		current_distance += dash_length + gap_length

func draw_pixelated_arrowhead(canvas, position, direction, color, size=10):
	# Calculate points for a pixelated arrow
	var back_direction = -direction
	var right_direction = back_direction.rotated(PI/4)  # 45 degrees
	var left_direction = back_direction.rotated(-PI/4)  # -45 degrees
	
	# Scale based on pixel size
	size = max(3, round(size / pixel_size) * 2)
	
	var right_point = position + right_direction * size
	var left_point = position + left_direction * size
	
	# Create a list of points
	var points = [position, right_point, left_point]
	
	# Draw the outline
	draw_pixelated_line(canvas, points[0], points[1], color, 2)
	draw_pixelated_line(canvas, points[1], points[2], color, 2)
	draw_pixelated_line(canvas, points[2], points[0], color, 2)
	
	# Fill the triangle with pixels
	var min_x = min(min(points[0].x, points[1].x), points[2].x)
	var max_x = max(max(points[0].x, points[1].x), points[2].x)
	var min_y = min(min(points[0].y, points[1].y), points[2].y)
	var max_y = max(max(points[0].y, points[1].y), points[2].y)
	
	# Step size for pixelated look
	var step = max(1, pixel_size)
	
	for x in range(int(min_x), int(max_x) + 1, step):
		for y in range(int(min_y), int(max_y) + 1, step):
			var point = Vector2(x, y)
			# Check if point is inside the triangle
			if is_point_in_triangle(point, points[0], points[1], points[2]):
				canvas.draw_rect(Rect2(point, Vector2(step, step)), color)

func is_point_in_triangle(p, a, b, c):
	# Helper function to determine if point is in triangle
	var d1 = sign((p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y))
	var d2 = sign((p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y))
	var d3 = sign((p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y))
	
	var has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
	
	# If all same sign, point is in triangle
	return !(has_neg and has_pos)

func draw_pixelated_diamond(canvas, center, size, color):
	# Draw a diamond shape using pixels
	var step = max(1, pixel_size)
	
	for x in range(-size, size + 1, step):
		for y in range(-size, size + 1, step):
			if abs(x) + abs(y) <= size:
				var pixel_pos = Vector2(
					center.x + x,
					center.y + y
				)
				canvas.draw_rect(Rect2(pixel_pos, Vector2(step, step)), color)

func has_pixelated_font():
	return false  # Simplified for this implementation

func get_pixelated_font():
	return FontLoader.get_default_font()  # Use default font
