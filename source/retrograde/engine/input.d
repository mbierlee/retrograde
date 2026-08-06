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
import retrograde.std.stringid : StringId;

import retrograde.engine.event : eventQueue, Event;

version (Native) {
    public import retrograde.native.input;
} else version (WebAssembly) {
    public import retrograde.wasm.input;
} else {
    static assert(false, "No inputt implementations available for target platform.");
}

Queue!KeyboardKeyEvent keyEvents;

/**
 * The events a physical key emits when it is pressed, held or released.
 *
 * A key can drive more than one event at a time, such as W driving both
 * ev_moveForward and ev_menuUp; every event mapped to the key is emitted.
 * Prefer $(D addKeyMapping) and $(D removeKeyMapping) over manipulating
 * this map directly.
 */
// TODO: allow mapping on modifiers too
HashMap!(KeyboardScanCode, Array!StringId) keyMapping;

/**
 * Make the given key emit the given event, on top of any events it already
 * emits.
 *
 * Mapping the same event to the same key again does nothing; a key never
 * emits the same event twice.
 *
 * Params:
 *  scanCode = The physical key to map.
 *  eventName = Name of the event the key should emit.
 */
void addKeyMapping(KeyboardScanCode scanCode, StringId eventName) {
    auto eventNames = keyMapping.getRef(scanCode);
    if (eventNames.isDefined) {
        auto mappedEvents = eventNames.value;
        if (!mappedEvents.exists(eventName)) {
            mappedEvents.add(eventName);
        }

        return;
    }

    Array!StringId newEvents;
    newEvents.add(eventName);
    keyMapping.put(scanCode, newEvents);
}

/**
 * Stop the given key from emitting the given event, leaving the other events
 * mapped to it in place.
 *
 * Params:
 *  scanCode = The physical key to unmap the event from.
 *  eventName = Name of the event the key should no longer emit.
 * Returns: Whether the key was mapped to the event.
 */
bool removeKeyMapping(KeyboardScanCode scanCode, StringId eventName) {
    auto eventNames = keyMapping.getRef(scanCode);
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
        keyMapping.remove(scanCode);
    }

    return true;
}

/**
 * Stop the given key from emitting any event at all.
 *
 * Params:
 *  scanCode = The physical key to unmap.
 * Returns: Whether the key was mapped to any event.
 */
bool removeKeyMappings(KeyboardScanCode scanCode) {
    return keyMapping.remove(scanCode);
}

/**
 * Returns: Whether the given key emits the given event.
 */
bool hasKeyMapping(KeyboardScanCode scanCode, StringId eventName) {
    auto eventNames = keyMapping.getRef(scanCode);
    return eventNames.isDefined && eventNames.value.exists(eventName);
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
        auto eventNames = keyMapping.getRef(keyEvent.scanCode);
        if (!eventNames.isDefined) {
            continue;
        }

        auto magnitude = keyEvent.action == InputEventAction.release ? 0 : 1;
        foreach (eventName; *eventNames.value) {
            eventQueue.enqueue(Event(eventName, magnitude));
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
    ctrl = 1 << 12,
    shift = 1 << 13,
    alt = 1 << 14,
    gui = 1 << 15
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

private void pressKey(KeyboardScanCode scanCode, InputEventAction action = InputEventAction.press) {
    KeyboardKeyEvent keyEvent;
    keyEvent.scanCode = scanCode;
    keyEvent.action = action;
    keyEvents.enqueue(keyEvent);
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
