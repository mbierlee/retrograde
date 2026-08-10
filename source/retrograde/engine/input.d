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

module retrograde.engine.input;

import retrograde.std.collections : Array, Queue, HashMap;
import retrograde.std.hash : hashOf;
import retrograde.std.stringid : StringId;

import retrograde.engine.event : eventQueue, Event, Magnitude;

version (Native) {
    public import retrograde.native.input;
} else version (WebAssembly) {
    public import retrograde.wasm.input;
} else {
    static assert(false, "No input implementations available for target platform.");
}

Queue!KeyboardKeyEvent keyEvents;
Queue!TextInputEvent textInputEvents;
Queue!MouseButtonEvent mouseButtonEvents;
Queue!MouseMovementEvent mouseMovementEvents;
Queue!MouseScrollEvent mouseScrollEvents;

/**
 * The handlers that text typed by the user is handed to.
 *
 * Text input carries a character rather than a magnitude, so it is not bound to
 * events the way keys and mouse buttons are: a text field wants the character
 * that was typed, whichever key happened to produce it. Add a handler here to
 * receive them; $(D processInput) calls every handler for each character typed.
 */
Array!TextInputHandlerFunction textInputHandlers;

/**
 * The events a key binding emits when its key is pressed, held or released.
 *
 * A binding can drive more than one event at a time, such as W driving both
 * ev_moveForward and ev_menuUp; every event mapped to the binding is emitted.
 * Prefer $(D addKeyMapping) and $(D removeKeyMapping) over manipulating
 * this map directly.
 */
HashMap!(KeyBinding, Array!StringId) keyMapping;

/**
 * The events a mouse button binding emits when its button is pressed or
 * released.
 *
 * Works the same way as $(D keyMapping): a binding can drive more than one
 * event, and every event mapped to it is emitted. Prefer
 * $(D addMouseButtonMapping) and $(D removeMouseButtonMapping) over
 * manipulating this map directly.
 */
HashMap!(MouseButtonBinding, Array!StringId) mouseButtonMapping;

/**
 * The events a mouse movement binding emits when the mouse is moved along the
 * axis it binds to.
 *
 * Works the same way as $(D keyMapping): a binding can drive more than one
 * event, and every event mapped to it is emitted. Prefer
 * $(D addMouseMovementMapping) and $(D removeMouseMovementMapping) over
 * manipulating this map directly.
 */
HashMap!(MouseMovementBinding, Array!StringId) mouseMovementMapping;

/**
 * The events a mouse scroll binding emits when the mousewheel is scrolled along
 * the axis it binds to.
 *
 * Works the same way as $(D keyMapping): a binding can drive more than one
 * event, and every event mapped to it is emitted. Prefer
 * $(D addMouseScrollMapping) and $(D removeMouseScrollMapping) over
 * manipulating this map directly.
 */
HashMap!(MouseScrollBinding, Array!StringId) mouseScrollMapping;

/**
 * Make the given key binding emit the given event, on top of any events it
 * already emits.
 *
 * Mapping the same event to the same binding again does nothing; a binding
 * never emits the same event twice.
 *
 * Params:
 *  binding = The key and modifiers to map.
 *  eventName = Name of the event the binding should emit.
 */
void addKeyMapping(KeyBinding binding, StringId eventName) {
    addMapping(keyMapping, binding, eventName);
}

/**
 * Make the given key emit the given event, on top of any events it already
 * emits.
 *
 * Params:
 *  scanCode = The physical key to map.
 *  eventName = Name of the event the key should emit.
 *  modifiers = The modifiers that have to be held along with the key.
 *              Defaults to none, letting the key emit on its own.
 *  ignoredModifiers = The modifiers that have no say in whether the key emits,
 *              on top of the required ones. Defaults to $(D anyModifiers), so
 *              that only the required modifiers are taken into account at all.
 *              Pass $(D KeyboardKeyModifier.none) to have the key emit on
 *              exactly the modifiers it requires and nothing else.
 */
void addKeyMapping(KeyboardScanCode scanCode, StringId eventName,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none,
    KeyboardKeyModifier ignoredModifiers = anyModifiers) {
    addKeyMapping(KeyBinding(scanCode, modifiers, ignoredModifiers), eventName);
}

/**
 * Stop the given key binding from emitting the given event, leaving the other
 * events mapped to it in place.
 *
 * Params:
 *  binding = The key and modifiers to unmap the event from.
 *  eventName = Name of the event the binding should no longer emit.
 * Returns: Whether the binding was mapped to the event.
 */
bool removeKeyMapping(KeyBinding binding, StringId eventName) {
    return removeMapping(keyMapping, binding, eventName);
}

/// ditto
bool removeKeyMapping(KeyboardScanCode scanCode, StringId eventName,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none,
    KeyboardKeyModifier ignoredModifiers = anyModifiers) {
    return removeKeyMapping(KeyBinding(scanCode, modifiers, ignoredModifiers), eventName);
}

/**
 * Stop the given key binding from emitting any event at all.
 *
 * Only the binding with exactly these modifiers is unmapped; other bindings
 * on the same key are left alone. Use $(D removeAllKeyMappings) to unmap a
 * key regardless of the modifiers it is bound with.
 *
 * Params:
 *  binding = The key and modifiers to unmap.
 * Returns: Whether the binding was mapped to any event.
 */
bool removeKeyMappings(KeyBinding binding) {
    return keyMapping.remove(binding);
}

/// ditto
bool removeKeyMappings(KeyboardScanCode scanCode,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none,
    KeyboardKeyModifier ignoredModifiers = anyModifiers) {
    return removeKeyMappings(KeyBinding(scanCode, modifiers, ignoredModifiers));
}

/**
 * Stop the given key from emitting any event at all, with whichever
 * modifiers it is bound with.
 *
 * Params:
 *  scanCode = The physical key to unmap.
 * Returns: Whether the key was bound at all.
 */
bool removeAllKeyMappings(KeyboardScanCode scanCode) {
    return removeAllMappings(keyMapping, scanCode);
}

/**
 * Returns: Whether the given key binding emits the given event.
 */
bool hasKeyMapping(KeyBinding binding, StringId eventName) {
    return hasMapping(keyMapping, binding, eventName);
}

/// ditto
bool hasKeyMapping(KeyboardScanCode scanCode, StringId eventName,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none,
    KeyboardKeyModifier ignoredModifiers = anyModifiers) {
    return hasKeyMapping(KeyBinding(scanCode, modifiers, ignoredModifiers), eventName);
}

/**
 * Unmap every key, leaving no key emitting any event.
 */
void clearKeyMappings() {
    keyMapping.clear();
}

/**
 * Make the given mouse button binding emit the given event, on top of any
 * events it already emits.
 *
 * Mapping the same event to the same binding again does nothing; a binding
 * never emits the same event twice.
 *
 * Params:
 *  binding = The mouse button and modifiers to map.
 *  eventName = Name of the event the binding should emit.
 */
void addMouseButtonMapping(MouseButtonBinding binding, StringId eventName) {
    addMapping(mouseButtonMapping, binding, eventName);
}

/**
 * Make the given mouse button emit the given event, on top of any events it
 * already emits.
 *
 * Params:
 *  button = The mouse button to map.
 *  eventName = Name of the event the button should emit.
 *  modifiers = The keyboard modifiers that have to be held along with the
 *              button. Defaults to none, letting the button emit on its own.
 *  ignoredModifiers = The modifiers that have no say in whether the button
 *              emits, on top of the required ones. Defaults to
 *              $(D anyModifiers), so that only the required modifiers are taken
 *              into account at all. Pass $(D KeyboardKeyModifier.none) to have
 *              the button emit on exactly the modifiers it requires and nothing
 *              else.
 */
void addMouseButtonMapping(MouseButton button, StringId eventName,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none,
    KeyboardKeyModifier ignoredModifiers = anyModifiers) {
    addMouseButtonMapping(MouseButtonBinding(button, modifiers, ignoredModifiers), eventName);
}

/**
 * Stop the given mouse button binding from emitting the given event, leaving
 * the other events mapped to it in place.
 *
 * Params:
 *  binding = The mouse button and modifiers to unmap the event from.
 *  eventName = Name of the event the binding should no longer emit.
 * Returns: Whether the binding was mapped to the event.
 */
bool removeMouseButtonMapping(MouseButtonBinding binding, StringId eventName) {
    return removeMapping(mouseButtonMapping, binding, eventName);
}

/// ditto
bool removeMouseButtonMapping(MouseButton button, StringId eventName,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none,
    KeyboardKeyModifier ignoredModifiers = anyModifiers) {
    return removeMouseButtonMapping(MouseButtonBinding(button, modifiers, ignoredModifiers),
        eventName);
}

/**
 * Stop the given mouse button binding from emitting any event at all.
 *
 * Only the binding with exactly these modifiers is unmapped; other bindings on
 * the same button are left alone. Use $(D removeAllMouseButtonMappings) to
 * unmap a button regardless of the modifiers it is bound with.
 *
 * Params:
 *  binding = The mouse button and modifiers to unmap.
 * Returns: Whether the binding was mapped to any event.
 */
bool removeMouseButtonMappings(MouseButtonBinding binding) {
    return mouseButtonMapping.remove(binding);
}

/// ditto
bool removeMouseButtonMappings(MouseButton button,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none,
    KeyboardKeyModifier ignoredModifiers = anyModifiers) {
    return removeMouseButtonMappings(MouseButtonBinding(button, modifiers, ignoredModifiers));
}

/**
 * Stop the given mouse button from emitting any event at all, with whichever
 * modifiers it is bound with.
 *
 * Params:
 *  button = The mouse button to unmap.
 * Returns: Whether the button was bound at all.
 */
bool removeAllMouseButtonMappings(MouseButton button) {
    return removeAllMappings(mouseButtonMapping, button);
}

/**
 * Returns: Whether the given mouse button binding emits the given event.
 */
bool hasMouseButtonMapping(MouseButtonBinding binding, StringId eventName) {
    return hasMapping(mouseButtonMapping, binding, eventName);
}

/// ditto
bool hasMouseButtonMapping(MouseButton button, StringId eventName,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none,
    KeyboardKeyModifier ignoredModifiers = anyModifiers) {
    return hasMouseButtonMapping(MouseButtonBinding(button, modifiers, ignoredModifiers),
        eventName);
}

/**
 * Unmap every mouse button, leaving no button emitting any event.
 */
void clearMouseButtonMappings() {
    mouseButtonMapping.clear();
}

/**
 * Make the given mouse movement binding emit the given event, on top of any
 * events it already emits.
 *
 * Mapping the same event to the same binding again does nothing; a binding
 * never emits the same event twice.
 *
 * Params:
 *  binding = The axis and type of movement to map.
 *  eventName = Name of the event the binding should emit.
 */
void addMouseMovementMapping(MouseMovementBinding binding, StringId eventName) {
    addMapping(mouseMovementMapping, binding, eventName);
}

/**
 * Make movement along the given axis emit the given event, on top of any
 * events it already emits.
 *
 * Params:
 *  axis = The axis to map. $(D Axis.all) follows every axis the mouse moves
 *         along, emitting the event once per axis.
 *  eventName = Name of the event the movement should emit.
 *  movementType = Whether to follow the absolute position of the mouse or the
 *         distance it moved.
 */
void addMouseMovementMapping(Axis axis, StringId eventName, MouseMovementType movementType) {
    addMouseMovementMapping(MouseMovementBinding(axis, movementType), eventName);
}

/**
 * Stop the given mouse movement binding from emitting the given event, leaving
 * the other events mapped to it in place.
 *
 * Params:
 *  binding = The axis and type of movement to unmap the event from.
 *  eventName = Name of the event the binding should no longer emit.
 * Returns: Whether the binding was mapped to the event.
 */
bool removeMouseMovementMapping(MouseMovementBinding binding, StringId eventName) {
    return removeMapping(mouseMovementMapping, binding, eventName);
}

/// ditto
bool removeMouseMovementMapping(Axis axis, StringId eventName, MouseMovementType movementType) {
    return removeMouseMovementMapping(MouseMovementBinding(axis, movementType), eventName);
}

/**
 * Stop the given mouse movement binding from emitting any event at all.
 *
 * Only the binding on exactly this type of movement is unmapped; the bindings
 * on the same axis for the other type are left alone. Use
 * $(D removeAllMouseMovementMappings) to unmap an axis regardless of the type
 * of movement it is bound on.
 *
 * Params:
 *  binding = The axis and type of movement to unmap.
 * Returns: Whether the binding was mapped to any event.
 */
bool removeMouseMovementMappings(MouseMovementBinding binding) {
    return mouseMovementMapping.remove(binding);
}

/// ditto
bool removeMouseMovementMappings(Axis axis, MouseMovementType movementType) {
    return removeMouseMovementMappings(MouseMovementBinding(axis, movementType));
}

/**
 * Stop movement along the given axis from emitting any event at all, on
 * whichever type of movement it is bound.
 *
 * Params:
 *  axis = The axis to unmap.
 * Returns: Whether the axis was bound at all.
 */
bool removeAllMouseMovementMappings(Axis axis) {
    return removeAllMappings(mouseMovementMapping, axis);
}

/**
 * Returns: Whether the given mouse movement binding emits the given event.
 */
