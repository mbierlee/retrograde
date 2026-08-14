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

import retrograde.engine.input : InputMethod, MouseMode, MouseModeEvent,
    mouseModeEvents, MouseMovementType;

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
// Text input is GLFW's character callback, glfwSetCharCallback: it hands over
// the code point of the character that was typed, which is exactly what a
// TextInputEvent carries, so it is enqueued into textInputEvents as it comes.
// Only set it when InputMethod.textInput was asked for, so that a game that
// does not take text does not have characters piling up on it. Mind that the
// character callback is the same one KeyboardKeyCode needs above: pairing a
// character up with its key event is a matter of the key callback, and is not
// what these events are for.
//
// Do not use glfwSetCharModsCallback for this. It is deprecated, and the
// modifiers it adds are not part of a TextInputEvent anyway: which keys went
// into composing a character is the business of the key events.
//
// GLFW's cursor position is already the Y-down position from the top left
// corner of the content area that MouseMovementEvent carries, so it is passed
// on as it comes. It is in screen coordinates rather than in pixels though,
// which are not the same thing on a hidpi display: take the size to work out a
// position that is a part of the content area from glfwGetWindowSize, not from
// glfwGetFramebufferSize.
//
// GLFW's scroll offsets are already the Y-up notches MouseScrollEvent carries,
// so they are passed on as they come. The browser is the one platform that
// reports the wheel the other way up, and its runtime turns the offset around
// itself rather than leaving that to every platform here.

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

/**
 * The mode the mouse was last asked to be in, which is the one it is taken to
 * be in while native input is not implemented.
 *
 * Kept here only so that the mode has somewhere to be reported back from while
 * there is no window holding it. It goes once GLFW is in: the mode is then
 * asked of the platform, the way the settings above are.
 */
private MouseMode currentMouseMode = MouseMode.normal;

/**
 * Puts the mouse in the given mode, and reports it as taken on right away.
 *
 * Called by $(D setMouseMode); prefer that over calling this directly.
 *
 * The browser has to be given the pointer lock by the user before a disabled
 * mouse is really disabled, which is why the mode is reported through an event
 * at all. Nothing of the sort stands in the way here: GLFW hides and locks the
 * cursor as soon as it is asked to, so the event follows immediately.
 */
void setPlatformMouseMode(MouseMode mouseMode) {
    // TODO: pass on to the platform once native input is implemented, as
    // glfwSetInputMode with GLFW_CURSOR: GLFW_CURSOR_NORMAL, GLFW_CURSOR_HIDDEN
    // and GLFW_CURSOR_DISABLED are the three modes here, in that order.
    currentMouseMode = mouseMode;
    mouseModeEvents.enqueue(MouseModeEvent(mouseMode));
}

/**
 * Returns: The mode the mouse is in.
 *
 * Called by $(D getMouseMode); prefer that over calling this directly.
 */
MouseMode getPlatformMouseMode() {
    // TODO: ask the platform once native input is implemented, as
    // glfwGetInputMode with GLFW_CURSOR, and drop currentMouseMode with it.
    return currentMouseMode;
}
