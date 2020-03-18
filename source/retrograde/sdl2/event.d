/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2020 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.sdl2.event;

version(Have_derelict_sdl2) {

import retrograde.messaging;
import retrograde.engine;
import retrograde.sdl2.input;
import retrograde.input;

import poodinis;

import derelict.sdl2.sdl;

class Sdl2EventHandler : EventHandler {

    private immutable JoystickHatPosition[ubyte] hatMap;
    private KeyboardKeyCode[SDL_Scancode] scanCodeMap;
    private MouseButton[ubyte] mouseButtonMap;
    private bool previouslyHandledMouseMotionEvent = false;

    @Autowire
    private Sdl2InputDeviceManager inputDeviceManager;

    @Autowire
    private RawInputEventChannel rawInputEventChannel;

    @Autowire
    private CoreEngineCommandChannel coreEngineCommandChannel;

    private const int mouseMotionMax = 60;

    public this() {
        hatMap = [
            SDL_HAT_LEFTUP: JoystickHatPosition.LEFT_UP,
            SDL_HAT_LEFT: JoystickHatPosition.LEFT,
            SDL_HAT_LEFTDOWN: JoystickHatPosition.LEFT_DOWN,
            SDL_HAT_UP: JoystickHatPosition.UP,
            SDL_HAT_CENTERED: JoystickHatPosition.CENTERED,
            SDL_HAT_DOWN: JoystickHatPosition.DOWN,
            SDL_HAT_RIGHTUP: JoystickHatPosition.RIGHT_UP,
            SDL_HAT_RIGHT: JoystickHatPosition.RIGHT,
            SDL_HAT_RIGHTDOWN: JoystickHatPosition.RIGHT_DOWN
        ];

        scanCodeMap = [
            SDL_SCANCODE_A: KeyboardKeyCode.A,
            SDL_SCANCODE_B: KeyboardKeyCode.B,
            SDL_SCANCODE_C: KeyboardKeyCode.C,
            SDL_SCANCODE_D: KeyboardKeyCode.D,
            SDL_SCANCODE_E: KeyboardKeyCode.E,
            SDL_SCANCODE_F: KeyboardKeyCode.F,
            SDL_SCANCODE_G: KeyboardKeyCode.G,
            SDL_SCANCODE_H: KeyboardKeyCode.H,
            SDL_SCANCODE_I: KeyboardKeyCode.I,
            SDL_SCANCODE_J: KeyboardKeyCode.J,
            SDL_SCANCODE_K: KeyboardKeyCode.K,
            SDL_SCANCODE_L: KeyboardKeyCode.L,
            SDL_SCANCODE_M: KeyboardKeyCode.M,
            SDL_SCANCODE_N: KeyboardKeyCode.N,
            SDL_SCANCODE_O: KeyboardKeyCode.O,
            SDL_SCANCODE_P: KeyboardKeyCode.P,
            SDL_SCANCODE_Q: KeyboardKeyCode.Q,
            SDL_SCANCODE_R: KeyboardKeyCode.R,
            SDL_SCANCODE_S: KeyboardKeyCode.S,
            SDL_SCANCODE_T: KeyboardKeyCode.T,
            SDL_SCANCODE_U: KeyboardKeyCode.U,
            SDL_SCANCODE_V: KeyboardKeyCode.V,
            SDL_SCANCODE_W: KeyboardKeyCode.W,
            SDL_SCANCODE_X: KeyboardKeyCode.X,
            SDL_SCANCODE_Y: KeyboardKeyCode.Y,
            SDL_SCANCODE_Z: KeyboardKeyCode.Z,

            SDL_SCANCODE_1: KeyboardKeyCode.ONE,
            SDL_SCANCODE_2: KeyboardKeyCode.TWO,
            SDL_SCANCODE_3: KeyboardKeyCode.THREE,
            SDL_SCANCODE_4: KeyboardKeyCode.FOUR,
            SDL_SCANCODE_5: KeyboardKeyCode.FIVE,
            SDL_SCANCODE_6: KeyboardKeyCode.SIX,
            SDL_SCANCODE_7: KeyboardKeyCode.SEVEN,
            SDL_SCANCODE_8: KeyboardKeyCode.EIGHT,
            SDL_SCANCODE_9: KeyboardKeyCode.NINE,
            SDL_SCANCODE_0: KeyboardKeyCode.ZERO,

            SDL_SCANCODE_RETURN: KeyboardKeyCode.RETURN,
            SDL_SCANCODE_ESCAPE: KeyboardKeyCode.ESCAPE,
            SDL_SCANCODE_BACKSPACE: KeyboardKeyCode.BACKSPACE,
            SDL_SCANCODE_TAB:  KeyboardKeyCode.TAB,
            SDL_SCANCODE_SPACE:  KeyboardKeyCode.SPACE,

            SDL_SCANCODE_MINUS: KeyboardKeyCode.MINUS,
            SDL_SCANCODE_EQUALS: KeyboardKeyCode.EQUALS,
            SDL_SCANCODE_LEFTBRACKET: KeyboardKeyCode.LEFTBRACKET,
            SDL_SCANCODE_RIGHTBRACKET: KeyboardKeyCode.RIGHTBRACKET,
            SDL_SCANCODE_BACKSLASH: KeyboardKeyCode.BACKSLASH,
            SDL_SCANCODE_NONUSHASH: KeyboardKeyCode.NONUSHASH,
            SDL_SCANCODE_SEMICOLON: KeyboardKeyCode.SEMICOLON,
            SDL_SCANCODE_APOSTROPHE: KeyboardKeyCode.APOSTROPHE,
            SDL_SCANCODE_GRAVE: KeyboardKeyCode.GRAVE,
            SDL_SCANCODE_COMMA: KeyboardKeyCode.COMMA,
            SDL_SCANCODE_PERIOD: KeyboardKeyCode.PERIOD,
            SDL_SCANCODE_SLASH: KeyboardKeyCode.SLASH,

            SDL_SCANCODE_CAPSLOCK: KeyboardKeyCode.CAPSLOCK,

            SDL_SCANCODE_F1: KeyboardKeyCode.F1,
            SDL_SCANCODE_F2: KeyboardKeyCode.F2,
            SDL_SCANCODE_F3: KeyboardKeyCode.F3,
            SDL_SCANCODE_F4: KeyboardKeyCode.F4,
            SDL_SCANCODE_F5: KeyboardKeyCode.F5,
            SDL_SCANCODE_F6: KeyboardKeyCode.F6,
            SDL_SCANCODE_F7: KeyboardKeyCode.F7,
            SDL_SCANCODE_F8: KeyboardKeyCode.F8,
            SDL_SCANCODE_F9: KeyboardKeyCode.F9,
            SDL_SCANCODE_F10: KeyboardKeyCode.F10,
            SDL_SCANCODE_F11: KeyboardKeyCode.F11,
            SDL_SCANCODE_F12: KeyboardKeyCode.F12,

            SDL_SCANCODE_PRINTSCREEN: KeyboardKeyCode.PRINTSCREEN,
            SDL_SCANCODE_SCROLLLOCK: KeyboardKeyCode.SCROLLLOCK,
            SDL_SCANCODE_PAUSE: KeyboardKeyCode.PAUSE,
            SDL_SCANCODE_INSERT: KeyboardKeyCode.INSERT,
            SDL_SCANCODE_HOME: KeyboardKeyCode.HOME,
            SDL_SCANCODE_PAGEUP: KeyboardKeyCode.PAGEUP,
            SDL_SCANCODE_DELETE: KeyboardKeyCode.DELETE,
            SDL_SCANCODE_END: KeyboardKeyCode.END,
            SDL_SCANCODE_PAGEDOWN: KeyboardKeyCode.PAGEDOWN,
            SDL_SCANCODE_RIGHT: KeyboardKeyCode.RIGHT,
            SDL_SCANCODE_LEFT: KeyboardKeyCode.LEFT,
            SDL_SCANCODE_DOWN: KeyboardKeyCode.DOWN,
            SDL_SCANCODE_UP: KeyboardKeyCode.UP,

            SDL_SCANCODE_NUMLOCKCLEAR: KeyboardKeyCode.NUMLOCKCLEAR,
            SDL_SCANCODE_KP_DIVIDE: KeyboardKeyCode.KEYPAD_DIVIDE,
            SDL_SCANCODE_KP_MULTIPLY: KeyboardKeyCode.KEYPAD_MULTIPLY,
            SDL_SCANCODE_KP_MINUS: KeyboardKeyCode.KEYPAD_MINUS,
            SDL_SCANCODE_KP_PLUS: KeyboardKeyCode.KEYPAD_PLUS,
            SDL_SCANCODE_KP_ENTER: KeyboardKeyCode.KEYPAD_ENTER,
            SDL_SCANCODE_KP_1: KeyboardKeyCode.KEYPAD_ONE,
            SDL_SCANCODE_KP_2: KeyboardKeyCode.KEYPAD_TWO,
            SDL_SCANCODE_KP_3: KeyboardKeyCode.KEYPAD_THREE,
            SDL_SCANCODE_KP_4: KeyboardKeyCode.KEYPAD_FOUR,
            SDL_SCANCODE_KP_5: KeyboardKeyCode.KEYPAD_FIVE,
            SDL_SCANCODE_KP_6: KeyboardKeyCode.KEYPAD_SIX,
            SDL_SCANCODE_KP_7: KeyboardKeyCode.KEYPAD_SEVEN,
            SDL_SCANCODE_KP_8: KeyboardKeyCode.KEYPAD_EIGHT,
            SDL_SCANCODE_KP_9: KeyboardKeyCode.KEYPAD_NINE,
            SDL_SCANCODE_KP_0: KeyboardKeyCode.KEYPAD_ZERO,
            SDL_SCANCODE_KP_PERIOD: KeyboardKeyCode.KEYPAD_PERIOD,

            SDL_SCANCODE_NONUSBACKSLASH: KeyboardKeyCode.NONUSBACKSLASH,
            SDL_SCANCODE_APPLICATION: KeyboardKeyCode.APPLICATION,
            SDL_SCANCODE_POWER: KeyboardKeyCode.POWER,
            SDL_SCANCODE_KP_EQUALS: KeyboardKeyCode.KEYPAD_EQUALS,
            SDL_SCANCODE_F13: KeyboardKeyCode.F13,
            SDL_SCANCODE_F14: KeyboardKeyCode.F14,
            SDL_SCANCODE_F15: KeyboardKeyCode.F15,
            SDL_SCANCODE_F16: KeyboardKeyCode.F16,
            SDL_SCANCODE_F17: KeyboardKeyCode.F17,
            SDL_SCANCODE_F18: KeyboardKeyCode.F18,
            SDL_SCANCODE_F19: KeyboardKeyCode.F19,
            SDL_SCANCODE_F20: KeyboardKeyCode.F20,
            SDL_SCANCODE_F21: KeyboardKeyCode.F21,
            SDL_SCANCODE_F22: KeyboardKeyCode.F22,
            SDL_SCANCODE_F23: KeyboardKeyCode.F23,
            SDL_SCANCODE_F24: KeyboardKeyCode.F24,
            SDL_SCANCODE_EXECUTE: KeyboardKeyCode.EXECUTE,
            SDL_SCANCODE_HELP: KeyboardKeyCode.HELP,
            SDL_SCANCODE_MENU: KeyboardKeyCode.MENU,
            SDL_SCANCODE_SELECT: KeyboardKeyCode.SELECT,
            SDL_SCANCODE_STOP: KeyboardKeyCode.STOP,
            SDL_SCANCODE_AGAIN: KeyboardKeyCode.AGAIN,
            SDL_SCANCODE_UNDO: KeyboardKeyCode.UNDO,
            SDL_SCANCODE_CUT: KeyboardKeyCode.CUT,
            SDL_SCANCODE_COPY: KeyboardKeyCode.COPY,
            SDL_SCANCODE_PASTE: KeyboardKeyCode.PASTE,
            SDL_SCANCODE_FIND: KeyboardKeyCode.FIND,
            SDL_SCANCODE_MUTE: KeyboardKeyCode.MUTE,
            SDL_SCANCODE_VOLUMEUP: KeyboardKeyCode.VOLUMEUP,
            SDL_SCANCODE_VOLUMEDOWN: KeyboardKeyCode.VOLUMEDOWN,
            SDL_SCANCODE_KP_COMMA: KeyboardKeyCode.KEYPAD_COMMA,
            SDL_SCANCODE_KP_EQUALSAS400: KeyboardKeyCode.KEYPAD_EQUALSAS400,

            SDL_SCANCODE_INTERNATIONAL1: KeyboardKeyCode.INTERNATIONAL1,
            SDL_SCANCODE_INTERNATIONAL2: KeyboardKeyCode.INTERNATIONAL2,
            SDL_SCANCODE_INTERNATIONAL3: KeyboardKeyCode.INTERNATIONAL3,
            SDL_SCANCODE_INTERNATIONAL4: KeyboardKeyCode.INTERNATIONAL4,
            SDL_SCANCODE_INTERNATIONAL5: KeyboardKeyCode.INTERNATIONAL5,
            SDL_SCANCODE_INTERNATIONAL6: KeyboardKeyCode.INTERNATIONAL6,
            SDL_SCANCODE_INTERNATIONAL7: KeyboardKeyCode.INTERNATIONAL7,
            SDL_SCANCODE_INTERNATIONAL8: KeyboardKeyCode.INTERNATIONAL8,
            SDL_SCANCODE_INTERNATIONAL9: KeyboardKeyCode.INTERNATIONAL9,
            SDL_SCANCODE_LANG1: KeyboardKeyCode.LANG1,
            SDL_SCANCODE_LANG2: KeyboardKeyCode.LANG2,
            SDL_SCANCODE_LANG3: KeyboardKeyCode.LANG3,
            SDL_SCANCODE_LANG4: KeyboardKeyCode.LANG4,
            SDL_SCANCODE_LANG5: KeyboardKeyCode.LANG5,
            SDL_SCANCODE_LANG6: KeyboardKeyCode.LANG6,
            SDL_SCANCODE_LANG7: KeyboardKeyCode.LANG7,
            SDL_SCANCODE_LANG8: KeyboardKeyCode.LANG8,
            SDL_SCANCODE_LANG9: KeyboardKeyCode.LANG9,

            SDL_SCANCODE_ALTERASE: KeyboardKeyCode.ALTERASE,
            SDL_SCANCODE_SYSREQ: KeyboardKeyCode.SYSREQ,
            SDL_SCANCODE_CANCEL: KeyboardKeyCode.CANCEL,
            SDL_SCANCODE_CLEAR: KeyboardKeyCode.CLEAR,
            SDL_SCANCODE_PRIOR: KeyboardKeyCode.PRIOR,
            SDL_SCANCODE_RETURN2: KeyboardKeyCode.RETURN2,
            SDL_SCANCODE_SEPARATOR: KeyboardKeyCode.SEPARATOR,
            SDL_SCANCODE_OUT: KeyboardKeyCode.OUT,
            SDL_SCANCODE_OPER: KeyboardKeyCode.OPER,
            SDL_SCANCODE_CLEARAGAIN: KeyboardKeyCode.CLEARAGAIN,
            SDL_SCANCODE_CRSEL: KeyboardKeyCode.CRSEL,
            SDL_SCANCODE_EXSEL: KeyboardKeyCode.EXSEL,

            SDL_SCANCODE_KP_00: KeyboardKeyCode.KEYPAD_00,
            SDL_SCANCODE_KP_000: KeyboardKeyCode.KEYPAD_000,
            SDL_SCANCODE_THOUSANDSSEPARATOR: KeyboardKeyCode.THOUSANDSSEPARATOR,
            SDL_SCANCODE_DECIMALSEPARATOR: KeyboardKeyCode.DECIMALSEPARATOR,
            SDL_SCANCODE_CURRENCYUNIT: KeyboardKeyCode.CURRENCYUNIT,
            SDL_SCANCODE_CURRENCYSUBUNIT: KeyboardKeyCode.CURRENCYSUBUNIT,
            SDL_SCANCODE_KP_LEFTPAREN: KeyboardKeyCode.KP_LEFTPAREN,
            SDL_SCANCODE_KP_RIGHTPAREN: KeyboardKeyCode.KP_RIGHTPAREN,
            SDL_SCANCODE_KP_LEFTBRACE: KeyboardKeyCode.KP_LEFTBRACE,
            SDL_SCANCODE_KP_RIGHTBRACE: KeyboardKeyCode.KP_RIGHTBRACE,
            SDL_SCANCODE_KP_TAB: KeyboardKeyCode.KP_TAB,
            SDL_SCANCODE_KP_BACKSPACE: KeyboardKeyCode.KP_BACKSPACE,
            SDL_SCANCODE_KP_A: KeyboardKeyCode.KP_A,
            SDL_SCANCODE_KP_B: KeyboardKeyCode.KP_B,
            SDL_SCANCODE_KP_C: KeyboardKeyCode.KP_C,
            SDL_SCANCODE_KP_D: KeyboardKeyCode.KP_D,
            SDL_SCANCODE_KP_E: KeyboardKeyCode.KP_E,
            SDL_SCANCODE_KP_F: KeyboardKeyCode.KP_F,
            SDL_SCANCODE_KP_XOR: KeyboardKeyCode.KP_XOR,
            SDL_SCANCODE_KP_POWER: KeyboardKeyCode.KP_POWER,
            SDL_SCANCODE_KP_PERCENT: KeyboardKeyCode.KP_PERCENT,
            SDL_SCANCODE_KP_LESS: KeyboardKeyCode.KP_LESS,
            SDL_SCANCODE_KP_GREATER: KeyboardKeyCode.KP_GREATER,
            SDL_SCANCODE_KP_AMPERSAND: KeyboardKeyCode.KP_AMPERSAND,
            SDL_SCANCODE_KP_DBLAMPERSAND: KeyboardKeyCode.KP_DBLAMPERSAND,
            SDL_SCANCODE_KP_VERTICALBAR: KeyboardKeyCode.KP_VERTICALBAR,
            SDL_SCANCODE_KP_DBLVERTICALBAR: KeyboardKeyCode.KP_DBLVERTICALBAR,
            SDL_SCANCODE_KP_COLON: KeyboardKeyCode.KP_COLON,
            SDL_SCANCODE_KP_HASH: KeyboardKeyCode.KP_HASH,
            SDL_SCANCODE_KP_SPACE: KeyboardKeyCode.KP_SPACE,
            SDL_SCANCODE_KP_AT: KeyboardKeyCode.KP_AT,
            SDL_SCANCODE_KP_EXCLAM: KeyboardKeyCode.KP_EXCLAM,
            SDL_SCANCODE_KP_MEMSTORE: KeyboardKeyCode.KP_MEMSTORE,
            SDL_SCANCODE_KP_MEMRECALL: KeyboardKeyCode.KP_MEMRECALL,
            SDL_SCANCODE_KP_MEMCLEAR: KeyboardKeyCode.KP_MEMCLEAR,
            SDL_SCANCODE_KP_MEMADD: KeyboardKeyCode.KP_MEMADD,
            SDL_SCANCODE_KP_MEMSUBTRACT: KeyboardKeyCode.KP_MEMSUBTRACT,
            SDL_SCANCODE_KP_MEMMULTIPLY: KeyboardKeyCode.KP_MEMMULTIPLY,
            SDL_SCANCODE_KP_MEMDIVIDE: KeyboardKeyCode.KP_MEMDIVIDE,
            SDL_SCANCODE_KP_PLUSMINUS: KeyboardKeyCode.KP_PLUSMINUS,
            SDL_SCANCODE_KP_CLEAR: KeyboardKeyCode.KP_CLEAR,
            SDL_SCANCODE_KP_CLEARENTRY: KeyboardKeyCode.KP_CLEARENTRY,
            SDL_SCANCODE_KP_BINARY: KeyboardKeyCode.KP_BINARY,
            SDL_SCANCODE_KP_OCTAL: KeyboardKeyCode.KP_OCTAL,
            SDL_SCANCODE_KP_DECIMAL: KeyboardKeyCode.KP_DECIMAL,
            SDL_SCANCODE_KP_HEXADECIMAL: KeyboardKeyCode.KP_HEXADECIMAL,

            SDL_SCANCODE_LCTRL: KeyboardKeyCode.LCTRL,
            SDL_SCANCODE_LSHIFT: KeyboardKeyCode.LSHIFT,
            SDL_SCANCODE_LALT: KeyboardKeyCode.LALT,
            SDL_SCANCODE_LGUI: KeyboardKeyCode.LGUI,
            SDL_SCANCODE_RCTRL: KeyboardKeyCode.RCTRL,
            SDL_SCANCODE_RSHIFT: KeyboardKeyCode.RSHIFT,
            SDL_SCANCODE_RALT: KeyboardKeyCode.RALT,
            SDL_SCANCODE_RGUI: KeyboardKeyCode.RGUI,

            SDL_SCANCODE_MODE: KeyboardKeyCode.MODE,

            SDL_SCANCODE_AUDIONEXT: KeyboardKeyCode.AUDIONEXT,
            SDL_SCANCODE_AUDIOPREV: KeyboardKeyCode.AUDIOPREV,
            SDL_SCANCODE_AUDIOSTOP: KeyboardKeyCode.AUDIOSTOP,
            SDL_SCANCODE_AUDIOPLAY: KeyboardKeyCode.AUDIOPLAY,
            SDL_SCANCODE_AUDIOMUTE: KeyboardKeyCode.AUDIOMUTE,
            SDL_SCANCODE_MEDIASELECT: KeyboardKeyCode.MEDIASELECT,
            SDL_SCANCODE_WWW: KeyboardKeyCode.WWW,
            SDL_SCANCODE_MAIL: KeyboardKeyCode.MAIL,
            SDL_SCANCODE_CALCULATOR: KeyboardKeyCode.CALCULATOR,
            SDL_SCANCODE_COMPUTER: KeyboardKeyCode.COMPUTER,
            SDL_SCANCODE_AC_SEARCH: KeyboardKeyCode.AC_SEARCH,
            SDL_SCANCODE_AC_HOME: KeyboardKeyCode.AC_HOME,
            SDL_SCANCODE_AC_BACK: KeyboardKeyCode.AC_BACK,
            SDL_SCANCODE_AC_FORWARD: KeyboardKeyCode.AC_FORWARD,
            SDL_SCANCODE_AC_STOP: KeyboardKeyCode.AC_STOP,
            SDL_SCANCODE_AC_REFRESH: KeyboardKeyCode.AC_REFRESH,
            SDL_SCANCODE_AC_BOOKMARKS: KeyboardKeyCode.AC_BOOKMARKS,

            SDL_SCANCODE_BRIGHTNESSDOWN: KeyboardKeyCode.BRIGHTNESSDOWN,
            SDL_SCANCODE_BRIGHTNESSUP: KeyboardKeyCode.BRIGHTNESSUP,
            SDL_SCANCODE_DISPLAYSWITCH: KeyboardKeyCode.DISPLAYSWITCH,
            SDL_SCANCODE_KBDILLUMTOGGLE: KeyboardKeyCode.KBDILLUMTOGGLE,
            SDL_SCANCODE_KBDILLUMDOWN: KeyboardKeyCode.KBDILLUMDOWN,
            SDL_SCANCODE_KBDILLUMUP: KeyboardKeyCode.KBDILLUMUP,
            SDL_SCANCODE_EJECT: KeyboardKeyCode.EJECT,
            SDL_SCANCODE_SLEEP: KeyboardKeyCode.SLEEP,

            SDL_SCANCODE_APP1: KeyboardKeyCode.APP1,
            SDL_SCANCODE_APP2: KeyboardKeyCode.APP2
        ];

        mouseButtonMap = [
            SDL_BUTTON_LEFT: MouseButton.LEFT,
            SDL_BUTTON_MIDDLE: MouseButton.MIDDLE,
            SDL_BUTTON_RIGHT: MouseButton.RIGHT,
            SDL_BUTTON_X1: MouseButton.X1,
            SDL_BUTTON_X2: MouseButton.X2
        ];
    }

    public override void handleEvents() {
        SDL_Event event;
        bool handledMouseMotionEvent = false;

        while (SDL_PollEvent(&event)) {
            switch(event.type) {
                case SDL_QUIT:
                    coreEngineCommandChannel.emit(Event(EngineCommand.quit, 1));
                    break;
                case SDL_JOYAXISMOTION:
                    handleJoystickEvents && emitJoyAxisEvent(event);
                    break;
                case SDL_JOYBALLMOTION:
                    handleJoystickEvents && emitJoyBallMotionEvent(event);
                    break;
                case SDL_JOYHATMOTION:
                    handleJoystickEvents && emitJoyHatEvent(event);
                    break;
                case SDL_JOYBUTTONDOWN:
                case SDL_JOYBUTTONUP:
                    handleJoystickEvents && emitJoyButtonEvent(event);
                    break;
                case SDL_JOYDEVICEADDED:
                    if (handleJoystickEvents) {
                        inputDeviceManager.openJoystick(event.jdevice.which);
                        emitJoyDeviceAddedEvent(event);
                    }
                    break;
                case SDL_JOYDEVICEREMOVED:
                    if (handleJoystickEvents) {
                        inputDeviceManager.closeJoystick(event.jdevice.which);
                        emitJoyDeviceRemovedEvent(event);
                    }
                    break;
                case SDL_KEYDOWN:
                case SDL_KEYUP:
                    handleKeyboardEvents && emitKeyboardKeyEvent(event);
                    break;
                case SDL_MOUSEMOTION:
                    if (handleMouseEvents) {
                        handledMouseMotionEvent = true;
                        emitMouseMotionEvent(event);
                    }
                    break;
                case SDL_MOUSEBUTTONDOWN:
                case SDL_MOUSEBUTTONUP:
                    handleMouseEvents && emitMouseButtonEvent(event);
                    break;
                case SDL_MOUSEWHEEL:
                    handleMouseEvents && emitMouseWheelEvent(event);
                    break;
                default:
                    break;
            }
        }

        if (!handledMouseMotionEvent
            && previouslyHandledMouseMotionEvent
            && inputDeviceManager.captureMouse
            && inputDeviceManager.emitMouseMotionReset) {
            emitMouseMotionResetEvent();
        }
    }

    private void emitJoyAxisEvent(const ref SDL_Event event) {
        double magnitude = cast(double) event.jaxis.value / 32767;
        auto axisData = new JoystickAxisEventData();
        axisData.device = Device(DeviceType.joystick, cast(int) event.jaxis.which);
        axisData.axis = event.jaxis.axis;
        rawInputEventChannel.emit(Event(InputEvent.JOYSTICK_AXIS_MOVEMENT, magnitude, axisData));
    }

    private void emitJoyBallMotionEvent(const ref SDL_Event event) {
        auto xBallData = new JoystickBallEventData();
        auto yBallData = new JoystickBallEventData();
        xBallData.axis = JoystickBallAxis.X;
        yBallData.axis = JoystickBallAxis.Y;
        xBallData.device = Device(DeviceType.joystick, cast(int) event.jball.which);
        yBallData.device = Device(DeviceType.joystick, cast(int) event.jball.which);
        double xBallMagnitude = cast(double) event.jball.xrel / 32767;
        double yBallMagnitude = cast(double) event.jball.yrel / 32767;

        rawInputEventChannel.emit(Event(InputEvent.JOYSTICK_BALL_MOVEMENT, xBallMagnitude, xBallData));
        rawInputEventChannel.emit(Event(InputEvent.JOYSTICK_BALL_MOVEMENT, yBallMagnitude, yBallData));
    }

    private void emitJoyHatEvent(const ref SDL_Event event) {
        auto hatData = new JoystickHatEventData();
        hatData.device = Device(DeviceType.joystick, cast(int) event.jhat.which);
        hatData.hat = event.jhat.hat;
        hatData.postion = hatMap[event.jhat.value];
        rawInputEventChannel.emit(Event(InputEvent.JOYSTICK_HAT, 1, hatData));
    }

    private void emitJoyButtonEvent(const ref SDL_Event event) {
        auto buttonData = new JoystickButtonEventData();
        buttonData.device = Device(DeviceType.joystick, cast(int) event.jbutton.which);
        buttonData.button = event.jbutton.button;
        double magnitude = event.jbutton.state == SDL_PRESSED ? 1 : 0;
        rawInputEventChannel.emit(Event(InputEvent.JOYSTICK_BUTTON, magnitude, buttonData));
    }

    private void emitJoyDeviceAddedEvent(const ref SDL_Event event) {
        auto joystickData = new InputMessageData();
        joystickData.device = Device(DeviceType.joystick, cast(int) event.jdevice.which);
        rawInputEventChannel.emit(Event(InputEvent.JOYSTICK_ADDED, 1, joystickData));
    }

    private void emitJoyDeviceRemovedEvent(const ref SDL_Event event) {
        auto joystickData = new InputMessageData();
        joystickData.device = Device(DeviceType.joystick, cast(int) event.jdevice.which);
        rawInputEventChannel.emit(Event(InputEvent.JOYSTICK_REMOVED, 1, joystickData));
    }

    private void emitKeyboardKeyEvent(const ref SDL_Event event) {
        if (event.key.repeat == 0) {
            double magnitude = event.key.state == SDL_PRESSED ? 1 : 0;
            auto keyboardData = new KeyboardKeyEventData();
            keyboardData.device = Device(DeviceType.keyboard);
            keyboardData.scanCode = scanCodeMap[event.key.keysym.scancode];
            keyboardData.modifiers = createModifiers(event.key.keysym.mod);
            rawInputEventChannel.emit(Event(InputEvent.KEYBOARD_KEY, magnitude, keyboardData));
        }
    }

    private KeyboardKeyModifier createModifiers(ushort sdlModifiers) {
        auto modifiers = KeyboardKeyModifier.NONE;

        if (sdlModifiers & KMOD_LSHIFT) { modifiers |= KeyboardKeyModifier.LSHIFT; }
        if (sdlModifiers & KMOD_RSHIFT) { modifiers |= KeyboardKeyModifier.RSHIFT; }
        if (sdlModifiers & KMOD_LCTRL)  { modifiers |= KeyboardKeyModifier.LCTRL; }
        if (sdlModifiers & KMOD_RCTRL)  { modifiers |= KeyboardKeyModifier.RCTRL; }
        if (sdlModifiers & KMOD_LALT)   { modifiers |= KeyboardKeyModifier.LALT; }
        if (sdlModifiers & KMOD_RALT)   { modifiers |= KeyboardKeyModifier.RALT; }
        if (sdlModifiers & KMOD_LGUI)   { modifiers |= KeyboardKeyModifier.LGUI; }
        if (sdlModifiers & KMOD_RGUI)   { modifiers |= KeyboardKeyModifier.RGUI; }
        if (sdlModifiers & KMOD_NUM)    { modifiers |= KeyboardKeyModifier.NUM; }
        if (sdlModifiers & KMOD_CAPS)   { modifiers |= KeyboardKeyModifier.CAPS; }
        if (sdlModifiers & KMOD_MODE)   { modifiers |= KeyboardKeyModifier.MODE; }
        if (sdlModifiers & KMOD_CTRL)   { modifiers |= KeyboardKeyModifier.CTRL; }
        if (sdlModifiers & KMOD_SHIFT)  { modifiers |= KeyboardKeyModifier.SHIFT; }
        if (sdlModifiers & KMOD_ALT)    { modifiers |= KeyboardKeyModifier.ALT; }
        if (sdlModifiers & KMOD_GUI)    { modifiers |= KeyboardKeyModifier.GUI; }

        return modifiers;
    }

    private void emitMouseMotionEvent(const ref SDL_Event event) {
        auto xMouseMotionData = new MouseMotionEventData();
        xMouseMotionData.device = Device(DeviceType.mouse);
        double xMagnitude = (cast(double) event.motion.xrel / mouseMotionMax) * inputDeviceManager.mouseSensitivityModifier;
        xMouseMotionData.axis = MouseAxis.X;
        xMouseMotionData.absolutePosition = event.motion.x;

        auto yMouseMotionData = new MouseMotionEventData();
        yMouseMotionData.device = Device(DeviceType.mouse);
        double yMagnitude = (cast(double) event.motion.yrel / mouseMotionMax) * inputDeviceManager.mouseSensitivityModifier;
        yMouseMotionData.axis = MouseAxis.Y;
        yMouseMotionData.absolutePosition = event.motion.y;

        rawInputEventChannel.emit(Event(InputEvent.MOUSE_MOTION, xMagnitude, xMouseMotionData));
        rawInputEventChannel.emit(Event(InputEvent.MOUSE_MOTION, yMagnitude, yMouseMotionData));

        previouslyHandledMouseMotionEvent = true;
    }

    private void emitMouseMotionResetEvent() {
        auto xMouseMotionData = new MouseMotionEventData();
        xMouseMotionData.device = Device(DeviceType.mouse);
        xMouseMotionData.axis = MouseAxis.X;

        auto yMouseMotionData = new MouseMotionEventData();
        yMouseMotionData.device = Device(DeviceType.mouse);
        yMouseMotionData.axis = MouseAxis.Y;

        rawInputEventChannel.emit(Event(InputEvent.MOUSE_MOTION, 0, xMouseMotionData));
        rawInputEventChannel.emit(Event(InputEvent.MOUSE_MOTION, 0, yMouseMotionData));

        previouslyHandledMouseMotionEvent = false;
    }

    private void emitMouseButtonEvent(const ref SDL_Event event) {
        auto mouseButtonData = new MouseButtonEventData();
        mouseButtonData.device = Device(DeviceType.mouse);
        double magnitude = event.button.state == SDL_PRESSED ? 1 : 0;
        mouseButtonData.button = mouseButtonMap[event.button.button];

        rawInputEventChannel.emit(Event(InputEvent.MOUSE_BUTTON, magnitude, mouseButtonData));
    }

    private void emitMouseWheelEvent(const ref SDL_Event event) {
        double magnitude = event.wheel.y;

        if (event.wheel.direction == SDL_MOUSEWHEEL_FLIPPED) {
            magnitude *= -1;
        }

        auto mouseWheelEventData = new InputMessageData();
        mouseWheelEventData.device = Device(DeviceType.mouse);

        rawInputEventChannel.emit(Event(InputEvent.MOUSE_WHEEL, magnitude, mouseWheelEventData));
    }
}

} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict SDL2. Please add it as dependency to your project.");    
    }
}
