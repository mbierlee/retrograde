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
    auto eventNames = keyMapping.getRef(binding);
    if (eventNames.isDefined) {
        auto mappedEvents = eventNames.value;
        if (!mappedEvents.exists(eventName)) {
            mappedEvents.add(eventName);
        }

        return;
    }

    Array!StringId newEvents;
    newEvents.add(eventName);
    keyMapping.put(binding, newEvents);
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
    auto eventNames = keyMapping.getRef(binding);
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
        keyMapping.remove(binding);
    }

    return true;
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
    Array!KeyBinding boundKeys;
    foreach (binding, eventNames; keyMapping) {
        if (binding.scanCode == scanCode) {
            boundKeys.add(binding);
        }
    }

    foreach (binding; boundKeys) {
        keyMapping.remove(binding);
    }

    return boundKeys.length > 0;
}

/**
 * Returns: Whether the given key binding emits the given event.
 */
bool hasKeyMapping(KeyBinding binding, StringId eventName) {
    auto eventNames = keyMapping.getRef(binding);
    return eventNames.isDefined && eventNames.value.exists(eventName);
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

void processInput() {
    KeyboardKeyEvent keyEvent;
    while (keyEvents.tryDequeue(keyEvent)) {
        if (keyEvent.action == InputEventAction.release) {
            emitReleaseEvents(keyEvent.scanCode);
        } else {
            emitPressEvents(keyEvent.scanCode, keyEvent.modifiers);
        }
    }
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
private bool bindingMatches(KeyBinding binding, KeyboardKeyModifier heldModifiers) {
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
 * Emits the events of every binding on the given key that the held modifiers
 * satisfy, at full magnitude.
 *
 * A modifier key reports itself among the modifiers of its own event, which is
 * left out here so that a binding on a modifier key does not need to require
 * itself.
 */
private void emitPressEvents(KeyboardScanCode scanCode, KeyboardKeyModifier modifiers) {
    auto heldModifiers = cast(KeyboardKeyModifier)(modifiers & ~modifierFlagOf(scanCode));
    foreach (binding, eventNames; keyMapping) {
        if (binding.scanCode != scanCode || !bindingMatches(binding, heldModifiers)) {
            continue;
        }

        foreach (i; 0 .. eventNames.length) {
            eventQueue.enqueue(Event(eventNames[i], 1));
        }
    }
}

/**
 * Emits the events of every binding on the given key at zero magnitude,
 * whatever modifiers those bindings name.
 *
 * Modifiers are deliberately not taken into account here: letting go of shift
 * before letting go of the key it modified would otherwise leave the events
 * of a shift binding stuck at full magnitude. Releasing an event that was
 * never pressed only sets it to the zero it already was.
 */
private void emitReleaseEvents(KeyboardScanCode scanCode) {
    foreach (binding, eventNames; keyMapping) {
        if (binding.scanCode != scanCode) {
            continue;
        }

        foreach (i; 0 .. eventNames.length) {
            eventQueue.enqueue(Event(eventNames[i], 0));
        }
    }
}

enum InputMethod : ubyte {
    keyboard = 1 << 0,
    mouse = 1 << 1
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
        memset(&eventQueue, 0, eventQueue.sizeof);
        memset(&keyMapping, 0, keyMapping.sizeof);
    } else {
        keyEvents.clear();
        eventQueue.clear();
        clearKeyMappings();
    }
}

private void pressKey(KeyboardScanCode scanCode, InputEventAction action = InputEventAction.press,
    KeyboardKeyModifier modifiers = KeyboardKeyModifier.none) {
    KeyboardKeyEvent keyEvent;
    keyEvent.scanCode = scanCode;
    keyEvent.action = action;
    keyEvent.modifiers = modifiers;
    keyEvents.enqueue(keyEvent);
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
                (KeyboardKeyModifier.leftShift | KeyboardKeyModifier.rightShift));
        assert(KeyboardKeyModifier.ctrl ==
                (KeyboardKeyModifier.leftCtrl | KeyboardKeyModifier.rightCtrl));
        assert(KeyboardKeyModifier.alt ==
                (KeyboardKeyModifier.leftAlt | KeyboardKeyModifier.rightAlt));
        assert(KeyboardKeyModifier.gui ==
                (KeyboardKeyModifier.leftGui | KeyboardKeyModifier.rightGui));
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
}
