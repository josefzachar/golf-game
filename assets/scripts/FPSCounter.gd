extends Node2D

# FPS tracking variables
var current_fps = 0
var min_fps = 1000
var max_fps = 0
var avg_fps = 0
var fps_samples = []
var max_samples = 60  # 1 second of samples at 60 FPS

# Active cell tracking
var active_cell_count = 0
var sand_simulation = null

# Graph variables
var graph_width = 100
var graph_height = 40
var graph_data = []
var target_fps = 60

# Font for drawing text
var font = null

func _ready():
	# Initialize graph data
	for i in range(graph_width):
		graph_data.append(0)
	
	# Find the sand simulation node
	var main = get_parent()
	if main.has_node("SandSimulation"):
		sand_simulation = main.get_node("SandSimulation")
	
	# Get default font
	font = ThemeDB.fallback_font

func _process(delta):
	# Update FPS
	current_fps = Engine.get_frames_per_second()
	
	# Update min/max FPS
	if current_fps < min_fps:
		min_fps = current_fps
	if current_fps > max_fps:
		max_fps = current_fps
	
	# Update average FPS
	fps_samples.append(current_fps)
	if fps_samples.size() > max_samples:
		fps_samples.remove_at(0)
	
	var total = 0
	for sample in fps_samples:
		total += sample
	avg_fps = total / fps_samples.size()
	
	# Update graph data
	graph_data.append(current_fps)
	if graph_data.size() > graph_width:
		graph_data.remove_at(0)
	
	# Update active cell count
	active_cell_count = 0  # We don't have active cell tracking anymore
	
	# Redraw
	queue_redraw()

func _draw():
	# Draw background
	var bg_color = Color(0, 0, 0, 0.5)
	draw_rect(Rect2(10, 10, graph_width + 20, graph_height + 60), bg_color, true)
	
	# Draw FPS text
	var text_color = Color(1, 1, 1)
	var font_size = 12
	
	# Use draw_string_outline for Godot 4.x
	draw_string(font, Vector2(15, 25), "FPS: " + str(current_fps), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	draw_string(font, Vector2(15, 40), "Min: " + str(min_fps) + " | Max: " + str(max_fps) + " | Avg: " + str(int(avg_fps)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	draw_string(font, Vector2(15, 55), "Active Cells: " + str(active_cell_count), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	
	# Draw graph
	var graph_bg_color = Color(0.1, 0.1, 0.1, 0.5)
	draw_rect(Rect2(20, 65, graph_width, graph_height), graph_bg_color, true)
	
	# Draw target FPS line
	var target_y = 65 + graph_height - (target_fps * graph_height / 100)
	var target_color = Color(0, 1, 0, 0.5)
	draw_line(Vector2(20, target_y), Vector2(20 + graph_width, target_y), target_color, 1)
	
	# Draw FPS graph
	for i in range(1, graph_data.size()):
		var x1 = 20 + i - 1
		var y1 = 65 + graph_height - (graph_data[i-1] * graph_height / 100)
		var x2 = 20 + i
		var y2 = 65 + graph_height - (graph_data[i] * graph_height / 100)
		
		# Color based on FPS (red for low, green for high)
		var graph_color
		if graph_data[i] < 30:
			graph_color = Color(1, 0, 0)  # Red for low FPS
		elif graph_data[i] < 45:
			graph_color = Color(1, 1, 0)  # Yellow for medium FPS
		else:
			graph_color = Color(0, 1, 0)  # Green for high FPS
		
		draw_line(Vector2(x1, y1), Vector2(x2, y2), graph_color, 2)
