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

import retrograde.engine.input : InputEventAction, InputMethod, KeyboardKeyCode,
    KeyboardKeyModifier, KeyboardKeyEvent, KeyboardScanCode, keyEvents,
    MouseButton, MouseButtonEvent, mouseButtonEvents;

/**
 * Init the input system.
 *
 * Without calling this function, input events will never be polled and queued.
 */
void initInput(InputMethod inputMethods) {
    if (inputMethods & InputMethod.keyboard) {
        setupKeyboardCallback();
    }

    if (inputMethods & InputMethod.mouse) {
        setupMouseCallback();
    }
}

private extern (C) void setupKeyboardCallback();
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
 * Called by the web runtime when a mouse button is pressed or released.
 *
 * See $(D MouseButtonEvent) for a description of the parameters.
 */
export extern (C) void onMouseButton(MouseButton button, InputEventAction action,
    KeyboardKeyModifier modifiers) {
    mouseButtonEvents.enqueue(MouseButtonEvent(button, action, modifiers));
}