bool hasMouseMovementMapping(MouseMovementBinding binding, StringId eventName) {
    return hasMapping(mouseMovementMapping, binding, eventName);
}

/// ditto
bool hasMouseMovementMapping(Axis axis, StringId eventName, MouseMovementType movementType) {
    return hasMouseMovementMapping(MouseMovementBinding(axis, movementType), eventName);
}

/**
 * Unmap every axis, leaving no mouse movement emitting any event.
 */
void clearMouseMovementMappings() {
    mouseMovementMapping.clear();
}

/**
 * Make the given mouse scroll binding emit the given event, on top of any
 * events it already emits.
 *
 * Mapping the same event to the same binding again does nothing; a binding
 * never emits the same event twice.
 *
 * Params:
 *  binding = The axis to map.
 *  eventName = Name of the event the binding should emit.
 */
void addMouseScrollMapping(MouseScrollBinding binding, StringId eventName) {
    addMapping(mouseScrollMapping, binding, eventName);
}

/**
 * Make scrolling along the given axis emit the given event, on top of any
 * events it already emits.
 *
 * Params:
 *  axis = The axis to map. $(D Axis.all) follows both axes of the wheel,
 *         emitting the event once per axis.
 *  eventName = Name of the event the scroll should emit.
 */
void addMouseScrollMapping(Axis axis, StringId eventName) {
    addMouseScrollMapping(MouseScrollBinding(axis), eventName);
}

/**
 * Stop the given mouse scroll binding from emitting the given event, leaving
 * the other events mapped to it in place.
 *
 * Params:
 *  binding = The axis to unmap the event from.
 *  eventName = Name of the event the binding should no longer emit.
 * Returns: Whether the binding was mapped to the event.
 */
bool removeMouseScrollMapping(MouseScrollBinding binding, StringId eventName) {
    return removeMapping(mouseScrollMapping, binding, eventName);
}

/// ditto
bool removeMouseScrollMapping(Axis axis, StringId eventName) {
    return removeMouseScrollMapping(MouseScrollBinding(axis), eventName);
}

/**
 * Stop scrolling along the given axis from emitting any event at all.
 *
 * Params:
 *  binding = The axis to unmap.
 * Returns: Whether the binding was mapped to any event.
 */
bool removeMouseScrollMappings(MouseScrollBinding binding) {
    return mouseScrollMapping.remove(binding);
}

/// ditto
bool removeMouseScrollMappings(Axis axis) {
    return removeMouseScrollMappings(MouseScrollBinding(axis));
}

/**
 * Returns: Whether the given mouse scroll binding emits the given event.
 */
bool hasMouseScrollMapping(MouseScrollBinding binding, StringId eventName) {
    return hasMapping(mouseScrollMapping, binding, eventName);
}

/// ditto
bool hasMouseScrollMapping(Axis axis, StringId eventName) {
    return hasMouseScrollMapping(MouseScrollBinding(axis), eventName);
}

/**
 * Unmap every axis, leaving no mouse scroll emitting any event.
 */
void clearMouseScrollMappings() {
    mouseScrollMapping.clear();
}

void processInput() {
    KeyboardKeyEvent keyEvent;
    while (keyEvents.tryDequeue(keyEvent)) {
        if (keyEvent.action == InputEventAction.release) {
            emitReleaseEvents(keyMapping, keyEvent.scanCode);
        } else {
            emitKeyPressEvents(keyEvent.scanCode, keyEvent.modifiers);
        }
    }

    TextInputEvent textInputEvent;
    while (textInputEvents.tryDequeue(textInputEvent)) {
        foreach (handler; textInputHandlers) {
            handler(textInputEvent);
        }
    }

    MouseButtonEvent mouseButtonEvent;
    while (mouseButtonEvents.tryDequeue(mouseButtonEvent)) {
        if (mouseButtonEvent.action == InputEventAction.release) {
            emitReleaseEvents(mouseButtonMapping, mouseButtonEvent.button);
        } else {
            emitPressEvents(mouseButtonMapping, mouseButtonEvent.button,
                mouseButtonEvent.modifiers);
        }
    }

    MouseMovementEvent mouseMovementEvent;
    while (mouseMovementEvents.tryDequeue(mouseMovementEvent)) {
        emitMouseMovementEvents(mouseMovementEvent);
    }

    MouseScrollEvent mouseScrollEvent;
    while (mouseScrollEvents.tryDequeue(mouseScrollEvent)) {
        emitMouseScrollEvents(mouseScrollEvent);
    }
}

/**
 * Adds the given event to the events the binding emits, on top of the ones it
 * already emits. Shared by the keyboard and the mouse button mapping API.
 */
private void addMapping(BindingT)(ref HashMap!(BindingT, Array!StringId) mapping,
    BindingT binding, StringId eventName) {
    auto eventNames = mapping.getRef(binding);
    if (eventNames.isDefined) {
        auto mappedEvents = eventNames.value;
        if (!mappedEvents.exists(eventName)) {
            mappedEvents.add(eventName);
        }

        return;
    }

    Array!StringId newEvents;
    newEvents.add(eventName);
    mapping.put(binding, newEvents);
}

/**
 * Takes the given event away from the binding, unmapping the binding entirely
 * once it is left with no events at all.
 *
 * Returns: Whether the binding was mapped to the event.
 */
private bool removeMapping(BindingT)(ref HashMap!(BindingT, Array!StringId) mapping,
    BindingT binding, StringId eventName) {
    auto eventNames = mapping.getRef(binding);
    if (!eventNames.isDefined) {
        return false;
    }

    auto mappedEvents = eventNames.value;
    auto index = mappedEvents.find(eventName);
    if (index == -1) {
        return false;
    }

    mappedEvents.remove(index);
    if (mappedEvents.length == 0) {
        mapping.remove(binding);
    }

    return true;
}

/**
 * Unmaps every binding on the given key or button, whichever modifiers those
 * bindings name.
 *
 * Returns: Whether the key or button was bound at all.
 */
private bool removeAllMappings(BindingT, InputT)(ref HashMap!(BindingT, Array!StringId) mapping,
    InputT input) {
    Array!BindingT boundInputs;
    foreach (binding, eventNames; mapping) {
        if (bindsTo(binding, input)) {
            boundInputs.add(binding);
        }
    }

    foreach (binding; boundInputs) {
        mapping.remove(binding);
    }

    return boundInputs.length > 0;
}

/**
 * Returns: Whether the binding emits the given event.
 */
private bool hasMapping(BindingT)(ref HashMap!(BindingT, Array!StringId) mapping,
    BindingT binding, StringId eventName) {
    auto eventNames = mapping.getRef(binding);
    return eventNames.isDefined && eventNames.value.exists(eventName);
}

/**
 * Returns: Whether the binding is on the given physical key.
 */
private bool bindsTo(KeyBinding binding, KeyboardScanCode scanCode) {
    return binding.scanCode == scanCode;
}

/**
 * Returns: Whether the binding is on the given mouse button.
 */
private bool bindsTo(MouseButtonBinding binding, MouseButton button) {
    return binding.button == button;
}

/**
 * Returns: Whether the binding is on the given axis.
 */
private bool bindsTo(MouseMovementBinding binding, Axis axis) {
    return binding.axis == axis;
}

/**
 * The modifiers a binding can require, grouped by the key they stand for. A
 * group is satisfied by any of the sides the binding names in it.
 */
private immutable KeyboardKeyModifier[5] modifierGroups = [
    KeyboardKeyModifier.shift,
    KeyboardKeyModifier.ctrl,
    KeyboardKeyModifier.alt,
    KeyboardKeyModifier.gui,
    KeyboardKeyModifier.mode
];

/**
 * Returns: Whether the binding emits with the given modifiers held.
 */
private bool bindingMatches(BindingT)(BindingT binding, KeyboardKeyModifier heldModifiers) {
    uint required = binding.modifiers & bindableModifiers;

    // A required modifier is never ignored, however wide the ignore mask is.
    uint ignored = binding.ignoredModifiers & ~required;
    uint held = heldModifiers & bindableModifiers & ~ignored;

    // Holding a modifier the binding did not ignore keeps it silent, so that a
    // binding narrowed down to ctrl+S does not fire on ctrl+shift+S.
    if (held & ~required) {
        return false;
    }

    // Every modifier the binding asks for has to be held on one of the sides
    // it named, so that shift takes either key but leftShift takes only its
    // own.
    foreach (group; modifierGroups) {
        if ((required & group) != 0 && (held & required & group) == 0) {
            return false;
        }
    }

    return true;
}

/**
 * Returns: The modifier a physical key is itself, or none for a key that is
 *          not a modifier.
 */
private KeyboardKeyModifier modifierFlagOf(KeyboardScanCode scanCode) {
    switch (scanCode) {
    case KeyboardScanCode.leftShift:
        return KeyboardKeyModifier.leftShift;
    case KeyboardScanCode.rightShift:
        return KeyboardKeyModifier.rightShift;
    case KeyboardScanCode.leftCtrl:
        return KeyboardKeyModifier.leftCtrl;
    case KeyboardScanCode.rightCtrl:
        return KeyboardKeyModifier.rightCtrl;
    case KeyboardScanCode.leftAlt:
        return KeyboardKeyModifier.leftAlt;
    case KeyboardScanCode.rightAlt:
        // The right alt key doubles as AltGr on the layouts that have one, in
        // which case it reports the mode modifier on top of its own.
        return cast(KeyboardKeyModifier)(KeyboardKeyModifier.rightAlt | KeyboardKeyModifier.mode);
    case KeyboardScanCode.leftGui:
        return KeyboardKeyModifier.leftGui;
    case KeyboardScanCode.rightGui:
        return KeyboardKeyModifier.rightGui;
    case KeyboardScanCode.mode:
        return KeyboardKeyModifier.mode;
    default:
        return KeyboardKeyModifier.none;
    }
}

/**
 * Emits the events of every keyboard binding on the given key that the held
 * modifiers satisfy, at full magnitude.
 *
 * A modifier key reports itself among the modifiers of its own event, which is
 * left out here so that a binding on a modifier key does not need to require
 * itself. Mouse buttons have no such thing to account for and go straight to
 * $(D emitPressEvents).
 */
private void emitKeyPressEvents(KeyboardScanCode scanCode, KeyboardKeyModifier modifiers) {
    auto heldModifiers = cast(KeyboardKeyModifier)(modifiers & ~modifierFlagOf(scanCode));
    emitPressEvents(keyMapping, scanCode, heldModifiers);
}

/**
 * Emits the events of every binding on the given key or mouse button that the
 * held modifiers satisfy, at full magnitude.
 */
private void emitPressEvents(BindingT, InputT)(ref HashMap!(BindingT, Array!StringId) mapping,
    InputT input, KeyboardKeyModifier heldModifiers) {
    foreach (binding, eventNames; mapping) {
        if (!bindsTo(binding, input) || !bindingMatches(binding, heldModifiers)) {
            continue;
        }

        foreach (i; 0 .. eventNames.length) {
            eventQueue.enqueue(Event(eventNames[i], 1));
        }
    }
}

/**
 * Emits the events of every binding on the given key or mouse button at zero
 * magnitude, whatever modifiers those bindings name.
 *
 * Modifiers are deliberately not taken into account here: letting go of shift
 * before letting go of the key it modified would otherwise leave the events
 * of a shift binding stuck at full magnitude. Releasing an event that was
 * never pressed only sets it to the zero it already was.
 */
private void emitReleaseEvents(BindingT, InputT)(ref HashMap!(BindingT, Array!StringId) mapping,
    InputT input) {
    foreach (binding, eventNames; mapping) {
        if (!bindsTo(binding, input)) {
            continue;
        }

        foreach (i; 0 .. eventNames.length) {
            eventQueue.enqueue(Event(eventNames[i], 0));
        }
    }
}

/**
 * Emits the events of every binding the given mouse movement satisfies, each
 * at the magnitude the mouse moved along the axis of the binding.
 *
 * A movement that carries every axis at once is taken apart here, so that a
 * binding on a single axis emits whether or not the platform is reporting the
 * axes separately. Which of the two the platform reports is a matter of how
 * finely it can follow the mouse, not of which bindings emit.
 *
 * A type of movement that was turned off is not held back here: the platform is
 * the one that stops reporting it, and a platform that keeps doing so anyway
 * says as much through $(D isMouseMovementEnabled) rather than being talked
 * over.
 */
private void emitMouseMovementEvents(MouseMovementEvent movementEvent) {
    if (movementEvent.axis == Axis.all || movementEvent.axis == Axis.x) {
        emitAxisMovementEvents(Axis.x, movementEvent.xPosition, movementEvent.movementType);
    }

    if (movementEvent.axis == Axis.all || movementEvent.axis == Axis.y) {
        emitAxisMovementEvents(Axis.y, movementEvent.yPosition, movementEvent.movementType);
    }

    // A mouse has no third axis, so a movement along one carries no position to
    // emit and is left alone here.
}

/**
 * Emits the events of every binding that follows the given axis on the given
 * type of movement, at the magnitude the mouse moved along it.
 *
 * A binding on $(D Axis.all) follows every axis, and so emits its events once
 * for each axis that the movement carried.
 */
