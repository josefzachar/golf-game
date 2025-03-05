# Golf Game README

# Golf Game

Welcome to the Golf Game project! This is a simple 2D golf game featuring a pixel-simulated environment and a physics engine inspired by Noita.

## Project Structure

- **assets/fonts**: Contains font files used in the game.
- **assets/scenes/Main.tscn**: The main scene of the game, setting up the golf course layout and UI elements.
- **assets/scenes/GolfBall.tscn**: Defines the scene for the golf ball, including its properties and behaviors.
- **assets/scripts/main.gd**: The entry point of the game, initializing the game, handling the main game loop, and managing the overall game state.
- **assets/scripts/golf_ball.gd**: Exports a class `GolfBall` with properties such as `position`, `velocity`, and methods like `apply_force()` and `reset_position()` to control the golf ball's behavior.
- **assets/scripts/physics.gd**: Exports a class `PhysicsEngine` that simulates physics interactions, including methods like `update_physics()` for applying forces and handling collisions.
- **assets/sprites/golf_ball.png**: The sprite image for the golf ball.
- **assets/sprites/environment.png**: The sprite image for the game environment.

## Setup Instructions

1. Clone the repository or download the project files.
2. Open the project in Godot.
3. Ensure all assets are correctly linked in the project settings.
4. Run the `Main.tscn` scene to start playing the game.

## Gameplay Mechanics

- Use the mouse to aim and set the power of your shot.
- Hit the golf ball to navigate through the course.
- The physics engine simulates realistic ball movement and interactions with the environment.

## Credits

- Developed by [Your Name].
- Inspired by Noita's physics engine and gameplay mechanics.