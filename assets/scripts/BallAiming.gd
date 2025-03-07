class_name BallAiming
extends RefCounted

# Reference to the main ball node
var ball = null

# Aiming variables
var is_shooting = false
var click_position = Vector2.ZERO  # Store the initial click position
var current_mouse_position = Vector2.ZERO  # Track current mouse position

func _init(ball_reference):
	ball = ball_reference

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
		# Calculate ball position in screen coordinates
		var ball_screen_pos = ball.ball_position * Constants.GRID_SIZE + Vector2(Constants.GRID_SIZE/2, Constants.GRID_SIZE/2)
		
		# Calculate the direction vectors
		var drag_direction = (current_mouse_position - click_position).normalized()
		var shot_direction = -drag_direction  # Opposite direction for the shot
		
		# Calculate the distance between click and current mouse position
		var distance = click_position.distance_to(current_mouse_position)
		
		# Determine the line length based on distance (power)
		var max_distance = 600.0
		var power_ratio = min(distance / max_distance, 1.0)
		
		# Draw the original dotted line - from click position to current mouse position
		draw_dotted_line(canvas, click_position, current_mouse_position, Color(1, 0, 0, 0.7), 5, 5)
		
		# Draw the opposite direction line - from click position in the opposite direction
		var opposite_end = click_position + shot_direction * distance
		canvas.draw_line(click_position, opposite_end, Color(1, 1, 1, 0.8), 2)
		
		# Draw arrowhead at the end of the opposite line
		draw_arrowhead(canvas, opposite_end, shot_direction, Color(1, 1, 1, 0.8))
		
		# Draw power indicator circle at the click position
		canvas.draw_circle(click_position, 5, Color(1, 0, 0, 0.7))
		
		# Draw power level indicator
		var power_text = "Power: %.0f%%" % (power_ratio * 100)
		canvas.draw_string(
			FontLoader.get_default_font(), 
			click_position + Vector2(15, -15), 
			power_text, 
			HORIZONTAL_ALIGNMENT_LEFT, 
			-1, 
			14, 
			Color(1, 1, 1, 0.8))

func draw_dotted_line(canvas, start_pos, end_pos, color, dash_length, gap_length):
	var direction = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	var current_distance = 0
	
	while current_distance < distance:
		var dash_start = start_pos + direction * current_distance
		current_distance += dash_length
		
		# Make sure we don't draw past the end
		if current_distance > distance:
			current_distance = distance
			
		var dash_end = start_pos + direction * current_distance
		canvas.draw_line(dash_start, dash_end, color, 2)
		
		current_distance += gap_length

func draw_arrowhead(canvas, position, direction, color):
	# Arrow properties
	var arrow_size = 10.0
	var arrow_angle = PI / 6  # 30 degrees
	
	# Calculate the points for the arrowhead
	var back_direction = -direction  # Direction from tip to base
	var right_direction = back_direction.rotated(arrow_angle)
	var left_direction = back_direction.rotated(-arrow_angle)
	
	var right_point = position + right_direction * arrow_size
	var left_point = position + left_direction * arrow_size
	
	# Draw the arrowhead
	var points = PackedVector2Array([position, right_point, left_point])
	canvas.draw_colored_polygon(points, color)
