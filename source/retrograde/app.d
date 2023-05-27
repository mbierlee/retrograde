/**
 * Retrograde Engine
 *
 * The main entry point for the Retrograde Engine when running as a
 * runtime.
 * In this mode, the engine is the main executable and the game project
 * is a dynamic library that is loaded at runtime.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.app;

version (runtime)  :  //

version (WebAssembly) {
	extern (C) void _start() {
	}
} else {
	import core.stdc.stdio : printf;

	extern (C) void main() {
		printf("Edit source/app.d to start your project.\n");
	}
}
