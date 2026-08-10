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

import retrograde.engine.input : InputMethod, MouseMovementType;

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
//
// GLFW's cursor position is already the Y-down position from the top left
// corner of the content area that MouseMovementEvent carries, so it is passed
// on as it comes. It is in screen coordinates rather than in pixels though,
// which are not the same thing on a hidpi display: take the size to work out a
// position that is a part of the content area from glfwGetWindowSize, not from
// glfwGetFramebufferSize.

void initInput(InputMethod inputMethods) {
    assert(0, "Native input system is not yet implemented");
}

/**
 * Tells the platform whether to report the given type of mouse movement.
 *
 * Called by $(D setMouseMovementEnabled); prefer that over calling this
 * directly.
 */
void setPlatformMouseMovementEnabled(MouseMovementType movementType, bool enabled) {
    // TODO: pass on to the platform once native input is implemented. Whether
    // both types can be reported at all depends on the platform: GLFW reports
    // the absolute position of the cursor and leaves the distance it moved to
    // be worked out from the previous position, unless raw motion is on.
}

/**
 * Returns: Whether the given type of mouse movement is reported, which none of
 *          them are while native input is not implemented.
 *
 * Called by $(D isMouseMovementEnabled); prefer that over calling this
 * directly. Report what the platform is really doing here rather than what it
 * was last asked for, so that a setting it cannot take on is not claimed to
 * have been taken on.
 */
bool isPlatformMouseMovementEnabled(MouseMovementType movementType) {
    return false;
}

/**
 * Tells the platform whether to report each axis of a movement on its own.
 *
 * Called by $(D splitMouseAxisEvent); prefer that over calling this directly.
 */
void setPlatformMouseAxisSplit(bool enabled) {
    // TODO: pass on to the platform once native input is implemented. GLFW
    // reports both axes in a single cursor position callback, so splitting them
    // is up to the platform layer here.
}

/**
 * Returns: Whether the platform reports each axis of a movement on its own,
 *          which it does not do while native input is not implemented.
 *
 * Called by $(D isMouseAxisEventSplit); prefer that over calling this directly.
 */
bool isPlatformMouseAxisSplit() {
    return false;
}

/**
 * Tells the platform whether to report mouse movement in its own raw values
 * rather than as a part of the size of the window.
 *
 * Called by $(D setRawMouseMotion); prefer that over calling this directly.
 */
void setPlatformRawMouseMotion(bool enabled) {
    // TODO: pass on to the platform once native input is implemented. Mind that
    // GLFW's raw mouse motion is a matter of the cursor being disabled rather
    // than of the values being in pixels, which is what this asks for.
}

/**
 * Returns: Whether mouse movement is reported in the raw values of the
 *          platform, which it is not while native input is not implemented.
 *
 * Called by $(D isRawMouseMotion); prefer that over calling this directly.
 */
bool isPlatformRawMouseMotion() {
    return false;
}
