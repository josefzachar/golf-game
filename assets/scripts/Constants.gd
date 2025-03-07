extends Node

# Scene
const GRID_SIZE = 8  # Size of each pixel cell
const GRID_WIDTH = 200  # Width of the grid in cells
const GRID_HEIGHT = 120  # Height of the grid in cells
const SAND_COLOR = Color(0.76, 0.70, 0.50)  # Base sandy color
const HOLE_COLOR = Color(0.1, 0.1, 0.1, 1.0)  # Dark hole with full opacity
const WATER_COLOR = Color(0.2, 0.4, 0.8, 0.7)  # Base blue-ish transparent water
const STONE_COLOR = Color(0.5, 0.5, 0.5)  # Base gray stone
const DIRT_COLOR = Color(0.6, 0.4, 0.2)  # Base brown dirt

# Cell variation ranges
const COLOR_VARIATION_RANGE = 0.05  # Maximum color shift (+/-)
const MASS_VARIATION_RANGE = 0.5  # Maximum mass variation (+/-)
const DAMPENING_VARIATION_RANGE = 0.15  # Maximum dampening variation (+/-)

# Ball
const GRAVITY = 50.0
const BALL_COLOR = Color(1.0, 1.0, 1.0)  # White ball
const BALL_MASS = 0.75  # Ball mass (higher value = heavier ball)
const BOUNCE_FACTOR = 0.5  # How bouncy the ball is (0-1) - reduced for less bouncing
const REST_THRESHOLD = 0.25  # Below this velocity magnitude, the ball will rest on surfaces

# Materials
enum CellType {
	EMPTY = 0,
	SAND = 1,
	BALL = 2,
	HOLE = 3,
	WATER = 4,
	BALL_START = 5,
	STONE = 6,
	DIRT = 7
}

# Cell property defaults
const CELL_DEFAULTS = {
	CellType.EMPTY: {
		"mass": 0.0,
		"dampening": 1.0,
		"base_color": Color(0.2, 0.3, 0.4)
	},
	CellType.SAND: {
		"mass": 1.0,
		"dampening": 0.95,
		"base_color": SAND_COLOR
	},
	CellType.BALL: {
		"mass": BALL_MASS,
		"dampening": 1.0,
		"base_color": BALL_COLOR
	},
	CellType.HOLE: {
		"mass": 0.0,
		"dampening": 1.0,
		"base_color": HOLE_COLOR
	},
	CellType.WATER: {
		"mass": 0.8,
		"dampening": 0.2,
		"base_color": WATER_COLOR
	},
	CellType.BALL_START: {
		"mass": 0.0,
		"dampening": 1.0,
		"base_color": Color(0.8, 0.8, 0.2, 0.8)
	},
	CellType.STONE: {
		"mass": 3.0,         # Increased from 2.5 to make it more solid
		"dampening": 0.85,    # REDUCED from 0.99 to increase friction
		"base_color": STONE_COLOR
	},
	CellType.DIRT: {
		"mass": 2.5,         # Increased from 2.0 to be very close to stone
		"dampening": 0.86,    # Almost the same as stone
		"base_color": DIRT_COLOR
	}
}

# You can also add these new constants to fine-tune behaviors:
const DIRT_RESISTANCE = 3.5  # Less resistance than sand (SAND_RESISTANCE is 5)
const STONE_BOUNCE_FACTOR = 0.75  # Higher bounce factor for stone (regular BOUNCE_FACTOR is 0.5)
const DIRT_BOUNCE_FACTOR = 0.6    # Slight bounce increase for dirt
const DIRT_IMPACT_THRESHOLD = 8.0  # Very high force needed to break dirt
const STONE_FRICTION = 0.6  # High friction value for stone surfaces

const MOMENTUM_CONSERVATION = 0.85  # How much momentum is preserved when hitting sand (higher = more conservation)
const SAND_RESISTANCE = 5  # How much sand slows the ball (reduced to allow more movement)
const SAND_DISPLACEMENT_FACTOR = 0.2  # How much sand spreads (higher = more spread)
const WATER_RESISTANCE = 20.0  # How much water slows the ball (much higher than sand)
