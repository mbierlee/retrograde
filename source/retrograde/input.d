/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2018 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.input;

import retrograde.messaging;
import retrograde.stringid;

import poodinis;

import std.signals;
import std.stdio;
import std.format;
import std.math;
import std.traits;
import std.algorithm;
import std.typecons;

enum InputEvent : StringId {
    JOYSTICK_AXIS_MOVEMENT = sid("ev_joystick_axis_movement"),
    JOYSTICK_BALL_MOVEMENT = sid("ev_joystick_ball_movement"),
    JOYSTICK_HAT = sid("ev_joystick_hat"),
    JOYSTICK_BUTTON = sid("ev_joystick_button"),
    JOYSTICK_ADDED = sid("ev_joystick_added"),
    JOYSTICK_REMOVED = sid("ev_joystick_removed"),
    KEYBOARD_KEY = sid("ev_keyboard_key"),
    MOUSE_MOTION = sid("ev_mouse_motion"),
    MOUSE_BUTTON = sid("ev_mouse_button"),
    MOUSE_WHEEL = sid("ev_mouse_wheel")
}

public void registerInputEventDebugSids(SidMap sidMap) {
    sidMap.add("ev_joystick_axis_movement");
    sidMap.add("ev_joystick_ball_movement");
    sidMap.add("ev_joystick_hat");
    sidMap.add("ev_joystick_button");
    sidMap.add("ev_joystick_added");
    sidMap.add("ev_joystick_removed");
    sidMap.add("ev_keyboard_key");
    sidMap.add("ev_mouse_motion");
    sidMap.add("ev_mouse_button");
    sidMap.add("ev_mouse_wheel");
}

class InputMessageData : MessageData {
    public Device device;
}

class JoystickAxisEventData : InputMessageData {
    public ubyte axis;
}

enum JoystickBallAxis {
    X, Y
}

class JoystickBallEventData : InputMessageData {
    public ubyte ball;
    public JoystickBallAxis axis;
}

enum JoystickHatPosition {
    LEFT_UP,
    LEFT,
    LEFT_DOWN,
    UP,
    CENTERED,
    DOWN,
    RIGHT_UP,
    RIGHT,
    RIGHT_DOWN
}

class JoystickHatEventData : InputMessageData {
    public ubyte hat;
    public JoystickHatPosition postion;
}

class JoystickButtonEventData : InputMessageData {
    public ubyte button;
}

