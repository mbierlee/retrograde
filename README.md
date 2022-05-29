The Retrograde Game Engine
===
Copyright Mike Bierlee 2014-2021  
Version 0.0.0  
Licensed under the terms of the MIT license - See [LICENSE.txt](LICENSE.txt)

Retrograde is a general purpose game engine. Currently it is in alpha state 
and not fit for production. Many usual engine systems are missing or incomplete. 
Incomplete 2D and 3D renderers are available.

## _This is the legacy version of the engine. A reworked version can be found in the development branch._

Features:
- Core update and render loop with fixed time-stepping and variable render rate.
- SDL2-based OS event handling and windowing system.
- Component-based entity system.
- Synchronous, immediate messaging system for events and commands.
- Modular design using dependency injection.
- SDL2-driven 2D renderer.
- OpenGL 4.5 3D renderer.
- Assimp-driven 3D model pipeline.
- Tiled 2D map pipeline.

Optional dependencies on projects not written in D:
- SDL2 2.0.5 (https://www.libsdl.org/)
- SDL2_image 2.0.0 (http://www.libsdl.org/projects/SDL_image/)
- SDL2_ttf 2.0.12 (https://www.libsdl.org/projects/SDL_ttf/)
- Assimp 3.3.1 (http://assimp.sourceforge.net/index.html)

Guaranteed to be compatible with the latest version of D (DMD) only.
Can be built with DUB.
