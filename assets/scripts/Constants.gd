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
const REST_THRESHOLD = 0.05  # Below this velocity magnitude, the ball will rest on surfaces

# Materials
enum CellType {
	EMPTY = 0,
	SAND = 1,
	BALL = 2,
	HOLE = 3,
	WATER = 4,
	BALL_START = 5,
	STONE = 6,
	DIRT = 7,
	FIRE = 8  # New fire cell type for explosions
	# Add new materials here with incremental IDs
	# LAVA = 9,
	# MUD = 10,
	# ICE = 11,
	# etc.
}

# Material Categories - for more universal physics handling
enum MaterialType {
	NONE = 0,       # For empty cells and special types
	LIQUID = 1,     # Flows freely (water, lava, etc.)
	GRANULAR = 2,   # Loose particles that flow/stack (sand, dirt, etc.)
	SOLID = 3       # Rigid materials (stone, ice, etc.)
}

# Map cell types to material types
const MATERIAL_CATEGORIES = {
	CellType.EMPTY: MaterialType.NONE,
	CellType.SAND: MaterialType.GRANULAR,
	CellType.BALL: MaterialType.NONE,
	CellType.HOLE: MaterialType.NONE,
	CellType.WATER: MaterialType.LIQUID,
	CellType.BALL_START: MaterialType.NONE,
	CellType.STONE: MaterialType.SOLID,
	CellType.DIRT: MaterialType.GRANULAR,
	CellType.FIRE: MaterialType.LIQUID  # Fire behaves like a liquid but rises
	# Add mappings for new materials here
	# CellType.LAVA: MaterialType.LIQUID,
	# CellType.MUD: MaterialType.GRANULAR,
	# CellType.ICE: MaterialType.SOLID,
}

# Universal material properties
# These properties define how materials behave in the physics system
const MATERIAL_PROPERTIES = {
	MaterialType.NONE: {
		"density": 0.0,           # How dense the material is (affects gravity)
		"viscosity": 0.0,         # How thick/sticky the material is (for liquids)
		"elasticity": 0.0,        # How bouncy the material is (0-1)
		"friction": 0.0,          # How much the material slows movement
		"strength": 0.0,          # How resistant to deformation/destruction
		"flow_rate": 0.0,         # How quickly the material flows
		"displacement": 0.0       # How much the material spreads when disturbed
	},
	MaterialType.LIQUID: {
		"density": 0.8,           # Liquids are moderately dense
		"viscosity": 0.7,         # Standard viscosity (water = 0.7, honey would be higher)
		"elasticity": 0.1,        # Low bounce factor
		"friction": 0.8,          # High friction in liquids
		"strength": 0.1,          # Very low strength (easily displaced)
		"flow_rate": 0.9,         # High flow rate
		"displacement": 0.7       # High displacement
	},
	MaterialType.GRANULAR: {
		"density": 1.2,           # Granular materials are moderately dense
		"viscosity": 0.3,         # Low viscosity
		"elasticity": 0.3,        # Moderate bounce factor
		"friction": 0.6,          # Moderate friction
		"strength": 0.4,          # Moderate strength
		"flow_rate": 0.8,         # Increased flow rate (was 0.5)
		"displacement": 0.5       # Moderate displacement
	},
	MaterialType.SOLID: {
		"density": 2.5,           # Solids are dense
		"viscosity": 0.0,         # No viscosity
		"elasticity": 0.7,        # High bounce factor
		"friction": 0.4,          # Moderate friction
		"strength": 0.9,          # High strength (hard to displace)
		"flow_rate": 0.0,         # No flow
		"displacement": 0.0       # No displacement
	}
}

# Define fire color constant
const FIRE_COLOR = Color(1.0, 0.5, 0.1, 0.9)  # Bright orange with some transparency

