# The Retrograde Game Engine

Copyright Mike Bierlee 2014-2026  
Version 0.0.0  
Licensed under the terms of the MIT license - See [LICENSE.txt](LICENSE.txt)

Retrograde is a general purpose game engine. Currently it is in alpha state
and not fit for production. Many usual engine systems are missing or incomplete.

This is yet another redo of the engine, this time focussing on portability and web-compatibility.

This README will be extended further once the engine matures more.

## Coordinate System

Retrograde uses the following coordinate system conventions:

- **Right-handed coordinate system**: Following OpenGL conventions, the engine uses a right-handed coordinate system where the cross product of the X-axis and Y-axis points in the positive Z direction.
- **Y-up orientation**: The positive Y-axis points upward. The standard up vector is `(0, 1, 0)`.
- **Matrix layout**: Matrices use row-major order for data storage.
- **Clipping planes**: Near and far clipping distances are specified along the negative Z-axis.

## Version Conditions

The following table lists all [version conditions](https://dlang.org/spec/version.html#version) available and used by Retrograde.

| Version         | Description                                                                                                                            |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Native          | Include native implementations. Do not use this if you want to build for the web.                                                      |
| WebAssembly     | Include WebAssembly implementations. Do not use for native builds. Some compilers will implicitly add this when targeting WASM.        |
| Windows         | Include implementations for Windows. Typically added by compiler when targeting Windows.                                               |
| UnitTesting     | Include the engine's unit tests in build. By NOT specifying this the compiler will properly optimize them out of your (release) build. |
| MemoryDebug     | When included, issues related to memory allocation will be printed. Normally only needed to debug issues with the game engine itself.  |
| OpenGLES3       | Use the OpenGL ES 3 render API. Available in WebAssembly (via WebGL2) and native.                                                      |
| DoublePrecision | Use double precision (64-bit) for scalar math operations instead of single precision (32-bit float). Affects Vector and Matrix types.  |