private void emitAxisMovementEvents(Axis axis, double position, MouseMovementType movementType) {
    foreach (binding, eventNames; mouseMovementMapping) {
        if (binding.movementType != movementType ||
            (binding.axis != axis && binding.axis != Axis.all)) {
            continue;
        }

        foreach (i; 0 .. eventNames.length) {
            eventQueue.enqueue(Event(eventNames[i], cast(Magnitude) position));
        }
    }
}

/**
 * Emits the events of every binding the given scroll satisfies, each at the
 * distance the wheel was scrolled along the axis of the binding.
 *
 * A scroll always carries both axes, so both are taken apart here: a wheel that
 * only turns one way reports the other axis at the zero it did not move.
 */
private void emitMouseScrollEvents(MouseScrollEvent scrollEvent) {
    emitAxisScrollEvents(Axis.x, scrollEvent.xOffset);
    emitAxisScrollEvents(Axis.y, scrollEvent.yOffset);
}

/**
 * Emits the events of every binding that follows the given axis, at the distance
 * the wheel was scrolled along it.
 *
 * A binding on $(D Axis.all) follows both axes, and so emits its events once for
 * each of them.
 */
private void emitAxisScrollEvents(Axis axis, double offset) {
    foreach (binding, eventNames; mouseScrollMapping) {
        if (binding.axis != axis && binding.axis != Axis.all) {
            continue;
        }

        foreach (i; 0 .. eventNames.length) {
            eventQueue.enqueue(Event(eventNames[i], cast(Magnitude) offset));
        }
    }
}

/**
 * The ways of giving input a platform can be asked to report.
 *
 * $(D keyboard) and $(D textInput) are both the keyboard, followed for a
 * different purpose: the first reports the keys that were pressed, to be bound
 * to game controls, the second the text those keys typed. They are asked for
 * separately, so that a game that has nothing to type into is not made to carry
 * the text the player's controls happen to spell out.
 */
enum InputMethod : ubyte {
    keyboard = 1 << 0,
    mouse = 1 << 1,
    textInput = 1 << 2
}

/**
 * Physical keyboard keys, identified by their position on a US layout
 * regardless of the layout actually in use.
 *
 * This list is based off of SDL2's scan code list, with GLFW's F25 added.
 * Not all platforms may map all of them.
 *
 * Scan codes are what input should be bound to: a key keeps the same scan
 * code on every layout, so a binding stays under the same finger. Use
 * $(D KeyboardKeyCode) instead when the character a key produces matters,
 * such as for text input or for labelling a binding in a UI.
 */
enum KeyboardScanCode : uint {
    unknown,
    a,
    acBack,
    acBookmarks,
    acForward,
    acHome,
    acRefresh,
    acSearch,
    acStop,
    again,
    alterase,
    apostrophe,
    app1,
    app2,
    application,
    audioMute,
    audioNext,
    audioPlay,
    audioPrev,
    audioStop,
    b,
    backslash,
    backspace,
    brightnessDown,
    brightnessUp,
    c,
    calculator,
    cancel,
    capslock,
    clear,
    clearAgain,
    comma,
    computer,
    copy,
    crsel,
    currencySubunit,
    currencyUnit,
    cut,
    d,
    decimalSeparator,
    deleteKey,
    displaySwitch,
    down,
    e,
    eight,
    eject,
    end,
    equals,
    escape,
    execute,
    exsel,
    f,
    f1,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f2,
    f20,
    f21,
    f22,
    f23,
    f24,
    f25,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    find,
    five,
    four,
    g,
    grave,
    h,
    help,
    home,
    i,
    insert,
    international1,
    international2,
    international3,
    international4,
    international5,
    international6,
    international7,
    international8,
    international9,
    j,
    k,
    kbdIllumDown,
    kbdIllumToggle,
    kbdIllumUp,
    keypad00,
    keypad000,
    keypadComma,
    keypadDivide,
    keypadEight,
    keypadEnter,
    keypadEquals,
    keypadEqualsas400,
    keypadFive,
    keypadFour,
    keypadMinus,
    keypadMultiply,
    keypadNine,
    keypadOne,
    keypadPeriod,
    keypadPlus,
    keypadSeven,
    keypadSix,
    keypadThree,
    keypadTwo,
    keypadZero,
    kpA,
    kpAmpersand,
    kpAt,
    kpB,
    kpBackspace,
    kpBinary,
    kpC,
    kpClear,
    kpClearentry,
    kpColon,
    kpD,
    kpDblampersand,
    kpDblverticalbar,
    kpDecimal,
    kpE,
    kpExclam,
    kpF,
    kpGreater,
    kpHash,
    kpHexadecimal,
    kpLeftbrace,
    kpLeftparen,
    kpLess,
    kpMemadd,
    kpMemclear,
    kpMemdivide,
    kpMemmultiply,
    kpMemrecall,
    kpMemstore,
    kpMemsubtract,
    kpOctal,
    kpPercent,
    kpPlusminus,
    kpPower,
    kpRightbrace,
    kpRightparen,
    kpSpace,
    kpTab,
    kpVerticalbar,
    kpXor,
    l,
    leftAlt,
    lang1,
    lang2,
    lang3,
    lang4,
    lang5,
    lang6,
    lang7,
    lang8,
    lang9,
    leftCtrl,
    left,
    leftBracket,
    leftGui,
    leftShift,
    m,
    mail,
    mediaSelect,
    menu,
    minus,
    mode,
    mute,
    n,
    nine,
    nonusBackslash,
    nonusHash,
    numlockClear,
    o,
    one,
    oper,
    outKey,
    p,
    pageDown,
    pageUp,
    paste,
    pause,
    period,
    power,
    printscreen,
    prior,
    q,
    r,
    rightAlt,
    rightCtrl,
    enter,
    enter2,
    rightGui,
    right,
    rightBracket,
    rightShift,
    s,
    scrolllock,
    select,
    semicolon,
    separator,
    seven,
    six,
    slash,
    sleep,
    space,
    stop,
    sysreq,
    t,
    tab,
    thousandsSeparator,
    three,
    two,
    u,
    undo,
    up,
    v,
    volumedown,
    volumeup,
    w,
    www,
    x,
    y,
    z,
    zero
}

/**
 * Bit set in a $(D KeyboardKeyCode) to mark it as carrying a scan code
 * instead of a Unicode code point.
 *
 * Code points reach up to 0x10FFFF, leaving this bit free to tell the two
 * apart. Same scheme as the one SDL2 uses for its key codes.
 */
enum uint scanCodeMask = 1 << 30;

/**
 * The key a keyboard event resolved to, with the keyboard layout and the
 * modifiers held at the time taken into account.
 *
 * A key that produces a character has that character's Unicode code point as
 * its key code, and can be compared against a character literal directly:
 * `keyEvent.keyCode == 'a'`. Only the keys that produce no character are
 * named here; their key code is the scan code of the key with
 * $(D scanCodeMask) set. Use $(D toKeyCode) to form one from a scan code.
 *
 * Unlike SDL2's key codes these are modifier-dependent, following what the
 * platform reports: shift+a produces 'A' rather than 'a', and a key behind
 * AltGr produces the character AltGr puts on it. Keypad keys produce their
 * character while Num Lock is on and their named key code while it is off.
 *
 * Key codes are meant for text and for showing a user which key to press.
 * Bind input to $(D KeyboardScanCode) instead, which does not move around
 * when the layout changes.
 */
