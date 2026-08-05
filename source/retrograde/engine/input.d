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

import retrograde.std.collections : Queue, HashMap;
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

// TODO: allow mapping on modifiers too
// TODO: Support mapping to multiple stringids? e.g. for W -> ev_moveFoward and ev_menuUp
HashMap!(KeyboardKeyCode, StringId) keyMapping;

void processInput() {
    KeyboardKeyEvent keyEvent;
    while (keyEvents.tryDequeue(keyEvent)) {
        StringId eventName;
        if (keyMapping.tryGet(keyEvent.scancode, eventName)) {
            eventQueue.enqueue(Event(
                    eventName,
                    keyEvent.action == InputEventAction.release ? 0 : 1
            ));
        }
    }
}

enum InputMethod : ubyte {
    keyboard = 1 << 0,
    mouse = 1 << 1
}

/**
 * Available keyboard codes for keyboard-input.
 * This list is based off of SDL2's key code list.
 * Not all platforms may map all of them.
 */
enum KeyboardKeyCode : uint {
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
 */
struct KeyboardKeyEvent {
    /**
     * Unicode code point of the character the key produced, or 0 when the
     * key does not produce a character, such as when pressing an arrow key
     * or a modifier. Which character a key produces depends on the keyboard
     * layout and on the modifiers held at the time.
     */
    dchar key;

    /**
     * Physical key that was pressed, independent of keyboard layout.
     * The same key always reports the same scancode, whereas the
     * character it produces may differ per layout.
     */
    KeyboardKeyCode scancode;

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
