/**
 * Retrograde Engine
 *
 * The main entry point for the Retrograde Engine when running as a
 * runtime.
 * - When compiled to native code, this runs the game's WASM module in a WASM runtime.
 * - When compiled to WebAssembly, this is the entry point for communicating to the game's
 *   WASM module.
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

import retrograde.std.stdio : writeln;

version (WebAssembly) {
    export extern (C) void _start() {
        writeln("Hello WebAssembly world!");
    }
} else {
    extern (C) void main() {
        writeln("Hello native world!");
    }
}