enum KeyboardKeyCode : uint {
    unknown = 0,
    acBack = scanCodeMask | KeyboardScanCode.acBack,
    acBookmarks = scanCodeMask | KeyboardScanCode.acBookmarks,
    acForward = scanCodeMask | KeyboardScanCode.acForward,
    acHome = scanCodeMask | KeyboardScanCode.acHome,
    acRefresh = scanCodeMask | KeyboardScanCode.acRefresh,
    acSearch = scanCodeMask | KeyboardScanCode.acSearch,
    acStop = scanCodeMask | KeyboardScanCode.acStop,
    again = scanCodeMask | KeyboardScanCode.again,
    alterase = scanCodeMask | KeyboardScanCode.alterase,
    app1 = scanCodeMask | KeyboardScanCode.app1,
    app2 = scanCodeMask | KeyboardScanCode.app2,
    application = scanCodeMask | KeyboardScanCode.application,
    audioMute = scanCodeMask | KeyboardScanCode.audioMute,
    audioNext = scanCodeMask | KeyboardScanCode.audioNext,
    audioPlay = scanCodeMask | KeyboardScanCode.audioPlay,
    audioPrev = scanCodeMask | KeyboardScanCode.audioPrev,
    audioStop = scanCodeMask | KeyboardScanCode.audioStop,
    backspace = scanCodeMask | KeyboardScanCode.backspace,
    brightnessDown = scanCodeMask | KeyboardScanCode.brightnessDown,
    brightnessUp = scanCodeMask | KeyboardScanCode.brightnessUp,
    calculator = scanCodeMask | KeyboardScanCode.calculator,
    cancel = scanCodeMask | KeyboardScanCode.cancel,
    capslock = scanCodeMask | KeyboardScanCode.capslock,
    clear = scanCodeMask | KeyboardScanCode.clear,
    clearAgain = scanCodeMask | KeyboardScanCode.clearAgain,
    computer = scanCodeMask | KeyboardScanCode.computer,
    copy = scanCodeMask | KeyboardScanCode.copy,
    crsel = scanCodeMask | KeyboardScanCode.crsel,
    currencySubunit = scanCodeMask | KeyboardScanCode.currencySubunit,
    currencyUnit = scanCodeMask | KeyboardScanCode.currencyUnit,
    cut = scanCodeMask | KeyboardScanCode.cut,
    decimalSeparator = scanCodeMask | KeyboardScanCode.decimalSeparator,
    deleteKey = scanCodeMask | KeyboardScanCode.deleteKey,
    displaySwitch = scanCodeMask | KeyboardScanCode.displaySwitch,
    down = scanCodeMask | KeyboardScanCode.down,
    eject = scanCodeMask | KeyboardScanCode.eject,
    end = scanCodeMask | KeyboardScanCode.end,
    escape = scanCodeMask | KeyboardScanCode.escape,
    execute = scanCodeMask | KeyboardScanCode.execute,
    exsel = scanCodeMask | KeyboardScanCode.exsel,
    f1 = scanCodeMask | KeyboardScanCode.f1,
    f10 = scanCodeMask | KeyboardScanCode.f10,
    f11 = scanCodeMask | KeyboardScanCode.f11,
    f12 = scanCodeMask | KeyboardScanCode.f12,
    f13 = scanCodeMask | KeyboardScanCode.f13,
    f14 = scanCodeMask | KeyboardScanCode.f14,
    f15 = scanCodeMask | KeyboardScanCode.f15,
    f16 = scanCodeMask | KeyboardScanCode.f16,
    f17 = scanCodeMask | KeyboardScanCode.f17,
    f18 = scanCodeMask | KeyboardScanCode.f18,
    f19 = scanCodeMask | KeyboardScanCode.f19,
    f2 = scanCodeMask | KeyboardScanCode.f2,
    f20 = scanCodeMask | KeyboardScanCode.f20,
    f21 = scanCodeMask | KeyboardScanCode.f21,
    f22 = scanCodeMask | KeyboardScanCode.f22,
    f23 = scanCodeMask | KeyboardScanCode.f23,
    f24 = scanCodeMask | KeyboardScanCode.f24,
    f25 = scanCodeMask | KeyboardScanCode.f25,
    f3 = scanCodeMask | KeyboardScanCode.f3,
    f4 = scanCodeMask | KeyboardScanCode.f4,
    f5 = scanCodeMask | KeyboardScanCode.f5,
    f6 = scanCodeMask | KeyboardScanCode.f6,
    f7 = scanCodeMask | KeyboardScanCode.f7,
    f8 = scanCodeMask | KeyboardScanCode.f8,
    f9 = scanCodeMask | KeyboardScanCode.f9,
    find = scanCodeMask | KeyboardScanCode.find,
    help = scanCodeMask | KeyboardScanCode.help,
    home = scanCodeMask | KeyboardScanCode.home,
    insert = scanCodeMask | KeyboardScanCode.insert,
    international1 = scanCodeMask | KeyboardScanCode.international1,
    international2 = scanCodeMask | KeyboardScanCode.international2,
    international3 = scanCodeMask | KeyboardScanCode.international3,
    international4 = scanCodeMask | KeyboardScanCode.international4,
    international5 = scanCodeMask | KeyboardScanCode.international5,
    international6 = scanCodeMask | KeyboardScanCode.international6,
    international7 = scanCodeMask | KeyboardScanCode.international7,
    international8 = scanCodeMask | KeyboardScanCode.international8,
    international9 = scanCodeMask | KeyboardScanCode.international9,
    kbdIllumDown = scanCodeMask | KeyboardScanCode.kbdIllumDown,
    kbdIllumToggle = scanCodeMask | KeyboardScanCode.kbdIllumToggle,
    kbdIllumUp = scanCodeMask | KeyboardScanCode.kbdIllumUp,
    keypad00 = scanCodeMask | KeyboardScanCode.keypad00,
    keypad000 = scanCodeMask | KeyboardScanCode.keypad000,
    keypadComma = scanCodeMask | KeyboardScanCode.keypadComma,
    keypadDivide = scanCodeMask | KeyboardScanCode.keypadDivide,
    keypadEight = scanCodeMask | KeyboardScanCode.keypadEight,
    keypadEnter = scanCodeMask | KeyboardScanCode.keypadEnter,
    keypadEquals = scanCodeMask | KeyboardScanCode.keypadEquals,
    keypadEqualsas400 = scanCodeMask | KeyboardScanCode.keypadEqualsas400,
    keypadFive = scanCodeMask | KeyboardScanCode.keypadFive,
    keypadFour = scanCodeMask | KeyboardScanCode.keypadFour,
    keypadMinus = scanCodeMask | KeyboardScanCode.keypadMinus,
    keypadMultiply = scanCodeMask | KeyboardScanCode.keypadMultiply,
    keypadNine = scanCodeMask | KeyboardScanCode.keypadNine,
    keypadOne = scanCodeMask | KeyboardScanCode.keypadOne,
    keypadPeriod = scanCodeMask | KeyboardScanCode.keypadPeriod,
    keypadPlus = scanCodeMask | KeyboardScanCode.keypadPlus,
    keypadSeven = scanCodeMask | KeyboardScanCode.keypadSeven,
    keypadSix = scanCodeMask | KeyboardScanCode.keypadSix,
    keypadThree = scanCodeMask | KeyboardScanCode.keypadThree,
    keypadTwo = scanCodeMask | KeyboardScanCode.keypadTwo,
    keypadZero = scanCodeMask | KeyboardScanCode.keypadZero,
    kpA = scanCodeMask | KeyboardScanCode.kpA,
    kpAmpersand = scanCodeMask | KeyboardScanCode.kpAmpersand,
    kpAt = scanCodeMask | KeyboardScanCode.kpAt,
    kpB = scanCodeMask | KeyboardScanCode.kpB,
    kpBackspace = scanCodeMask | KeyboardScanCode.kpBackspace,
    kpBinary = scanCodeMask | KeyboardScanCode.kpBinary,
    kpC = scanCodeMask | KeyboardScanCode.kpC,
    kpClear = scanCodeMask | KeyboardScanCode.kpClear,
    kpClearentry = scanCodeMask | KeyboardScanCode.kpClearentry,
    kpColon = scanCodeMask | KeyboardScanCode.kpColon,
    kpD = scanCodeMask | KeyboardScanCode.kpD,
    kpDblampersand = scanCodeMask | KeyboardScanCode.kpDblampersand,
    kpDblverticalbar = scanCodeMask | KeyboardScanCode.kpDblverticalbar,
    kpDecimal = scanCodeMask | KeyboardScanCode.kpDecimal,
    kpE = scanCodeMask | KeyboardScanCode.kpE,
    kpExclam = scanCodeMask | KeyboardScanCode.kpExclam,
    kpF = scanCodeMask | KeyboardScanCode.kpF,
    kpGreater = scanCodeMask | KeyboardScanCode.kpGreater,
    kpHash = scanCodeMask | KeyboardScanCode.kpHash,
    kpHexadecimal = scanCodeMask | KeyboardScanCode.kpHexadecimal,
    kpLeftbrace = scanCodeMask | KeyboardScanCode.kpLeftbrace,
    kpLeftparen = scanCodeMask | KeyboardScanCode.kpLeftparen,
    kpLess = scanCodeMask | KeyboardScanCode.kpLess,
    kpMemadd = scanCodeMask | KeyboardScanCode.kpMemadd,
    kpMemclear = scanCodeMask | KeyboardScanCode.kpMemclear,
    kpMemdivide = scanCodeMask | KeyboardScanCode.kpMemdivide,
    kpMemmultiply = scanCodeMask | KeyboardScanCode.kpMemmultiply,
    kpMemrecall = scanCodeMask | KeyboardScanCode.kpMemrecall,
    kpMemstore = scanCodeMask | KeyboardScanCode.kpMemstore,
    kpMemsubtract = scanCodeMask | KeyboardScanCode.kpMemsubtract,
    kpOctal = scanCodeMask | KeyboardScanCode.kpOctal,
    kpPercent = scanCodeMask | KeyboardScanCode.kpPercent,
    kpPlusminus = scanCodeMask | KeyboardScanCode.kpPlusminus,
    kpPower = scanCodeMask | KeyboardScanCode.kpPower,
    kpRightbrace = scanCodeMask | KeyboardScanCode.kpRightbrace,
    kpRightparen = scanCodeMask | KeyboardScanCode.kpRightparen,
    kpSpace = scanCodeMask | KeyboardScanCode.kpSpace,
    kpTab = scanCodeMask | KeyboardScanCode.kpTab,
    kpVerticalbar = scanCodeMask | KeyboardScanCode.kpVerticalbar,
    kpXor = scanCodeMask | KeyboardScanCode.kpXor,
    leftAlt = scanCodeMask | KeyboardScanCode.leftAlt,
    lang1 = scanCodeMask | KeyboardScanCode.lang1,
    lang2 = scanCodeMask | KeyboardScanCode.lang2,
    lang3 = scanCodeMask | KeyboardScanCode.lang3,
    lang4 = scanCodeMask | KeyboardScanCode.lang4,
    lang5 = scanCodeMask | KeyboardScanCode.lang5,
    lang6 = scanCodeMask | KeyboardScanCode.lang6,
    lang7 = scanCodeMask | KeyboardScanCode.lang7,
    lang8 = scanCodeMask | KeyboardScanCode.lang8,
    lang9 = scanCodeMask | KeyboardScanCode.lang9,
    leftCtrl = scanCodeMask | KeyboardScanCode.leftCtrl,
    left = scanCodeMask | KeyboardScanCode.left,
    leftGui = scanCodeMask | KeyboardScanCode.leftGui,
    leftShift = scanCodeMask | KeyboardScanCode.leftShift,
    mail = scanCodeMask | KeyboardScanCode.mail,
    mediaSelect = scanCodeMask | KeyboardScanCode.mediaSelect,
    menu = scanCodeMask | KeyboardScanCode.menu,
    mode = scanCodeMask | KeyboardScanCode.mode,
    mute = scanCodeMask | KeyboardScanCode.mute,
    numlockClear = scanCodeMask | KeyboardScanCode.numlockClear,
    oper = scanCodeMask | KeyboardScanCode.oper,
    outKey = scanCodeMask | KeyboardScanCode.outKey,
    pageDown = scanCodeMask | KeyboardScanCode.pageDown,
    pageUp = scanCodeMask | KeyboardScanCode.pageUp,
    paste = scanCodeMask | KeyboardScanCode.paste,
    pause = scanCodeMask | KeyboardScanCode.pause,
    power = scanCodeMask | KeyboardScanCode.power,
    printscreen = scanCodeMask | KeyboardScanCode.printscreen,
    prior = scanCodeMask | KeyboardScanCode.prior,
    rightAlt = scanCodeMask | KeyboardScanCode.rightAlt,
    rightCtrl = scanCodeMask | KeyboardScanCode.rightCtrl,
    enter = scanCodeMask | KeyboardScanCode.enter,
    enter2 = scanCodeMask | KeyboardScanCode.enter2,
    rightGui = scanCodeMask | KeyboardScanCode.rightGui,
    right = scanCodeMask | KeyboardScanCode.right,
    rightShift = scanCodeMask | KeyboardScanCode.rightShift,
    scrolllock = scanCodeMask | KeyboardScanCode.scrolllock,
    select = scanCodeMask | KeyboardScanCode.select,
    separator = scanCodeMask | KeyboardScanCode.separator,
    sleep = scanCodeMask | KeyboardScanCode.sleep,
    stop = scanCodeMask | KeyboardScanCode.stop,
    sysreq = scanCodeMask | KeyboardScanCode.sysreq,
    tab = scanCodeMask | KeyboardScanCode.tab,
    thousandsSeparator = scanCodeMask | KeyboardScanCode.thousandsSeparator,
    undo = scanCodeMask | KeyboardScanCode.undo,
    up = scanCodeMask | KeyboardScanCode.up,
    volumedown = scanCodeMask | KeyboardScanCode.volumedown,
    volumeup = scanCodeMask | KeyboardScanCode.volumeup,
    www = scanCodeMask | KeyboardScanCode.www
}

/**
 * Returns the key code of a key that produces no character, being the
 * given scan code marked with $(D scanCodeMask).
 */
KeyboardKeyCode toKeyCode(KeyboardScanCode scanCode) {
    if (scanCode == KeyboardScanCode.unknown) {
        return KeyboardKeyCode.unknown;
    }

    return cast(KeyboardKeyCode)(scanCodeMask | scanCode);
}

/**
 * Types of action that can be performed on input,
 * such as pressing a keyboard button or releasing a gamepad button.
 */
enum InputEventAction : ubyte {
    unknown,
    press,
    release,
    repeat
}

/**
 * Modifiers that are typically key buttons pressed while pressing another key.
 *
 * Only the side-specific flags are ever reported on their own: an event names
 * the physical modifier key that was held. The side-independent names are
 * masks over both of their sides, as in SDL2, so testing one of them matches
 * either key. Test them with `&` rather than `==`:
 * `modifiers & KeyboardKeyModifier.ctrl` is true for both control keys.
 *
 * $(D numlock) and $(D capslock) report the state of a lock rather than a key
 * being held. $(D mode) is the AltGr key, which is a held key like the rest.
 */
enum KeyboardKeyModifier : uint {
    none = 0,
    leftShift = 1 << 1,
    rightShift = 1 << 2,
    leftCtrl = 1 << 3,
    rightCtrl = 1 << 4,
    leftAlt = 1 << 5,
    rightAlt = 1 << 6,
    leftGui = 1 << 7,
    rightGui = 1 << 8,
    numlock = 1 << 9,
    capslock = 1 << 10,
    mode = 1 << 11,
    shift = leftShift | rightShift,
    ctrl = leftCtrl | rightCtrl,
    alt = leftAlt | rightAlt,
    gui = leftGui | rightGui
}

/**
 * The modifiers a key binding is allowed to require.
 *
 * The lock modifiers are left out: they report a toggle state rather than a
 * key being held, so taking them into account would make every binding stop
 * working while caps lock happens to be on. They are still reported on the
 * events themselves.
 */
enum KeyboardKeyModifier bindableModifiers = cast(KeyboardKeyModifier)(
        KeyboardKeyModifier.shift | KeyboardKeyModifier.ctrl |
            KeyboardKeyModifier.alt | KeyboardKeyModifier.gui |
            KeyboardKeyModifier.mode);

/**
 * The ignore mask a binding carries by default: every modifier has its say
 * taken away, so the key emits whatever the player happens to be holding.
 */
enum KeyboardKeyModifier anyModifiers = bindableModifiers;

/**
 * A physical key together with the modifiers that have to be held for it to
 * emit its events.
 *
 * A binding ignores modifiers by default: W walks the player forward whether
 * or not shift, ctrl or anything else is held. That is what lets a modifier
 * carry a meaning of its own without breaking the keys pressed alongside it:
 *
 * ---
 * // W walks whatever is held, and shift runs on its own.
 * addKeyMapping(KeyboardScanCode.w, sid("ev_walkForward"));
 * addKeyMapping(KeyboardScanCode.leftShift, sid("ev_run"));
 * ---
 *
 * $(D modifiers) names the modifiers that then do have to be held. Naming a
 * side-independent modifier such as $(D KeyboardKeyModifier.shift) takes
 * either side, naming $(D KeyboardKeyModifier.leftShift) takes only that key.
 * The modifiers not named still have no say, so shift+W emits below whether or
 * not ctrl is held as well:
 *
 * ---
 * addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"),
 *     KeyboardKeyModifier.shift);
 * ---
 *
 * $(D ignoredModifiers) is what hands that say back. Narrowing it to
 * $(D KeyboardKeyModifier.none) leaves no modifier ignored, so the binding
 * emits on exactly the modifiers it names and nothing else, which is how a
 * key that means something different under every modifier is bound:
 *
 * ---
 * // Ctrl+S saves, and stays out of the way of ctrl+shift+S.
 * addKeyMapping(KeyboardScanCode.s, sid("ev_save"),
 *     KeyboardKeyModifier.ctrl, KeyboardKeyModifier.none);
 *
 * // S on its own, with nothing else held at all.
 * addKeyMapping(KeyboardScanCode.s, sid("ev_strafeBackward"),
 *     KeyboardKeyModifier.none, KeyboardKeyModifier.none);
 * ---
 *
 * A required modifier is never ignored, so the two can be mixed freely: the
 * ignore mask only ever covers the modifiers $(D modifiers) leaves out.
 */
struct KeyBinding {
    /// The physical key to bind to.
    KeyboardScanCode scanCode;

    /// The modifiers that have to be held along with it, if any.
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none;

    /**
     * The modifiers that have no say in whether the binding emits, on top of
     * the ones it requires. Defaults to all of them, so that only the required
     * modifiers are taken into account at all.
     */
    KeyboardKeyModifier ignoredModifiers = anyModifiers;

    bool opEquals(ref const typeof(this) other) const {
        return scanCode == other.scanCode && modifiers == other.modifiers &&
            ignoredModifiers == other.ignoredModifiers;
    }

    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

    ulong toHash() nothrow @trusted const {
        ulong packed = (cast(ulong) modifiers << 32) | scanCode;
        ulong ignored = ignoredModifiers;
        return hashOf(packed) * 33 + hashOf(ignored);
    }
}