# Cell property defaults - enhanced with more properties
const CELL_DEFAULTS = {
	CellType.EMPTY: {
		"mass": 0.0,
		"dampening": 1.0,
		"base_color": Color(0.2, 0.3, 0.4),
		"material_type": MaterialType.NONE,
		# Copy properties from material type
		"density": MATERIAL_PROPERTIES[MaterialType.NONE].density,
		"viscosity": MATERIAL_PROPERTIES[MaterialType.NONE].viscosity,
		"elasticity": MATERIAL_PROPERTIES[MaterialType.NONE].elasticity,
		"friction": MATERIAL_PROPERTIES[MaterialType.NONE].friction,
		"strength": MATERIAL_PROPERTIES[MaterialType.NONE].strength,
		"flow_rate": MATERIAL_PROPERTIES[MaterialType.NONE].flow_rate,
		"displacement": MATERIAL_PROPERTIES[MaterialType.NONE].displacement
	},
	CellType.SAND: {
		"mass": 1.0,
		"dampening": 0.95,
		"base_color": SAND_COLOR,
		"material_type": MaterialType.GRANULAR,
		# Copy properties from material type with some customization
		"density": MATERIAL_PROPERTIES[MaterialType.GRANULAR].density * 0.9,  # Lighter than default granular
		"viscosity": MATERIAL_PROPERTIES[MaterialType.GRANULAR].viscosity,
		"elasticity": MATERIAL_PROPERTIES[MaterialType.GRANULAR].elasticity * 0.8,  # Less bouncy
		"friction": MATERIAL_PROPERTIES[MaterialType.GRANULAR].friction * 1.2,  # More friction
		"strength": MATERIAL_PROPERTIES[MaterialType.GRANULAR].strength * 0.7,  # Weaker than default
		"flow_rate": MATERIAL_PROPERTIES[MaterialType.GRANULAR].flow_rate * 1.3,  # Flows more easily
		"displacement": MATERIAL_PROPERTIES[MaterialType.GRANULAR].displacement * 1.2  # Displaces more easily
	},
	CellType.BALL: {
		"mass": BALL_MASS,
		"dampening": 1.0,
		"base_color": BALL_COLOR,
		"material_type": MaterialType.NONE
	},
	CellType.HOLE: {
		"mass": 0.0,
		"dampening": 1.0,
		"base_color": HOLE_COLOR,
		"material_type": MaterialType.NONE
	},
	CellType.WATER: {
		"mass": 0.8,
		"dampening": 0.2,
		"base_color": WATER_COLOR,
		"material_type": MaterialType.LIQUID,
		# Copy properties from material type with some customization
		"density": MATERIAL_PROPERTIES[MaterialType.LIQUID].density,
		"viscosity": MATERIAL_PROPERTIES[MaterialType.LIQUID].viscosity,  # Standard water viscosity
		"elasticity": MATERIAL_PROPERTIES[MaterialType.LIQUID].elasticity,
		"friction": MATERIAL_PROPERTIES[MaterialType.LIQUID].friction,
		"strength": MATERIAL_PROPERTIES[MaterialType.LIQUID].strength,
		"flow_rate": MATERIAL_PROPERTIES[MaterialType.LIQUID].flow_rate * 1.2,  # Water flows very easily
		"displacement": MATERIAL_PROPERTIES[MaterialType.LIQUID].displacement * 1.1  # Water displaces easily
	},
	CellType.BALL_START: {
		"mass": 0.0,
		"dampening": 1.0,
		"base_color": Color(0.8, 0.8, 0.2, 0.8),
		"material_type": MaterialType.NONE
	},
	CellType.STONE: {
		"mass": 3.0,
		"dampening": 0.85,
		"base_color": STONE_COLOR,
		"material_type": MaterialType.SOLID,
		# Copy properties from material type with some customization
		"density": MATERIAL_PROPERTIES[MaterialType.SOLID].density * 1.2,  # Denser than default solid
		"viscosity": MATERIAL_PROPERTIES[MaterialType.SOLID].viscosity,
		"elasticity": MATERIAL_PROPERTIES[MaterialType.SOLID].elasticity * 1.1,  # More bouncy
		"friction": MATERIAL_PROPERTIES[MaterialType.SOLID].friction * 0.9,  # Less friction
		"strength": MATERIAL_PROPERTIES[MaterialType.SOLID].strength * 1.3,  # Much stronger
		"flow_rate": MATERIAL_PROPERTIES[MaterialType.SOLID].flow_rate,
		"displacement": MATERIAL_PROPERTIES[MaterialType.SOLID].displacement
	},
	CellType.DIRT: {
		"mass": 2.5,
		"dampening": 0.86,
		"base_color": DIRT_COLOR,
		"material_type": MaterialType.GRANULAR,
		# Copy properties from material type with some customization
		"density": MATERIAL_PROPERTIES[MaterialType.GRANULAR].density * 1.3,  # Denser than default granular
		"viscosity": MATERIAL_PROPERTIES[MaterialType.GRANULAR].viscosity * 1.5,  # More viscous (packed)
		"elasticity": MATERIAL_PROPERTIES[MaterialType.GRANULAR].elasticity * 1.2,  # More bouncy
		"friction": MATERIAL_PROPERTIES[MaterialType.GRANULAR].friction * 1.1,  # More friction
		"strength": MATERIAL_PROPERTIES[MaterialType.GRANULAR].strength * 2.0,  # Much stronger than sand
		"flow_rate": MATERIAL_PROPERTIES[MaterialType.GRANULAR].flow_rate * 0.4,  # Flows less easily
		"displacement": MATERIAL_PROPERTIES[MaterialType.GRANULAR].displacement * 0.5  # Harder to displace
	},
	CellType.FIRE: {
		"mass": 0.2,  # Very light
		"dampening": 0.1,  # Almost no dampening
		"base_color": FIRE_COLOR,
		"material_type": MaterialType.LIQUID,
		# Custom properties for fire
		"density": MATERIAL_PROPERTIES[MaterialType.LIQUID].density * 0.2,  # Very low density (rises)
		"viscosity": MATERIAL_PROPERTIES[MaterialType.LIQUID].viscosity * 0.3,  # Low viscosity
		"elasticity": MATERIAL_PROPERTIES[MaterialType.LIQUID].elasticity,
		"friction": MATERIAL_PROPERTIES[MaterialType.LIQUID].friction * 0.5,  # Low friction
		"strength": MATERIAL_PROPERTIES[MaterialType.LIQUID].strength * 0.5,  # Very weak
		"flow_rate": MATERIAL_PROPERTIES[MaterialType.LIQUID].flow_rate * 1.5,  # Flows very easily
		"displacement": MATERIAL_PROPERTIES[MaterialType.LIQUID].displacement * 1.5,  # Displaces very easily
		"lifetime": 2.0,  # Fire cells have a lifetime and disappear
		"rises": true,  # Fire rises upward
		"rise_speed": 0.8,  # How fast it rises
		"spread_chance": 0.3,  # Chance to spread to adjacent cells
		"color_variation": 0.2  # More color variation for fire
	}
	
	# Example of how to add a new material:
	# CellType.LAVA: {
	#     "mass": 1.2,
	#     "dampening": 0.3,
	#     "base_color": Color(0.9, 0.3, 0.1, 0.8),  # Orange-red with transparency
	#     "material_type": MaterialType.LIQUID,
	#     "density": MATERIAL_PROPERTIES[MaterialType.LIQUID].density * 1.5,  # Denser than water
	#     "viscosity": MATERIAL_PROPERTIES[MaterialType.LIQUID].viscosity * 2.0,  # More viscous than water
	#     "elasticity": MATERIAL_PROPERTIES[MaterialType.LIQUID].elasticity * 0.5,
	#     "friction": MATERIAL_PROPERTIES[MaterialType.LIQUID].friction * 1.2,
	#     "strength": MATERIAL_PROPERTIES[MaterialType.LIQUID].strength,
	#     "flow_rate": MATERIAL_PROPERTIES[MaterialType.LIQUID].flow_rate * 0.7,  # Flows slower than water
	#     "displacement": MATERIAL_PROPERTIES[MaterialType.LIQUID].displacement * 0.8
	# }
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

# Add these to Constants.gd after the existing constants

# Ball types
enum BallType {
	STANDARD = 0,
	STICKY = 1,
	EXPLOSIVE = 2,
	TELEPORT = 3,
	HEAVY = 4
}

# Ball properties for each type
const BALL_PROPERTIES = {
	BallType.STANDARD: {
		"name": "Standard Ball",
		"color": Color(1.0, 1.0, 1.0),  # White
		"mass": BALL_MASS,  # Use existing BALL_MASS
		"bounce_factor": BOUNCE_FACTOR,  # Use existing BOUNCE_FACTOR
		"description": "Regular golf ball with standard physics"
	},
	BallType.STICKY: {
		"name": "Sticky Ball",
		"color": Color(0.2, 0.8, 0.2),  # Green
		"mass": 0.6,
		"bounce_factor": 0.0,  # No bounce
		"description": "Sticks to surfaces and floats on water"
	},
	BallType.EXPLOSIVE: {
		"name": "Explosive Ball",
		"color": Color(1.0, 0.3, 0.1),  # Orange-red
		"mass": 0.7,
		"bounce_factor": 0.4,
		"explosion_radius": 8.0,
		"description": "Explodes when activated"
	},
	BallType.TELEPORT: {
		"name": "Teleport Ball",
		"color": Color(0.6, 0.2, 0.8),  # Purple
		"mass": 0.5,
		"bounce_factor": 0.5,
		"description": "Swaps places with the hole when activated"
	},
	BallType.HEAVY: {
		"name": "Heavy Ball",
		"color": Color(0.3, 0.3, 0.7),  # Blue
		"mass": 2.0,  # Much heavier
		"bounce_factor": 0.3,  # More bounce due to weight
		"penetration_factor": 3.0,  # Penetrates materials easier
		"description": "Heavy projectile that penetrates terrain"
	}
}
