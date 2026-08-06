/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.native.input;

version (Native)  :  //

import retrograde.engine.input : InputMethod;

// TODO: When this is implemented with GLFW, mind that GLFW's key callback
// names its parameters the other way around from KeyboardKeyEvent: GLFW's key
// is the layout-independent physical key and is what maps to KeyboardScanCode,
// while GLFW's scancode is a raw platform-specific number that has no
// equivalent here and can be ignored.
//
// GLFW has nothing that maps to KeyboardKeyCode directly. The character a key
// produced arrives through the separate character callback as a code point,
// which has to be paired up with the key event it belongs to. That callback
// only fires for keys that produce a character; the rest take
// toKeyCode(scanCode). Prefer it over glfwGetKeyName, which reports the
// unmodified character of a key and so would not give the 'A' of shift+a.

void initInput(InputMethod inputMethods) {
    assert(0, "Native input system is not yet implemented");
}