/**
 * An event emitted when a keyboard key is pressed, held or released.
 *
 * The key it happened to is identified in two ways: $(D scanCode) names the
 * physical key, $(D keyCode) names what that key resolved to under the active
 * keyboard layout.
 *
 * Note that those two names carry the opposite meaning of GLFW's similarly
 * named key callback parameters, where a key is the physical key and a
 * scancode is a raw platform-specific number. These follow SDL2's naming
 * instead, where a scan code is the physical key.
 */
struct KeyboardKeyEvent {
    /**
     * Physical key that was pressed, independent of keyboard layout.
     * The same key always reports the same scan code, whereas the
     * character it produces may differ per layout.
     */
    KeyboardScanCode scanCode;

    /**
     * The key the physical key resolved to under the active keyboard layout
     * and the modifiers held at the time: the Unicode code point of the
     * character it produced, or a named key code for keys that produce no
     * character, such as an arrow key or a modifier.
     */
    KeyboardKeyCode keyCode;

    /**
     * Whether the key was pressed, released or is being repeated.
     * Holding a key down makes the operating system emit a stream of
     * repeats after an initial press, at a rate the user configures.
     */
    InputEventAction action;

    /**
     * Bit mask of the modifiers that were active during the event,
     * including the modifier being pressed or released in its own event.
     */
    KeyboardKeyModifier modifiers;
}

/**
 * A handler that text typed by the user is handed to.
 *
 * Add one to $(D textInputHandlers) to receive the characters the player types.
 */
alias TextInputHandlerFunction = void delegate(ref const TextInputEvent);

/**
 * An event emitted when the user types a character.
 *
 * This is text as the platform composed it rather than the keys that went into
 * it: the keyboard layout, the modifiers held and whatever input method the
 * user types their language with are all already taken into account, so a
 * character arrives here the way it would in a text field. That makes it the
 * one thing to build text entry on; a character that no single key produces,
 * such as one typed with a dead key or composed through an IME, never shows up
 * as a $(D KeyboardKeyEvent) at all.
 *
 * Only characters are reported, so the keys that edit text rather than produce
 * it, such as backspace, enter and the arrow keys, are not among them. Those
 * are keys like any other: take them from $(D KeyboardKeyEvent), whose
 * $(D keyCode) names them.
 *
 * Holding a key down types its character over and over, the way it does in a
 * text field: a repeat is reported as another character rather than as
 * something to be told apart from the first one.
 *
 * This works like GLFW's character callback, and unlike its key callback, which
 * $(D KeyboardKeyEvent) covers instead.
 */
struct TextInputEvent {
    /**
     * The Unicode code point of the character that was typed. It can be
     * compared against a character literal directly:
     * `textInputEvent.codePoint == 'a'`.
     */
    dchar codePoint;
}

/**
 * Available mouse buttons.
 *
 * These weird-ass gamer mice with a million buttons are not fully supported.
 */
enum MouseButton : uint {
    unknown,
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    left = MouseButton.one,
    right = MouseButton.two,
    middle = MouseButton.three,
}

/**
 * A mouse button together with the keyboard modifiers that have to be held for
 * it to emit its events.
 *
 * Works exactly like $(D KeyBinding), only on a mouse button instead of a
 * physical key: a binding ignores every modifier by default, $(D modifiers)
 * names the ones that do have to be held, and $(D ignoredModifiers) hands the
 * say back to the ones it names:
 *
 * ---
 * // The left button fires whatever is held, and ctrl+left aims down the sight
 * // without also firing.
 * addMouseButtonMapping(MouseButton.left, sid("ev_fire"),
 *     KeyboardKeyModifier.none, KeyboardKeyModifier.ctrl);
 * addMouseButtonMapping(MouseButton.left, sid("ev_aim"),
 *     KeyboardKeyModifier.ctrl, KeyboardKeyModifier.none);
 * ---
 */
struct MouseButtonBinding {
    /// The mouse button to bind to.
    MouseButton button;

    /// The keyboard modifiers that have to be held along with it, if any.
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none;

    /**
     * The modifiers that have no say in whether the binding emits, on top of
     * the ones it requires. Defaults to all of them, so that only the required
     * modifiers are taken into account at all.
     */
    KeyboardKeyModifier ignoredModifiers = anyModifiers;

    bool opEquals(ref const typeof(this) other) const {
        return button == other.button && modifiers == other.modifiers &&
            ignoredModifiers == other.ignoredModifiers;
    }

    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

    ulong toHash() nothrow @trusted const {
        ulong packed = (cast(ulong) modifiers << 32) | button;
        ulong ignored = ignoredModifiers;
        return hashOf(packed) * 33 + hashOf(ignored);
    }
}

/**
 * An event emitted when a mouse button is pressed or released.
 */
struct MouseButtonEvent {
    /// The button the event happened to.
    MouseButton button;

    /**
     * Whether the button was pressed or released. Mouse buttons do not repeat
     * while they are held, so $(D InputEventAction.repeat) is never reported.
     */
    InputEventAction action;

    /**
     * Bit mask of the keyboard modifiers that were active during the event.
     */
    KeyboardKeyModifier modifiers;
}

/**
 * An event emitted when the mouse is moved.
 *
 * Depending on the platform and its configuration, this position may be absolute or relative.
 * It may be that of the mouse over the window or the whole desktop.
 * Refer to the platform in use for specifics.
 *
 * Wherever the position is taken from, it is one over the 2D window rather than
 * one in the 3D world, and so is Y-down: its origin is the top left corner of
 * that area and the positive Y-axis points downward, the way every platform
 * reports the mouse. The Y-up convention of the engine is one of the 3D world
 * alone; a position over the window that is to be used in it has to be flipped.
 *
 * A movement is reported on a single axis or on all of them at once, which is
 * what $(D axis) says. Only the positions of the axes the event carries are
 * filled in; the rest are left at zero. See $(D splitMouseAxisEvent) for which
 * of the two the platform reports.
 */
struct MouseMovementEvent {
    double xPosition;
    double yPosition;
    Axis axis;
    MouseMovementType movementType;
}

/**
 * An axis of mouse movement together with the type of movement to follow along
 * it.
 *
 * The mouse drives its events by how far it moved rather than by being pressed,
 * so a binding emits its events at the magnitude of the movement instead of at
 * the full magnitude a key or a button emits at. What that magnitude means is
 * up to the type of movement bound: the position of the mouse for
 * $(D MouseMovementType.absolute), the distance it moved since the last event
 * for $(D MouseMovementType.relative).
 *
 * Both types are followed independently, so the same movement can drive a
 * cursor and a camera at once:
 *
 * ---
 * addMouseMovementMapping(Axis.x, sid("ev_cursorX"), MouseMovementType.absolute);
 * addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
 * ---
 *
 * $(D Axis.all) follows every axis rather than a combined one: its events are
 * emitted once per axis the mouse moved along, each carrying that axis' own
 * magnitude.
 */
struct MouseMovementBinding {
    /// The axis to bind to, or $(D Axis.all) to bind to each of them.
    Axis axis;

    /// Whether to follow the position of the mouse or the distance it moved.
    MouseMovementType movementType;

    bool opEquals(ref const typeof(this) other) const {
        return axis == other.axis && movementType == other.movementType;
    }

    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

    ulong toHash() nothrow @trusted const {
        ulong packed = (cast(ulong) movementType << 32) | axis;
        return hashOf(packed);
    }
}

/**
 * Type of mouse movement.
 *
 * It depends on the platform whether one or the other is available.
 */
enum MouseMovementType : uint {
    /// Absolute X/Y movement over the screen/desktop
    absolute,

    /// Relative movement to the previous mouse movement event (delta movement)
    relative
}

/**
 * Input axis definition for multi-axis control input, such as joysticks or mouse-movement.
 */
enum Axis : uint {
    /// Every axis at once: all of them in an event, any of them in a binding.
    all,

    x,
    y,
    z
}

/**
 * Whether the platform should report the given type of mouse movement at all.
 *
 * A type that is turned off is one the platform stops following, leaving
 * nothing for the bindings on it to emit. Turning off the type that is not
 * being used spares the platform that work: reporting both is what the mouse
 * starts out doing.
 *
 * Whether the platform takes this on is up to the platform, as is whether both
 * types are available there at all. Ask $(D isMouseMovementEnabled) for what it
 * ended up doing.
 *
 * Params:
 *  movementType = The type of movement to report or leave alone.
 *  enabled = Whether to report it.
 */
void setMouseMovementEnabled(MouseMovementType movementType, bool enabled) {
    setPlatformMouseMovementEnabled(movementType, enabled);
}

/**
 * Returns: Whether the given type of mouse movement is reported.
 *
 * This is asked of the platform rather than kept here, so it is what the
 * platform is really doing rather than what it was asked to do: a platform that
 * cannot report a type of movement keeps saying so however often it is turned
 * on, and one that cannot stop reporting one keeps saying that as well.
 */
bool isMouseMovementEnabled(MouseMovementType movementType) {
    return isPlatformMouseMovementEnabled(movementType);
}

/**
 * Whether the platform should report each mousemovement
 * axis individually or combined.
 *
 * Which of the two the platform reports does not change which bindings emit: a
 * combined movement is taken apart into the axes it carries. Reporting each
 * axis on its own lets the platform follow the mouse more finely, at the cost
 * of an event per axis.
 *
 * Whether the platform takes this on is up to the platform. Ask
 * $(D isMouseAxisEventSplit) for what it ended up doing.
 */
void splitMouseAxisEvent(bool enabled) {
    setPlatformMouseAxisSplit(enabled);
}

/**
 * Returns: Whether the platform reports each axis of a movement on its own.
 *
 * This is asked of the platform rather than kept here, so it is what the
 * platform is really doing rather than what it was asked to do: a platform that
 * cannot report the axes separately keeps saying so however often it is turned
 * on.
 */
bool isMouseAxisEventSplit() {
    return isPlatformMouseAxisSplit();
}

/**
 * When enabled, the x/y mouse movement values contain raw values
 * as known by the platform instead of clamping to 0.0 - 1.0.
 * For example: on desktops this would be the raw pixel values.
 *
 * Whether the platform takes this on is up to the platform. Ask
 * $(D isRawMouseMotion) for what it ended up doing.
 */
void setRawMouseMotion(bool enabled) {
    setPlatformRawMouseMotion(enabled);
}

/**
 * Returns: Whether mouse movement is reported in the raw values of the
 *          platform.
 *
 * As with $(D isMouseAxisEventSplit), this is what the platform is really
 * doing rather than what it was asked to do.
 */
bool isRawMouseMotion() {
    return isPlatformRawMouseMotion();
}

/**
 * An input event generated scrolling a one or two-dimensional mousewheel.
 *
 * The offsets are the distance the wheel was scrolled since the previous scroll
 * event, in notches: one detent of a typical wheel is a whole one, and a
 * trackpad or a free-spinning wheel reports the fractions in between.
 *
 * A scroll is the rotation of the wheel rather than a position over the window,
 * and so is Y-up rather than Y-down as the mouse itself is: scrolling up, away
 * from the user, gives a positive $(D yOffset) and scrolling down a negative
 * one, the way every platform but the browser reports the wheel. Scrolling right
 * gives a positive $(D xOffset), which every platform agrees on.
 *
 * Both axes are always carried, so a wheel that only turns one way reports the
 * other at zero.
 */
struct MouseScrollEvent {
    double xOffset;
    double yOffset;
}

/**
 * An axis of the mousewheel to follow.
 *
 * The wheel drives its events by how far it was scrolled rather than by being
 * pressed, so a binding emits its events at the distance of the scroll instead
 * of at the full magnitude a key or a button emits at. A scroll is an impulse
 * rather than a state: its events are emitted once per scroll, and nothing is
 * emitted while the wheel sits still.
 *
 * ---
 * addMouseScrollMapping(Axis.y, sid("ev_zoom"));
 * ---
 *
 * $(D Axis.all) follows both axes rather than a combined one: its events are
 * emitted once per axis, each carrying that axis' own offset.
 */
struct MouseScrollBinding {
    /// The axis to bind to, or $(D Axis.all) to bind to both of them.
    Axis axis;

    bool opEquals(ref const typeof(this) other) const {
        return axis == other.axis;
    }

    bool opEquals(const typeof(this) other) const {
        return opEquals(other);
    }

    ulong toHash() nothrow @trusted const {
        return hashOf(cast(ulong) axis);
    }
}

version (UnitTesting)  :  ///

import retrograde.std.test : test, writeSection;
import retrograde.std.stringid : sid;

