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

module retrograde.wasm.input;

version (WebAssembly)  :  //

import retrograde.engine.input : Axis, InputEventAction, InputMethod, KeyboardKeyCode,
    KeyboardKeyModifier, KeyboardKeyEvent, KeyboardScanCode, keyEvents,
    MouseButton, MouseButtonEvent, mouseButtonEvents, MouseMode, MouseModeEvent,
    mouseModeEvents, MouseMovementEvent, mouseMovementEvents, MouseMovementType,
    MouseScrollEvent, mouseScrollEvents, TextInputEvent, textInputEvents;

/**
 * Init the input system.
 *
 * Without calling this function, input events will never be polled and queued.
 */
void initInput(InputMethod inputMethods) {
    if (inputMethods & InputMethod.keyboard) {
        setupKeyboardCallback();
    }

    if (inputMethods & InputMethod.textInput) {
        setupTextInputCallback();
    }

    if (inputMethods & InputMethod.mouse) {
        setupMouseCallback();
    }
}

private extern (C) void setupKeyboardCallback();
private extern (C) void setupTextInputCallback();
private extern (C) void setupMouseCallback();

/**
 * Called by the web runtime when a key is pressed, held or released.
 *
 * See $(D KeyboardKeyEvent) for a description of the parameters.
 */
export extern (C) void onKey(KeyboardScanCode scanCode, KeyboardKeyCode keyCode,
    InputEventAction action, KeyboardKeyModifier modifiers) {
    keyEvents.enqueue(KeyboardKeyEvent(scanCode, keyCode, action, modifiers));
}

/**
 * Called by the web runtime when the user types a character.
 *
 * The runtime works the character out of the key events the browser reports,
 * leaving out the keys that edit text rather than produce it and the ones
 * pressed as part of a shortcut. Held keys type their character again with
 * every repeat, as they do in a text field.
 *
 * See $(D TextInputEvent) for a description of the parameters.
 */
export extern (C) void onTextInput(dchar codePoint) {
    textInputEvents.enqueue(TextInputEvent(codePoint));
}

/**
 * Called by the web runtime when a mouse button is pressed or released.
 *
 * See $(D MouseButtonEvent) for a description of the parameters.
 */
export extern (C) void onMouseButton(MouseButton button, InputEventAction action,
    KeyboardKeyModifier modifiers) {
    mouseButtonEvents.enqueue(MouseButtonEvent(button, action, modifiers));
}

/**
 * Called by the web runtime when the mouse is moved.
 *
 * Positions are those of the mouse over the render area, from its top left
 * corner and Y-down as the engine has them. An absolute movement carries the
 * position of the mouse over that area, a relative one the distance it moved
 * since the previous movement. Both are in pixels when raw mouse motion is on,
 * and as a part of the size of the render area when it is off.
 *
 * See $(D MouseMovementEvent) for a description of the parameters.
 */
export extern (C) void onMouseMovement(double xPosition, double yPosition, Axis axis,
    MouseMovementType movementType) {
    mouseMovementEvents.enqueue(MouseMovementEvent(xPosition, yPosition, axis, movementType));
}

/**
 * Called by the web runtime when the mousewheel is scrolled.
 *
 * Offsets are the distance the wheel was scrolled since the previous scroll, in
 * notches: the runtime works them out from the units the browser reported the
 * scroll in, so that a detent of the wheel is a whole notch whichever browser it
 * came from. It also turns the vertical offset around, as the browser is the odd
 * one out in reporting a scroll down as the positive one.
 *
 * See $(D MouseScrollEvent) for a description of the parameters.
 */
export extern (C) void onMouseScroll(double xOffset, double yOffset) {
    mouseScrollEvents.enqueue(MouseScrollEvent(xOffset, yOffset));
}