enum KeyboardKeyCode {
    A,
    AC_BACK,
    AC_BOOKMARKS,
    AC_FORWARD,
    AC_HOME,
    AC_REFRESH,
    AC_SEARCH,
    AC_STOP,
    AGAIN,
    ALTERASE,
    APOSTROPHE,
    APP1,
    APP2,
    APPLICATION,
    AUDIOMUTE,
    AUDIONEXT,
    AUDIOPLAY,
    AUDIOPREV,
    AUDIOSTOP,
    B,
    BACKSLASH,
    BACKSPACE,
    BRIGHTNESSDOWN,
    BRIGHTNESSUP,
    C,
    CALCULATOR,
    CANCEL,
    CAPSLOCK,
    CLEAR,
    CLEARAGAIN,
    COMMA,
    COMPUTER,
    COPY,
    CRSEL,
    CURRENCYSUBUNIT,
    CURRENCYUNIT,
    CUT,
    D,
    DECIMALSEPARATOR,
    DELETE,
    DISPLAYSWITCH,
    DOWN,
    E,
    EIGHT,
    EJECT,
    END,
    EQUALS,
    ESCAPE,
    EXECUTE,
    EXSEL,
    F,
    F1,
    F10,
    F11,
    F12,
    F13,
    F14,
    F15,
    F16,
    F17,
    F18,
    F19,
    F2,
    F20,
    F21,
    F22,
    F23,
    F24,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    FIND,
    FIVE,
    FOUR,
    G,
    GRAVE,
    H,
    HELP,
    HOME,
    I,
    INSERT,
    INTERNATIONAL1,
    INTERNATIONAL2,
    INTERNATIONAL3,
    INTERNATIONAL4,
    INTERNATIONAL5,
    INTERNATIONAL6,
    INTERNATIONAL7,
    INTERNATIONAL8,
    INTERNATIONAL9,
    J,
    K,
    KBDILLUMDOWN,
    KBDILLUMTOGGLE,
    KBDILLUMUP,
    KEYPAD_00,
    KEYPAD_000,
    KEYPAD_COMMA,
    KEYPAD_DIVIDE,
    KEYPAD_EIGHT,
    KEYPAD_ENTER,
    KEYPAD_EQUALS,
    KEYPAD_EQUALSAS400,
    KEYPAD_FIVE,
    KEYPAD_FOUR,
    KEYPAD_MINUS,
    KEYPAD_MULTIPLY,
    KEYPAD_NINE,
    KEYPAD_ONE,
    KEYPAD_PERIOD,
    KEYPAD_PLUS,
    KEYPAD_SEVEN,
    KEYPAD_SIX,
    KEYPAD_THREE,
    KEYPAD_TWO,
    KEYPAD_ZERO,
    KP_A,
    KP_AMPERSAND,
    KP_AT,
    KP_B,
    KP_BACKSPACE,
    KP_BINARY,
    KP_C,
    KP_CLEAR,
    KP_CLEARENTRY,
    KP_COLON,
    KP_D,
    KP_DBLAMPERSAND,
    KP_DBLVERTICALBAR,
    KP_DECIMAL,
    KP_E,
    KP_EXCLAM,
    KP_F,
    KP_GREATER,
    KP_HASH,
    KP_HEXADECIMAL,
    KP_LEFTBRACE,
    KP_LEFTPAREN,
    KP_LESS,
    KP_MEMADD,
    KP_MEMCLEAR,
    KP_MEMDIVIDE,
    KP_MEMMULTIPLY,
    KP_MEMRECALL,
    KP_MEMSTORE,
    KP_MEMSUBTRACT,
    KP_OCTAL,
    KP_PERCENT,
    KP_PLUSMINUS,
    KP_POWER,
    KP_RIGHTBRACE,
    KP_RIGHTPAREN,
    KP_SPACE,
    KP_TAB,
    KP_VERTICALBAR,
    KP_XOR,
    L,
    LALT,
    LANG1,
    LANG2,
    LANG3,
    LANG4,
    LANG5,
    LANG6,
    LANG7,
    LANG8,
    LANG9,
    LCTRL,
    LEFT,
    LEFTBRACKET,
    LGUI,
    LSHIFT,
    M,
    MAIL,
    MEDIASELECT,
    MENU,
    MINUS,
    MODE,
    MUTE,
    N,
    NINE,
    NONUSBACKSLASH,
    NONUSHASH,
    NUMLOCKCLEAR,
    O,
    ONE,
    OPER,
    OUT,
    P,
    PAGEDOWN,
    PAGEUP,
    PASTE,
    PAUSE,
    PERIOD,
    POWER,
    PRINTSCREEN,
    PRIOR,
    Q,
    R,
    RALT,
    RCTRL,
    RETURN,
    RETURN2,
    RGUI,
    RIGHT,
    RIGHTBRACKET,
    RSHIFT,
    S,
    SCROLLLOCK,
    SELECT,
    SEMICOLON,
    SEPARATOR,
    SEVEN,
    SIX,
    SLASH,
    SLEEP,
    SPACE,
    STOP,
    SYSREQ,
    T,
    TAB,
    THOUSANDSSEPARATOR,
    THREE,
    TWO,
    U,
    UNDO,
    UP,
    V,
    VOLUMEDOWN,
    VOLUMEUP,
    W,
    WWW,
    X,
    Y,
    Z,
    ZERO
}

enum MouseButton {
    LEFT,
    MIDDLE,
    RIGHT,
    X1,
    X2
}

enum KeyboardKeyModifier : int {
    NONE   = 1<<0,
    LSHIFT = 1<<2,
    RSHIFT = 1<<3,
    LCTRL  = 1<<4,
    RCTRL  = 1<<5,
    LALT   = 1<<6,
    RALT   = 1<<7,
    LGUI   = 1<<8,
    RGUI   = 1<<9,
    NUM    = 1<<10,
    CAPS   = 1<<11,
    MODE   = 1<<12,
    CTRL   = 1<<13,
    SHIFT  = 1<<14,
    ALT    = 1<<15,
    GUI    = 1<<16
}

alias InvertMagnitude = Flag!"InvertMagnitude";

class KeyboardKeyEventData : InputMessageData {
    public KeyboardKeyCode scanCode;
    public KeyboardKeyModifier modifiers;
}

enum MouseAxis {
    X, Y
}

class MouseMotionEventData : InputMessageData {
    public MouseAxis axis;
    public int absolutePosition;
}

class MouseButtonEventData : InputMessageData {
    public MouseButton button;
}

struct EventMappingKey {
    public StringId eventName;
    public uint componentOne;
    public uint componentTwo;
}