void resetInput() {
    version (WasmMemTest) {
        // The WasmMemTest harness wipes the heap before each test, so these globals already
        // hold dangling pointers. Reset them to their init state without freeing: clear()/free
        // would log benign "invalid block" errors for the already-wiped memory.
        import retrograde.std.memory : memset;

        memset(&keyEvents, 0, keyEvents.sizeof);
        memset(&textInputEvents, 0, textInputEvents.sizeof);
        memset(&textInputHandlers, 0, textInputHandlers.sizeof);
        memset(&typedText, 0, typedText.sizeof);
        memset(&otherTypedText, 0, otherTypedText.sizeof);
        memset(&mouseButtonEvents, 0, mouseButtonEvents.sizeof);
        memset(&mouseMovementEvents, 0, mouseMovementEvents.sizeof);
        memset(&mouseScrollEvents, 0, mouseScrollEvents.sizeof);
        memset(&eventQueue, 0, eventQueue.sizeof);
        memset(&keyMapping, 0, keyMapping.sizeof);
        memset(&mouseButtonMapping, 0, mouseButtonMapping.sizeof);
        memset(&mouseMovementMapping, 0, mouseMovementMapping.sizeof);
        memset(&mouseScrollMapping, 0, mouseScrollMapping.sizeof);
    } else {
        keyEvents.clear();
        textInputEvents.clear();
        textInputHandlers.clear();
        typedText.clear();
        otherTypedText.clear();
        mouseButtonEvents.clear();
        mouseMovementEvents.clear();
        mouseScrollEvents.clear();
        eventQueue.clear();
        clearKeyMappings();
        clearMouseButtonMappings();
        clearMouseMovementMappings();
        clearMouseScrollMappings();
    }

    setMouseMovementEnabled(MouseMovementType.absolute, true);
    setMouseMovementEnabled(MouseMovementType.relative, true);
    splitMouseAxisEvent(false);
    setRawMouseMotion(false);
}

private void pressKey(KeyboardScanCode scanCode, InputEventAction action = InputEventAction.press,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none) {
    KeyboardKeyEvent keyEvent;
    keyEvent.scanCode = scanCode;
    keyEvent.action = action;
    keyEvent.modifiers = modifiers;
    keyEvents.enqueue(keyEvent);
}

/**
 * Collects the characters handed to a text input handler, so that the tests can
 * check what came through.
 *
 * Kept at module scope on purpose: a handler over a global needs no context of
 * its own, where a delegate over a local of a test lambda would be a closure,
 * which betterC has no GC to put anywhere.
 */
private struct TypedText {
    Array!dchar codePoints;

    void handle(ref const TextInputEvent textInputEvent) {
        codePoints.add(textInputEvent.codePoint);
    }

    void clear() {
        codePoints.clear();
    }
}

private TypedText typedText;
private TypedText otherTypedText;

private void typeText(dchar codePoint) {
    textInputEvents.enqueue(TextInputEvent(codePoint));
}

private void pressMouseButton(MouseButton button, InputEventAction action = InputEventAction.press,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none) {
    MouseButtonEvent buttonEvent;
    buttonEvent.button = button;
    buttonEvent.action = action;
    buttonEvent.modifiers = modifiers;
    mouseButtonEvents.enqueue(buttonEvent);
}

private void moveMouse(double xPosition, double yPosition,
    MouseMovementType movementType = MouseMovementType.absolute, Axis axis = Axis.all) {
    MouseMovementEvent movementEvent;
    movementEvent.xPosition = xPosition;
    movementEvent.yPosition = yPosition;
    movementEvent.axis = axis;
    movementEvent.movementType = movementType;
    mouseMovementEvents.enqueue(movementEvent);
}

private void scrollMouse(double xOffset, double yOffset) {
    MouseScrollEvent scrollEvent;
    scrollEvent.xOffset = xOffset;
    scrollEvent.yOffset = yOffset;
    mouseScrollEvents.enqueue(scrollEvent);
}

private size_t emittedEventCount(StringId eventName, Magnitude magnitude) {
    size_t count = 0;
    Event event;
    while (eventQueue.tryDequeue(event)) {
        if (event.name == eventName && event.magnitude == magnitude) {
            count++;
        }
    }

    return count;
}