/**
 * Called by the web runtime when the mouse takes on another mode.
 *
 * The mode is the one the mouse is now really in, which is not the one that was
 * asked for while the browser has not handed over the pointer lock that a
 * disabled mouse needs. Taking and losing that lock is reported here as it
 * happens, whether the user gave it by clicking the render area or took it back
 * with escape.
 *
 * See $(D MouseModeEvent) for a description of the parameters.
 */
export extern (C) void onMouseMode(MouseMode mouseMode) {
    mouseModeEvents.enqueue(MouseModeEvent(mouseMode));
}

/**
 * Tells the web runtime whether to report the given type of mouse movement.
 *
 * Called by $(D setMouseMovementEnabled); prefer that over calling this
 * directly, as it is what the engine itself goes by.
 */
void setPlatformMouseMovementEnabled(MouseMovementType movementType, bool enabled) {
    setMouseMovementTypeEnabled(movementType, enabled);
}

/**
 * Asks the web runtime whether it is reporting the given type of mouse
 * movement.
 *
 * Called by $(D isMouseMovementEnabled); prefer that over calling this
 * directly. The setting is kept by the runtime alone rather than on both sides,
 * so that the two can never end up disagreeing over it.
 */
bool isPlatformMouseMovementEnabled(MouseMovementType movementType) {
    return isMouseMovementTypeEnabled(movementType);
}

/**
 * Tells the web runtime whether to report each axis of a movement on its own.
 *
 * Called by $(D splitMouseAxisEvent); prefer that over calling this directly.
 */
void setPlatformMouseAxisSplit(bool enabled) {
    setMouseAxisSplitEnabled(enabled);
}

/**
 * Asks the web runtime whether it is reporting each axis of a movement on its
 * own.
 *
 * Called by $(D isMouseAxisEventSplit); prefer that over calling this directly.
 * The setting is kept by the runtime alone rather than on both sides, so that
 * the two can never end up disagreeing over it.
 */
bool isPlatformMouseAxisSplit() {
    return isMouseAxisSplitEnabled();
}

/**
 * Tells the web runtime whether to report mouse movement in pixels rather than
 * as a part of the size of the render area.
 *
 * Called by $(D setRawMouseMotion); prefer that over calling this directly.
 */
void setPlatformRawMouseMotion(bool enabled) {
    setRawMouseMotionEnabled(enabled);
}

/**
 * Asks the web runtime whether it is reporting mouse movement in pixels.
 *
 * Called by $(D isRawMouseMotion); prefer that over calling this directly.
 */
bool isPlatformRawMouseMotion() {
    return isRawMouseMotionEnabled();
}

/**
 * Asks the browser to put the mouse in the given mode.
 *
 * Called by $(D setMouseMode); prefer that over calling this directly.
 *
 * A hidden mouse is hidden right away, but a disabled one has to be granted the
 * pointer lock by the user first: the runtime asks for it here and keeps asking
 * on every click on the render area until it is given, so that a mouse that was
 * asked to be disabled is disabled from the first click on. Whether it ended up
 * being granted is reported through $(D onMouseMode) rather than here.
 */
void setPlatformMouseMode(MouseMode mouseMode) {
    setMouseCursorMode(mouseMode);
}

/**
 * Asks the web runtime which mode the mouse is really in.
 *
 * Called by $(D getMouseMode); prefer that over calling this directly. As with
 * the settings above, the mode is kept by the runtime alone rather than on both
 * sides, so that the two can never end up disagreeing over it.
 */
MouseMode getPlatformMouseMode() {
    return getMouseCursorMode();
}

private extern (C) void setMouseMovementTypeEnabled(MouseMovementType movementType, bool enabled);
private extern (C) bool isMouseMovementTypeEnabled(MouseMovementType movementType);
private extern (C) void setMouseAxisSplitEnabled(bool enabled);
private extern (C) bool isMouseAxisSplitEnabled();
private extern (C) void setRawMouseMotionEnabled(bool enabled);
private extern (C) bool isRawMouseMotionEnabled();
private extern (C) void setMouseCursorMode(MouseMode mouseMode);
private extern (C) MouseMode getMouseCursorMode();