class RawInputEventChannel : EventChannel {}
class MappedInputCommandChannel : CommandChannel {}

struct Device {
    DeviceType type;
    int id;
}

enum DeviceType {
    unknown,
    joystick,
    keyboard,
    mouse
}

class MappedInputCommandData : InputMessageData {}

class InputHandler {

    @Autowire
    private MappedInputCommandChannel mappedInputCommandChannel;

    @Autowire
    private RawInputEventChannel rawInputEventChannel;

    private const(Event)[] eventQueue;
    private StringId[][EventMappingKey] eventMappings;
    private double[ubyte] axisDeadzones;
    private StringId[] inputEvents;
    private bool[EventMappingKey] invertMagnitudeMap;

    public this() {
        inputEvents = [EnumMembers!InputEvent];
    }

    public void initialize() {
        rawInputEventChannel.connect(&queueEventHandlerEvent);
    }

    private void queueEventHandlerEvent(const(Event) event) {
        if (inputEvents.canFind(event.type)) {
            eventQueue ~= event;
        }
    }

    public void handleEvents() {
        foreach (event; eventQueue) {
            auto eventKey = createMappingKey(event);
            auto mappedEvents = eventKey in eventMappings;
            if (mappedEvents) {
                double magnitude = event.magnitude;
                if (event.type == InputEvent.JOYSTICK_AXIS_MOVEMENT) {
                    magnitude = calculateAxisDeadzoneMagnitude(event);
                }

                auto invertMagnitude = eventKey in invertMagnitudeMap;
                if (invertMagnitude !is null && *invertMagnitude == true) {
                    magnitude *= -1;
                }

                MappedInputCommandData mappedCommandData = null;
                auto inputEventData = cast(InputMessageData) event.data;
                if (inputEventData) {
                    mappedCommandData = new MappedInputCommandData();
                    mappedCommandData.device = inputEventData.device;
                }

                foreach(mappedEvent; *mappedEvents) {
                    mappedInputCommandChannel.emit(Command(mappedEvent, magnitude, mappedCommandData));
                }
            }
        }

        eventQueue.destroy();
    }

    private double calculateAxisDeadzoneMagnitude(const ref Event event) {
        auto magnitude = event.magnitude;
        auto data = cast(JoystickAxisEventData) event.data;
        auto deadzone = data.axis in axisDeadzones;
        if (deadzone && abs(magnitude) < *deadzone) {
            return 0;
        }

        return magnitude;
    }

    private EventMappingKey createMappingKey(const ref Event event) {
        auto eventKey = EventMappingKey(event.type, 0);

        switch (event.type) {
            case InputEvent.JOYSTICK_AXIS_MOVEMENT:
                auto data = cast(JoystickAxisEventData) event.data;
                eventKey.componentOne = data.axis;
                break;
            case InputEvent.JOYSTICK_BALL_MOVEMENT:
                auto data = cast(JoystickBallEventData) event.data;
                eventKey.componentOne = data.ball;
                eventKey.componentTwo = data.axis;
                break;
            case InputEvent.JOYSTICK_BUTTON:
                auto data = cast(JoystickButtonEventData) event.data;
                eventKey.componentOne = data.button;
                break;
            case InputEvent.JOYSTICK_HAT:
                auto data = cast(JoystickHatEventData) event.data;
                eventKey.componentOne = data.hat;
                break;
            case InputEvent.KEYBOARD_KEY:
                auto data = cast(KeyboardKeyEventData) event.data;
                eventKey.componentOne = data.scanCode;
                break;
            case InputEvent.MOUSE_MOTION:
                auto data = cast(MouseMotionEventData) event.data;
                eventKey.componentOne = data.axis;
                break;
            case InputEvent.MOUSE_BUTTON:
                auto data = cast(MouseButtonEventData) event.data;
                eventKey.componentOne = data.button;
                break;
            default:
                break;
        }

        return eventKey;
    }

    public void setEventMapping(EventMappingKey sourceKey, StringId targetCommand, InvertMagnitude invertMagnitude = InvertMagnitude.no) {
        setEventMapping(sourceKey, [targetCommand], invertMagnitude);
    }

    public void setEventMapping(EventMappingKey sourceKey, StringId[] targetCommands, InvertMagnitude invertMagnitude = InvertMagnitude.no) {
        eventMappings[sourceKey] = targetCommands;
        invertMagnitudeMap[sourceKey] = invertMagnitude;
    }

    public void setJoystickAxisDeadzone(ubyte axis, double deadzone) {
        axisDeadzones[axis] = deadzone;
    }
}