void runInputTests() {
    writeSection("-- Input tests --");

    test("a mapped key emits its event", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        pressKey(KeyboardScanCode.w);
        processInput();

        Event event;
        assert(eventQueue.tryDequeue(event));
        assert(event.name == sid("ev_moveForward"));
        assert(event.magnitude == 1);
        assert(eventQueue.length == 0);
    });

    test("an unmapped key emits nothing", () {
        resetInput();
        pressKey(KeyboardScanCode.w);
        processInput();
        assert(eventQueue.length == 0);
    });

    test("a key mapped to multiple events emits all of them", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"));
        pressKey(KeyboardScanCode.w);
        processInput();

        assert(eventQueue.length == 2);

        Event event;
        assert(eventQueue.tryDequeue(event));
        assert(event.name == sid("ev_moveForward"));
        assert(eventQueue.tryDequeue(event));
        assert(event.name == sid("ev_menuUp"));
    });

    test("mapping the same event to a key twice emits it once", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        pressKey(KeyboardScanCode.w);
        processInput();

        assert(eventQueue.length == 1);
    });

    test("different keys keep their own events", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.s, sid("ev_moveBackward"));

        assert(hasKeyMapping(KeyboardScanCode.w, sid("ev_moveForward")));
        assert(hasKeyMapping(KeyboardScanCode.s, sid("ev_moveBackward")));
        assert(!hasKeyMapping(KeyboardScanCode.w, sid("ev_moveBackward")));
        assert(!hasKeyMapping(KeyboardScanCode.s, sid("ev_moveForward")));
    });

    test("removing one event from a key keeps the others", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"));

        assert(removeKeyMapping(KeyboardScanCode.w, sid("ev_moveForward")));
        assert(!hasKeyMapping(KeyboardScanCode.w, sid("ev_moveForward")));
        assert(hasKeyMapping(KeyboardScanCode.w, sid("ev_menuUp")));

        pressKey(KeyboardScanCode.w);
        processInput();

        Event event;
        assert(eventQueue.tryDequeue(event));
        assert(event.name == sid("ev_menuUp"));
        assert(eventQueue.length == 0);
    });

    test("removing the last event of a key unmaps the key", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));

        assert(removeKeyMapping(KeyboardScanCode.w, sid("ev_moveForward")));
        assert(keyMapping.length == 0);
    });

    test("removing an event a key does not have changes nothing", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));

        assert(!removeKeyMapping(KeyboardScanCode.w, sid("ev_menuUp")));
        assert(!removeKeyMapping(KeyboardScanCode.s, sid("ev_moveForward")));
        assert(hasKeyMapping(KeyboardScanCode.w, sid("ev_moveForward")));
    });

    test("removing all events of a key unmaps the key", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"));

        assert(removeKeyMappings(KeyboardScanCode.w));
        assert(!removeKeyMappings(KeyboardScanCode.w));
        assert(!hasKeyMapping(KeyboardScanCode.w, sid("ev_moveForward")));
        assert(!hasKeyMapping(KeyboardScanCode.w, sid("ev_menuUp")));
        assert(keyMapping.length == 0);
    });

    test("a key mapped again after being unmapped emits its event again", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        assert(removeKeyMappings(KeyboardScanCode.w));
        addKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"));

        pressKey(KeyboardScanCode.w);
        processInput();

        assert(eventQueue.length == 1);

        Event event;
        assert(eventQueue.tryDequeue(event));
        assert(event.name == sid("ev_menuUp"));
    });

    test("releasing a key emits its events with zero magnitude", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"));
        pressKey(KeyboardScanCode.w, InputEventAction.release);
        processInput();

        assert(eventQueue.length == 2);

        Event event;
        while (eventQueue.tryDequeue(event)) {
            assert(event.magnitude == 0);
        }
    });

    test("repeating a key emits its events with full magnitude", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        pressKey(KeyboardScanCode.w, InputEventAction.repeat);
        processInput();

        Event event;
        assert(eventQueue.tryDequeue(event));
        assert(event.magnitude == 1);
    });

    writeSection("-- Input modifier tests --");

    test("side-independent modifiers cover both of their sides", () {
        assert(KeyboardKeyModifier.shift ==
            (
            KeyboardKeyModifier.leftShift | KeyboardKeyModifier.rightShift));
        assert(KeyboardKeyModifier.ctrl ==
            (
            KeyboardKeyModifier.leftCtrl | KeyboardKeyModifier.rightCtrl));
        assert(KeyboardKeyModifier.alt ==
            (
            KeyboardKeyModifier.leftAlt | KeyboardKeyModifier.rightAlt));
        assert(KeyboardKeyModifier.gui ==
            (
            KeyboardKeyModifier.leftGui | KeyboardKeyModifier.rightGui));
    });

    test("bindings do not require the lock modifiers", () {
        assert((bindableModifiers & KeyboardKeyModifier.capslock) == 0);
        assert((bindableModifiers & KeyboardKeyModifier.numlock) == 0);
        assert((bindableModifiers & KeyboardKeyModifier.mode) != 0);
    });

    test("a key mapped without modifiers ignores every modifier", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));

        assert(KeyBinding(KeyboardScanCode.w).ignoredModifiers == anyModifiers);
        assert(hasKeyMapping(KeyBinding(KeyboardScanCode.w), sid("ev_moveForward")));
        assert(hasKeyMapping(KeyBinding(KeyboardScanCode.w, KeyboardKeyModifier.none),
            sid("ev_moveForward")));
    });

    test("a modifier binding only emits while its modifier is held", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);

        pressKey(KeyboardScanCode.w);
        processInput();
        assert(eventQueue.length == 0);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftShift);
        processInput();
        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 1);
    });

    test("a binding without modifiers emits while one is held", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftCtrl);
        processInput();
        assert(emittedEventCount(sid("ev_moveForward"), 1) == 1);
    });

    test("a side-independent binding is satisfied by either side", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftShift);
        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.rightShift);
        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.shift);
        processInput();

        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 3);
    });

    test("a sided binding is only satisfied by its own side", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.leftShift);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.rightShift);
        processInput();
        assert(eventQueue.length == 0);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftShift);
        processInput();
        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 1);
    });

    test("holding the other side as well satisfies a sided binding", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.leftShift);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.shift);
        processInput();
        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 1);
    });

    test("bindings on the same key with different modifiers stay apart", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);
        addKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"), KeyboardKeyModifier.ctrl);

        assert(keyMapping.length == 3);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftCtrl);
        processInput();

        // The shift binding is the only one left out: the unmodified one
        // ignores ctrl rather than being blocked by it.
        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 0);
    });

    test("a sided and a side-independent binding both emit on the same press", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);
        addKeyMapping(KeyboardScanCode.w, sid("ev_leftHanded"), KeyboardKeyModifier.leftShift);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftShift);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 1);
    });

    test("a binding requiring several modifiers needs all of them", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"),
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.ctrl | KeyboardKeyModifier.alt));

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftCtrl);
        processInput();
        assert(eventQueue.length == 0);

        pressKey(KeyboardScanCode.w, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.rightCtrl | KeyboardKeyModifier.leftAlt));
        processInput();
        assert(emittedEventCount(sid("ev_menuUp"), 1) == 1);
    });

    test("holding an extra modifier does not stop a binding from emitting", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);

        pressKey(KeyboardScanCode.w, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.leftShift | KeyboardKeyModifier.leftAlt));
        processInput();
        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 1);
    });

    test("the lock modifiers do not stop a binding from emitting", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.s, sid("ev_sprintBackward"), KeyboardKeyModifier.shift);

        pressKey(KeyboardScanCode.w, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.capslock | KeyboardKeyModifier.numlock));
        pressKey(KeyboardScanCode.s, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.rightShift | KeyboardKeyModifier.capslock));
        processInput();

        assert(emittedEventCount(sid("ev_moveForward"), 1) == 1);
    });

    test("releasing a key releases its bindings whatever modifiers are left", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftShift);
        processInput();
        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 1);

        // Shift was let go of before the key it modified, so the release
        // reports no modifiers at all.
        pressKey(KeyboardScanCode.w, InputEventAction.release);
        processInput();
        assert(emittedEventCount(sid("ev_sprintForward"), 0) == 1);
    });

    test("releasing a key releases every binding on it", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);
        addKeyMapping(KeyboardScanCode.s, sid("ev_moveBackward"));

        pressKey(KeyboardScanCode.w, InputEventAction.release);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_moveBackward"), 0) == 0);
    });

    test("removing a binding leaves the other modifiers of the key alone", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);

        assert(removeKeyMappings(KeyboardScanCode.w));
        assert(!hasKeyMapping(KeyboardScanCode.w, sid("ev_moveForward")));
        assert(hasKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"),
            KeyboardKeyModifier.shift));
    });

    test("removing all mappings of a key removes every modifier of it", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"), KeyboardKeyModifier.shift);
        addKeyMapping(KeyboardScanCode.s, sid("ev_moveBackward"));

        assert(removeAllKeyMappings(KeyboardScanCode.w));
        assert(!removeAllKeyMappings(KeyboardScanCode.w));
        assert(keyMapping.length == 1);
        assert(hasKeyMapping(KeyboardScanCode.s, sid("ev_moveBackward")));
    });

    writeSection("-- Input ignored modifier tests --");

    test("walking and running coexist on a key and its modifier", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_walkForward"));
        addKeyMapping(KeyboardScanCode.leftShift, sid("ev_run"));

        pressKey(KeyboardScanCode.leftShift, InputEventAction.press,
            KeyboardKeyModifier.leftShift);
        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftShift);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_walkForward"), 1) == 1);
    });

    test("a binding on a modifier key does not have to require itself", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.leftShift, sid("ev_run"),
            KeyboardKeyModifier.none, KeyboardKeyModifier.none);

        pressKey(KeyboardScanCode.leftShift, InputEventAction.press,
            KeyboardKeyModifier.leftShift);
        processInput();

        assert(emittedEventCount(sid("ev_run"), 1) == 1);
    });

    test("a binding on the AltGr key does not have to require its mode", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.rightAlt, sid("ev_run"),
            KeyboardKeyModifier.none, KeyboardKeyModifier.none);

        pressKey(KeyboardScanCode.rightAlt, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.rightAlt | KeyboardKeyModifier.mode));
        processInput();

        assert(emittedEventCount(sid("ev_run"), 1) == 1);
    });

    test("a narrowed binding on a modifier key is blocked by other modifiers", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.leftShift, sid("ev_run"),
            KeyboardKeyModifier.none, KeyboardKeyModifier.none);

        pressKey(KeyboardScanCode.leftShift, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.leftShift | KeyboardKeyModifier.leftCtrl));
        processInput();

        assert(eventQueue.length == 0);
    });

    test("a binding narrowed to no modifiers stays silent while one is held", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.s, sid("ev_strafeBackward"),
            KeyboardKeyModifier.none, KeyboardKeyModifier.none);

        pressKey(KeyboardScanCode.s);
        processInput();
        assert(emittedEventCount(sid("ev_strafeBackward"), 1) == 1);

        pressKey(KeyboardScanCode.s, InputEventAction.press, KeyboardKeyModifier.leftCtrl);
        processInput();
        assert(eventQueue.length == 0);
    });

    test("a binding narrowed to its modifiers takes no others", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.s, sid("ev_save"),
            KeyboardKeyModifier.ctrl, KeyboardKeyModifier.none);

        pressKey(KeyboardScanCode.s, InputEventAction.press, KeyboardKeyModifier.leftCtrl);
        processInput();
        assert(emittedEventCount(sid("ev_save"), 1) == 1);

        pressKey(KeyboardScanCode.s, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.leftCtrl | KeyboardKeyModifier.leftShift));
        processInput();
        assert(eventQueue.length == 0);
    });

    test("a narrowed binding on both sides of a modifier takes only both", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.s, sid("ev_save"),
            KeyboardKeyModifier.leftCtrl, KeyboardKeyModifier.none);

        pressKey(KeyboardScanCode.s, InputEventAction.press, KeyboardKeyModifier.ctrl);
        processInput();
        assert(eventQueue.length == 0);
    });

    test("narrowing to one modifier leaves the others ignored", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.s, sid("ev_save"), KeyboardKeyModifier.ctrl,
            KeyboardKeyModifier.alt);

        pressKey(KeyboardScanCode.s, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.leftCtrl | KeyboardKeyModifier.rightAlt));
        processInput();
        assert(emittedEventCount(sid("ev_save"), 1) == 1);

        pressKey(KeyboardScanCode.s, InputEventAction.press,
            cast(KeyboardKeyModifier)(KeyboardKeyModifier.leftCtrl | KeyboardKeyModifier.leftShift));
        processInput();
        assert(eventQueue.length == 0);
    });

    test("a required modifier is never ignored", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_sprintForward"),
            KeyboardKeyModifier.shift, anyModifiers);

        pressKey(KeyboardScanCode.w);
        processInput();
        assert(eventQueue.length == 0);

        pressKey(KeyboardScanCode.w, InputEventAction.press, KeyboardKeyModifier.leftShift);
        processInput();
        assert(emittedEventCount(sid("ev_sprintForward"), 1) == 1);
    });

    test("bindings differing only in what they ignore stay apart", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_walkForward"));
        addKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"), KeyboardKeyModifier.none,
            KeyboardKeyModifier.none);

        assert(keyMapping.length == 2);
        assert(hasKeyMapping(KeyboardScanCode.w, sid("ev_walkForward")));
        assert(!hasKeyMapping(KeyboardScanCode.w, sid("ev_walkForward"),
            KeyboardKeyModifier.none, KeyboardKeyModifier.none));
        assert(hasKeyMapping(KeyboardScanCode.w, sid("ev_menuUp"),
            KeyboardKeyModifier.none, KeyboardKeyModifier.none));
    });

    test("releasing a key releases its narrowed bindings too", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_save"), KeyboardKeyModifier.ctrl,
            KeyboardKeyModifier.none);

        pressKey(KeyboardScanCode.w, InputEventAction.release);
        processInput();

        assert(emittedEventCount(sid("ev_save"), 0) == 1);
    });

    test("scan code mask does not collide with Unicode code points", () {
        assert(scanCodeMask > 0x10FFFF);
    });

    test("key codes of keys without a character are their masked scan code", () {
        assert(toKeyCode(KeyboardScanCode.escape) == KeyboardKeyCode.escape);
        assert(toKeyCode(KeyboardScanCode.leftShift) == KeyboardKeyCode.leftShift);
        assert(toKeyCode(KeyboardScanCode.f25) == KeyboardKeyCode.f25);
    });

    test("an unknown scan code converts to an unknown key code", () {
        assert(toKeyCode(KeyboardScanCode.unknown) == KeyboardKeyCode.unknown);
        assert(KeyboardKeyCode.unknown == 0);
    });

    test("keys that produce a character have no named key code", () {
        static assert(!__traits(hasMember, KeyboardKeyCode, "a"));
        static assert(!__traits(hasMember, KeyboardKeyCode, "space"));
        static assert(__traits(hasMember, KeyboardScanCode, "a"));
    });

    test("every named key code carries the scan code of the same key", () {
        static foreach (name; __traits(allMembers, KeyboardKeyCode)) {
            static if (name != "unknown") {
                assert(__traits(getMember, KeyboardKeyCode, name) ==
                    toKeyCode(__traits(getMember, KeyboardScanCode, name)));
            }
        }
    });

    writeSection("-- Text input tests --");

    test("typed text reaches its handler", () {
        resetInput();
        textInputHandlers.add(&typedText.handle);
        typeText('a');
        processInput();

        assert(typedText.codePoints.length == 1);
        assert(typedText.codePoints[0] == 'a');
    });

    test("typed text is handed over in the order it was typed", () {
        resetInput();
        textInputHandlers.add(&typedText.handle);
        typeText('h');
        typeText('i');
        typeText('!');
        processInput();

        assert(typedText.codePoints.length == 3);
        assert(typedText.codePoints[0] == 'h');
        assert(typedText.codePoints[1] == 'i');
        assert(typedText.codePoints[2] == '!');
    });

    test("text outside the ASCII range keeps its code point", () {
        resetInput();
        textInputHandlers.add(&typedText.handle);
        typeText('é');
        typeText('あ');
        typeText('🎮');
        processInput();

        assert(typedText.codePoints.length == 3);
        assert(typedText.codePoints[0] == 0xE9);
        assert(typedText.codePoints[1] == 0x3042);
        assert(typedText.codePoints[2] == 0x1F3AE);
    });

    test("every handler gets each character typed", () {
        resetInput();
        textInputHandlers.add(&typedText.handle);
        textInputHandlers.add(&otherTypedText.handle);
        typeText('a');
        processInput();

        assert(typedText.codePoints.length == 1);
        assert(typedText.codePoints[0] == 'a');
        assert(otherTypedText.codePoints.length == 1);
        assert(otherTypedText.codePoints[0] == 'a');
    });

    test("text typed with no handler is dropped", () {
        resetInput();
        typeText('a');
        processInput();

        assert(textInputEvents.length == 0);
        assert(eventQueue.length == 0);
    });

    test("text is only handed over once", () {
        resetInput();
        textInputHandlers.add(&typedText.handle);
        typeText('a');
        processInput();
        processInput();

        assert(typedText.codePoints.length == 1);
    });

    test("typed text emits no bound events", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.a, sid("ev_moveLeft"));
        typeText('a');
        processInput();

        assert(eventQueue.length == 0);
    });

    test("a key that is bound is typed as text as well", () {
        resetInput();
        textInputHandlers.add(&typedText.handle);
        addKeyMapping(KeyboardScanCode.a, sid("ev_moveLeft"));
        pressKey(KeyboardScanCode.a);
        typeText('a');
        processInput();

        assert(typedText.codePoints.length == 1);
        assert(emittedEventCount(sid("ev_moveLeft"), 1) == 1);
    });

    test("text input is a method of its own", () {
        assert((InputMethod.textInput & InputMethod.keyboard) == 0);
        assert((InputMethod.textInput & InputMethod.mouse) == 0);
    });

    writeSection("-- Mouse button input tests --");

    test("the named mouse buttons are the numbered ones", () {
        assert(MouseButton.left == MouseButton.one);
        assert(MouseButton.right == MouseButton.two);
        assert(MouseButton.middle == MouseButton.three);
    });

    test("a mapped mouse button emits its event", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        pressMouseButton(MouseButton.left);
        processInput();

        Event event;
        assert(eventQueue.tryDequeue(event));
        assert(event.name == sid("ev_fire"));
        assert(event.magnitude == 1);
        assert(eventQueue.length == 0);
    });

    test("an unmapped mouse button emits nothing", () {
        resetInput();
        pressMouseButton(MouseButton.left);
        processInput();
        assert(eventQueue.length == 0);
    });

    test("a mouse button mapped to multiple events emits all of them", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        addMouseButtonMapping(MouseButton.left, sid("ev_menuSelect"));
        pressMouseButton(MouseButton.left);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_fire"), 1) == 1);
    });

    test("mapping the same event to a mouse button twice emits it once", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        pressMouseButton(MouseButton.left);
        processInput();

        assert(eventQueue.length == 1);
    });

    test("different mouse buttons keep their own events", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        addMouseButtonMapping(MouseButton.right, sid("ev_aim"));

        pressMouseButton(MouseButton.right);
        processInput();

        assert(emittedEventCount(sid("ev_aim"), 1) == 1);
        assert(!hasMouseButtonMapping(MouseButton.left, sid("ev_aim")));
    });

    test("releasing a mouse button emits its events with zero magnitude", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        addMouseButtonMapping(MouseButton.left, sid("ev_menuSelect"));
        pressMouseButton(MouseButton.left, InputEventAction.release);
        processInput();

        assert(eventQueue.length == 2);

        Event event;
        while (eventQueue.tryDequeue(event)) {
            assert(event.magnitude == 0);
        }
    });

    test("removing one event from a mouse button keeps the others", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        addMouseButtonMapping(MouseButton.left, sid("ev_menuSelect"));

        assert(removeMouseButtonMapping(MouseButton.left, sid("ev_fire")));
        assert(!removeMouseButtonMapping(MouseButton.left, sid("ev_fire")));
        assert(!hasMouseButtonMapping(MouseButton.left, sid("ev_fire")));
        assert(hasMouseButtonMapping(MouseButton.left, sid("ev_menuSelect")));
    });

    test("removing the last event of a mouse button unmaps the button", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));

        assert(removeMouseButtonMapping(MouseButton.left, sid("ev_fire")));
        assert(mouseButtonMapping.length == 0);
    });

    test("removing all events of a mouse button unmaps the button", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        addMouseButtonMapping(MouseButton.left, sid("ev_menuSelect"));

        assert(removeMouseButtonMappings(MouseButton.left));
        assert(!removeMouseButtonMappings(MouseButton.left));
        assert(mouseButtonMapping.length == 0);
    });

    test("removing all mappings of a mouse button removes every modifier of it", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        addMouseButtonMapping(MouseButton.left, sid("ev_aim"), KeyboardKeyModifier.ctrl);
        addMouseButtonMapping(MouseButton.right, sid("ev_menuBack"));

        assert(removeAllMouseButtonMappings(MouseButton.left));
        assert(!removeAllMouseButtonMappings(MouseButton.left));
        assert(mouseButtonMapping.length == 1);
        assert(hasMouseButtonMapping(MouseButton.right, sid("ev_menuBack")));
    });

    test("clearing the mouse button mappings leaves no button bound", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));
        clearMouseButtonMappings();

        assert(mouseButtonMapping.length == 0);
        assert(!hasMouseButtonMapping(MouseButton.left, sid("ev_fire")));
    });

    test("a modifier binding on a mouse button only emits while its modifier is held", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_aim"), KeyboardKeyModifier.ctrl);

        pressMouseButton(MouseButton.left);
        processInput();
        assert(eventQueue.length == 0);

        pressMouseButton(MouseButton.left, InputEventAction.press, KeyboardKeyModifier.leftCtrl);
        processInput();
        assert(emittedEventCount(sid("ev_aim"), 1) == 1);
    });

    test("a mouse button binding narrowed to its modifiers takes no others", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"), KeyboardKeyModifier.none,
            KeyboardKeyModifier.ctrl);
        addMouseButtonMapping(MouseButton.left, sid("ev_aim"), KeyboardKeyModifier.ctrl,
            KeyboardKeyModifier.none);

        assert(mouseButtonMapping.length == 2);

        pressMouseButton(MouseButton.left, InputEventAction.press, KeyboardKeyModifier.leftCtrl);
        processInput();

        assert(emittedEventCount(sid("ev_fire"), 1) == 1);
        assert(emittedEventCount(sid("ev_aim"), 1) == 0);
    });

    test("releasing a mouse button releases its bindings whatever modifiers are left", () {
        resetInput();
        addMouseButtonMapping(MouseButton.left, sid("ev_aim"), KeyboardKeyModifier.ctrl);

        pressMouseButton(MouseButton.left, InputEventAction.press, KeyboardKeyModifier.leftCtrl);
        processInput();
        assert(emittedEventCount(sid("ev_aim"), 1) == 1);

        pressMouseButton(MouseButton.left, InputEventAction.release);
        processInput();
        assert(emittedEventCount(sid("ev_aim"), 0) == 1);
    });

    test("keys and mouse buttons keep their own bindings", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.w, sid("ev_moveForward"));
        addMouseButtonMapping(MouseButton.left, sid("ev_fire"));

        pressKey(KeyboardScanCode.w);
        pressMouseButton(MouseButton.left);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_moveForward"), 1) == 1);
        assert(!hasKeyMapping(KeyboardScanCode.w, sid("ev_fire")));
        assert(!hasMouseButtonMapping(MouseButton.left, sid("ev_moveForward")));
    });

    test("a mouse button mapped to the event of a key emits it too", () {
        resetInput();
        addKeyMapping(KeyboardScanCode.space, sid("ev_jump"));
        addMouseButtonMapping(MouseButton.middle, sid("ev_jump"));

        pressKey(KeyboardScanCode.space);
        pressMouseButton(MouseButton.middle);
        processInput();

        assert(emittedEventCount(sid("ev_jump"), 1) == 2);
    });

    writeSection("-- Mouse movement input tests --");

    test("a mapped axis emits its event at the magnitude of the movement", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        moveMouse(0.5, 0.25, MouseMovementType.relative);
        processInput();

        Event event;
        assert(eventQueue.tryDequeue(event));
        assert(event.name == sid("ev_lookX"));
        assert(event.magnitude == 0.5);
        assert(eventQueue.length == 0);
    });

    test("an unmapped axis emits nothing", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        moveMouse(0.5, 0.25, MouseMovementType.relative, Axis.y);
        processInput();

        assert(eventQueue.length == 0);
    });

    test("a combined movement drives the bindings of both axes", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_cursorX"), MouseMovementType.absolute);
        addMouseMovementMapping(Axis.y, sid("ev_cursorY"), MouseMovementType.absolute);
        moveMouse(0.5, 0.25);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_cursorX"), 0.5) == 1);

        moveMouse(0.5, 0.25);
        processInput();
        assert(emittedEventCount(sid("ev_cursorY"), 0.25) == 1);
    });

    test("a split movement only drives the axis it carries", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_cursorX"), MouseMovementType.absolute);
        addMouseMovementMapping(Axis.y, sid("ev_cursorY"), MouseMovementType.absolute);
        moveMouse(0.5, 0, MouseMovementType.absolute, Axis.x);
        processInput();

        assert(emittedEventCount(sid("ev_cursorX"), 0.5) == 1);
    });

    test("a binding on all axes emits once per axis of the movement", () {
        resetInput();
        addMouseMovementMapping(Axis.all, sid("ev_look"), MouseMovementType.relative);
        moveMouse(0.5, 0.25, MouseMovementType.relative);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_look"), 0.5) == 1);

        moveMouse(0.5, 0.25, MouseMovementType.relative, Axis.y);
        processInput();

        assert(eventQueue.length == 1);
        assert(emittedEventCount(sid("ev_look"), 0.25) == 1);
    });

    test("a movement along an axis the mouse does not carry emits nothing", () {
        resetInput();
        addMouseMovementMapping(Axis.all, sid("ev_look"), MouseMovementType.relative);
        moveMouse(0.5, 0.25, MouseMovementType.relative, Axis.z);
        processInput();

        assert(eventQueue.length == 0);
    });

    test("absolute and relative bindings keep their own movements", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_cursorX"), MouseMovementType.absolute);
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);

        assert(mouseMovementMapping.length == 2);

        moveMouse(0.5, 0, MouseMovementType.relative, Axis.x);
        processInput();

        assert(emittedEventCount(sid("ev_cursorX"), 0.5) == 0);

        moveMouse(0.5, 0, MouseMovementType.relative, Axis.x);
        processInput();

        assert(emittedEventCount(sid("ev_lookX"), 0.5) == 1);
    });

    test("an axis mapped to multiple events emits all of them", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        addMouseMovementMapping(Axis.x, sid("ev_aimX"), MouseMovementType.relative);
        moveMouse(0.5, 0, MouseMovementType.relative, Axis.x);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_aimX"), 0.5) == 1);
    });

    test("mapping the same event to an axis twice emits it once", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        moveMouse(0.5, 0, MouseMovementType.relative, Axis.x);
        processInput();

        assert(eventQueue.length == 1);
    });

    test("a movement of zero still emits, so its events do not stay put", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        moveMouse(0, 0, MouseMovementType.relative, Axis.x);
        processInput();

        assert(emittedEventCount(sid("ev_lookX"), 0) == 1);
    });

    test("removing one event from an axis keeps the others", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        addMouseMovementMapping(Axis.x, sid("ev_aimX"), MouseMovementType.relative);

        assert(removeMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative));
        assert(!removeMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative));
        assert(!hasMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative));
        assert(hasMouseMovementMapping(Axis.x, sid("ev_aimX"), MouseMovementType.relative));
    });

    test("removing the last event of a binding unmaps the binding", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);

        assert(removeMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative));
        assert(mouseMovementMapping.length == 0);
    });

    test("removing a binding leaves the other movement type of the axis alone", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_cursorX"), MouseMovementType.absolute);
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);

        assert(removeMouseMovementMappings(Axis.x, MouseMovementType.absolute));
        assert(!removeMouseMovementMappings(Axis.x, MouseMovementType.absolute));
        assert(!hasMouseMovementMapping(Axis.x, sid("ev_cursorX"), MouseMovementType.absolute));
        assert(hasMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative));
    });

    test("removing all mappings of an axis removes both of its movement types", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_cursorX"), MouseMovementType.absolute);
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        addMouseMovementMapping(Axis.y, sid("ev_lookY"), MouseMovementType.relative);

        assert(removeAllMouseMovementMappings(Axis.x));
        assert(!removeAllMouseMovementMappings(Axis.x));
        assert(mouseMovementMapping.length == 1);
        assert(hasMouseMovementMapping(Axis.y, sid("ev_lookY"), MouseMovementType.relative));
    });

    test("clearing the mouse movement mappings leaves no axis bound", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative);
        clearMouseMovementMappings();

        assert(mouseMovementMapping.length == 0);
        assert(!hasMouseMovementMapping(Axis.x, sid("ev_lookX"), MouseMovementType.relative));
    });

    writeSection("-- Mouse scroll input tests --");

    test("a mapped axis emits its event at the distance of the scroll", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));
        scrollMouse(0, 1);
        processInput();

        Event event;
        assert(eventQueue.tryDequeue(event));
        assert(event.name == sid("ev_zoom"));
        assert(event.magnitude == 1);
        assert(eventQueue.length == 0);
    });

    test("an unmapped axis emits nothing", () {
        resetInput();
        addMouseScrollMapping(Axis.x, sid("ev_scrollX"));
        clearMouseScrollMappings();
        scrollMouse(1, 1);
        processInput();

        assert(eventQueue.length == 0);
    });

    test("a scroll drives the bindings of both axes", () {
        resetInput();
        addMouseScrollMapping(Axis.x, sid("ev_scrollX"));
        addMouseScrollMapping(Axis.y, sid("ev_scrollY"));
        scrollMouse(0.5, 0.25);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_scrollX"), 0.5) == 1);

        scrollMouse(0.5, 0.25);
        processInput();
        assert(emittedEventCount(sid("ev_scrollY"), 0.25) == 1);
    });

    test("a binding on all axes emits once per axis of the scroll", () {
        resetInput();
        addMouseScrollMapping(Axis.all, sid("ev_scroll"));
        scrollMouse(0.5, 0.25);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_scroll"), 0.5) == 1);

        scrollMouse(0.5, 0.25);
        processInput();
        assert(emittedEventCount(sid("ev_scroll"), 0.25) == 1);
    });

    test("a binding on the third axis is left alone by a scroll", () {
        resetInput();
        addMouseScrollMapping(Axis.z, sid("ev_scrollZ"));
        scrollMouse(0.5, 0.25);
        processInput();

        assert(eventQueue.length == 0);
    });

    test("scrolling up and down keep their own signs", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));

        // The wheel is Y-up: scrolling up, away from the user, is the positive
        // one, and the sign of the offset is carried through as it comes.
        scrollMouse(0, 1);
        processInput();

        assert(emittedEventCount(sid("ev_zoom"), 1) == 1);

        scrollMouse(0, -1);
        processInput();

        assert(emittedEventCount(sid("ev_zoom"), -1) == 1);
    });

    test("an axis mapped to multiple events emits all of them", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));
        addMouseScrollMapping(Axis.y, sid("ev_menuScroll"));
        scrollMouse(0, 1);
        processInput();

        assert(eventQueue.length == 2);
        assert(emittedEventCount(sid("ev_menuScroll"), 1) == 1);
    });

    test("mapping the same event to an axis twice emits it once", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));
        scrollMouse(0, 1);
        processInput();

        assert(eventQueue.length == 1);
    });

    test("an axis the wheel did not turn along still emits", () {
        resetInput();
        addMouseScrollMapping(Axis.x, sid("ev_scrollX"));
        scrollMouse(0, 1);
        processInput();

        // A wheel that only turns one way carries the other axis at zero, which
        // is emitted so that its events do not stay at the last scroll that did
        // touch them.
        assert(emittedEventCount(sid("ev_scrollX"), 0) == 1);
    });

    test("mouse scroll and mouse movement keep their own bindings", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));
        addMouseMovementMapping(Axis.y, sid("ev_lookY"), MouseMovementType.relative);
        scrollMouse(0, 1);
        processInput();

        assert(eventQueue.length == 1);
        assert(emittedEventCount(sid("ev_zoom"), 1) == 1);
        assert(!hasMouseScrollMapping(Axis.y, sid("ev_lookY")));
    });

    test("removing one event from an axis keeps the others", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));
        addMouseScrollMapping(Axis.y, sid("ev_menuScroll"));

        assert(removeMouseScrollMapping(Axis.y, sid("ev_zoom")));
        assert(!removeMouseScrollMapping(Axis.y, sid("ev_zoom")));
        assert(!hasMouseScrollMapping(Axis.y, sid("ev_zoom")));
        assert(hasMouseScrollMapping(Axis.y, sid("ev_menuScroll")));
    });

    test("removing the last event of a binding unmaps the binding", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));

        assert(removeMouseScrollMapping(Axis.y, sid("ev_zoom")));
        assert(mouseScrollMapping.length == 0);
    });

    test("removing all events of an axis leaves the other axes alone", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));
        addMouseScrollMapping(Axis.y, sid("ev_menuScroll"));
        addMouseScrollMapping(Axis.x, sid("ev_scrollX"));

        assert(removeMouseScrollMappings(Axis.y));
        assert(!removeMouseScrollMappings(Axis.y));
        assert(mouseScrollMapping.length == 1);
        assert(hasMouseScrollMapping(Axis.x, sid("ev_scrollX")));
    });

    test("clearing the mouse scroll mappings leaves no axis bound", () {
        resetInput();
        addMouseScrollMapping(Axis.y, sid("ev_zoom"));
        clearMouseScrollMappings();

        assert(mouseScrollMapping.length == 0);
        assert(!hasMouseScrollMapping(Axis.y, sid("ev_zoom")));
    });

    writeSection("-- Mouse movement setting tests --");

    test("the types of movement report what the platform does", () {
        resetInput();

        // Which types are reported is asked of the platform rather than kept by
        // the engine, so a platform that does not take a setting on keeps
        // reporting what it is really doing instead of what it was asked for.
        version (WebAssembly) {
            assert(isMouseMovementEnabled(MouseMovementType.absolute));
            assert(isMouseMovementEnabled(MouseMovementType.relative));

            setMouseMovementEnabled(MouseMovementType.absolute, false);
            assert(!isMouseMovementEnabled(MouseMovementType.absolute));
            assert(isMouseMovementEnabled(MouseMovementType.relative));

            setMouseMovementEnabled(MouseMovementType.absolute, true);
            assert(isMouseMovementEnabled(MouseMovementType.absolute));
        }
    });

    test("a movement that arrives is emitted, whatever it was asked to report", () {
        resetInput();
        addMouseMovementMapping(Axis.x, sid("ev_cursorX"), MouseMovementType.absolute);
        setMouseMovementEnabled(MouseMovementType.absolute, false);

        // Holding the movement back is the platform's to do: one that keeps
        // reporting a type that was turned off says so through
        // isMouseMovementEnabled rather than having its events dropped here.
        moveMouse(0.5, 0, MouseMovementType.absolute, Axis.x);
        processInput();

        assert(emittedEventCount(sid("ev_cursorX"), 0.5) == 1);
    });

    test("the axis split and raw motion settings report what the platform does", () {
        resetInput();
        splitMouseAxisEvent(true);
        setRawMouseMotion(true);

        // Both are asked of the platform rather than kept by the engine, so a
        // platform that does not take a setting on keeps reporting it as off
        // instead of claiming what it was asked for.
        version (WebAssembly) {
            assert(isMouseAxisEventSplit());
            assert(isRawMouseMotion());
        }

        splitMouseAxisEvent(false);
        setRawMouseMotion(false);

        assert(!isMouseAxisEventSplit());
        assert(!isRawMouseMotion());
    });
}
