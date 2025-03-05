extends Node

# Scene
const GRID_SIZE = 8  # Size of each pixel cell
const GRID_WIDTH = 200  # Width of the grid in cells
const GRID_HEIGHT = 120  # Height of the grid in cells
const SAND_COLOR = Color(0.76, 0.70, 0.50)  # Sandy color
const HOLE_COLOR = Color(0.1, 0.1, 0.1, 1.0)  # Dark hole with full opacity
const WATER_COLOR = Color(0.2, 0.4, 0.8, 0.7)  # Blue-ish transparent water

# Ball
const GRAVITY = 50.0
const BALL_COLOR = Color(1.0, 1.0, 1.0)  # White ball
const BALL_MASS = 1.0  # Ball mass (higher value = heavier ball)
const BOUNCE_FACTOR = 0.5  # How bouncy the ball is (0-1) - reduced for less bouncing
const REST_THRESHOLD = 0.25  # Below this velocity magnitude, the ball will rest on surfaces


# Materials
enum CellType {
	EMPTY = 0,
	SAND = 1,
	BALL = 2,
	HOLE = 3,
	WATER = 4,
	BALL_START = 5
}

const MOMENTUM_CONSERVATION = 0.85  # How much momentum is preserved when hitting sand (higher = more conservation)
const SAND_RESISTANCE = 5  # How much sand slows the ball (reduced to allow more movement)
const SAND_DISPLACEMENT_FACTOR = 0.2  # How much sand spreads (higher = more spread)
const WATER_RESISTANCE = 20.0  # How much water slows the ball (much higher than sand)
