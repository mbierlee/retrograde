/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.platform.glfw;

version (Have_glfw_d)
{
    import std.experimental.logger : Logger;
    import std.string : toStringz;
    import std.conv : to;

    import glfw3.api;

    import poodinis;

    import retrograde.core.platform : Platform, PlatformSettings;
    import retrograde.core.runtime : EngineRuntime;
    import retrograde.core.collections : Queue;
    import retrograde.core.input : KeyboardKeyCode, InputEventAction, KeyboardKeyModifier, KeyInputEventMessage,
        CharacterInputEventMessage, AbsoluteMouseMovementEventMessage, inputEventChannel;
    import retrograde.core.messaging : MessageHandler;

    private struct GlfwKeyEvent
    {
        int key;
        int scanCode;
        int action;
        int modifiers;
    }

    private struct GlfwMouseMovementEvent
    {
        double xPosition;
        double yPosition;
    }

    private struct StateData
    {
        Queue!GlfwKeyEvent keyEvents;
        Queue!dchar charEvents;
        Queue!GlfwMouseMovementEvent mouseMovementEvents;
    }

    class GlfwPlatformSettings : PlatformSettings
    {
        int windowWidth = 1920;
        int windowHeight = 1080;
        string windowTitle = "Retrograde Engine";
        int swapInterval = 1;

        bool enableKeyInputEvents = true;
        bool enableCharacterInputEvents = true;
        bool enableMouseInputEvents = true;
    }

    /**
    * A GLFW-based platform for Desktop OSes.
    * To use, dependency glfw-d must be included in your project's dub project.
    */
    class GlfwPlatform : Platform
    {
        private @Autowire EngineRuntime runtime;
        private @Autowire Logger logger;
        private @Autowire MessageHandler messageHandler;

        private GLFWwindow* window;
        private StateData stateData;
        private const KeyboardKeyCode[int] glfwKeyMap;
        private const InputEventAction[int] glfwActionMap;

        this()
        {
            glfwKeyMap = [
        GLFW_KEY_UNKNOWN: KeyboardKeyCode.unknown,
        GLFW_KEY_SPACE:
                KeyboardKeyCode.space,
        GLFW_KEY_APOSTROPHE:
                KeyboardKeyCode.apostrophe,
        GLFW_KEY_COMMA:
                KeyboardKeyCode.comma,
        GLFW_KEY_MINUS:
                KeyboardKeyCode.minus,
        GLFW_KEY_PERIOD:
                KeyboardKeyCode.period,
        GLFW_KEY_SLASH:
                KeyboardKeyCode.slash,
        GLFW_KEY_0:
                KeyboardKeyCode.zero,
        GLFW_KEY_1:
                KeyboardKeyCode.one,
        GLFW_KEY_2:
                KeyboardKeyCode.two,
        GLFW_KEY_3:
                KeyboardKeyCode.three,
        GLFW_KEY_4:
                KeyboardKeyCode.four,
        GLFW_KEY_5:
                KeyboardKeyCode.five,
        GLFW_KEY_6:
                KeyboardKeyCode.six,
        GLFW_KEY_7:
                KeyboardKeyCode.seven,
        GLFW_KEY_8:
                KeyboardKeyCode.eight,
        GLFW_KEY_9:
                KeyboardKeyCode.nine,
        GLFW_KEY_SEMICOLON:
                KeyboardKeyCode.semicolon,
        GLFW_KEY_EQUAL:
                KeyboardKeyCode.equals,
        GLFW_KEY_A:
                KeyboardKeyCode.a,
        GLFW_KEY_B:
                KeyboardKeyCode.b,
        GLFW_KEY_C:
                KeyboardKeyCode.c,
        GLFW_KEY_D:
                KeyboardKeyCode.d,
        GLFW_KEY_E:
                KeyboardKeyCode.e,
        GLFW_KEY_F:
                KeyboardKeyCode.f,
        GLFW_KEY_G:
                KeyboardKeyCode.g,
        GLFW_KEY_H:
                KeyboardKeyCode.h,
        GLFW_KEY_I:
                KeyboardKeyCode.i,
        GLFW_KEY_J:
                KeyboardKeyCode.j,
        GLFW_KEY_K:
                KeyboardKeyCode.k,
        GLFW_KEY_L:
                KeyboardKeyCode.l,
        GLFW_KEY_M:
                KeyboardKeyCode.m,
        GLFW_KEY_N:
                KeyboardKeyCode.n,
        GLFW_KEY_O:
                KeyboardKeyCode.o,
        GLFW_KEY_P:
                KeyboardKeyCode.p,
        GLFW_KEY_Q:
                KeyboardKeyCode.q,
        GLFW_KEY_R:
                KeyboardKeyCode.r,
        GLFW_KEY_S:
                KeyboardKeyCode.s,
        GLFW_KEY_T:
                KeyboardKeyCode.t,
        GLFW_KEY_U:
                KeyboardKeyCode.u,
        GLFW_KEY_V:
                KeyboardKeyCode.v,
        GLFW_KEY_W:
                KeyboardKeyCode.w,
        GLFW_KEY_X:
                KeyboardKeyCode.x,
        GLFW_KEY_Y:
                KeyboardKeyCode.y,
        GLFW_KEY_Z:
                KeyboardKeyCode.z,
        GLFW_KEY_LEFT_BRACKET:
                KeyboardKeyCode.leftBracket,
        GLFW_KEY_BACKSLASH:
                KeyboardKeyCode.backslash,
        GLFW_KEY_RIGHT_BRACKET:
                KeyboardKeyCode.rightBracket,
        GLFW_KEY_GRAVE_ACCENT:
                KeyboardKeyCode.grave,
        GLFW_KEY_WORLD_1:
                KeyboardKeyCode.international1,
        GLFW_KEY_WORLD_2:
                KeyboardKeyCode.international2,
        GLFW_KEY_ESCAPE:
                KeyboardKeyCode.escape,
        GLFW_KEY_ENTER:
                KeyboardKeyCode.enter,
        GLFW_KEY_TAB:
                KeyboardKeyCode.tab,
        GLFW_KEY_BACKSPACE:
                KeyboardKeyCode.backspace,
        GLFW_KEY_INSERT:
                KeyboardKeyCode.insert,
        GLFW_KEY_DELETE:
                KeyboardKeyCode.deleteKey,
        GLFW_KEY_RIGHT:
                KeyboardKeyCode.right,
        GLFW_KEY_LEFT:
                KeyboardKeyCode.left,
        GLFW_KEY_DOWN:
                KeyboardKeyCode.down,
        GLFW_KEY_UP:
                KeyboardKeyCode.up,
        GLFW_KEY_PAGE_UP:
                KeyboardKeyCode.pageUp,
        GLFW_KEY_PAGE_DOWN:
                KeyboardKeyCode.pageDown,
        GLFW_KEY_HOME:
                KeyboardKeyCode.home,
        GLFW_KEY_END:
                KeyboardKeyCode.end,
        GLFW_KEY_CAPS_LOCK:
                KeyboardKeyCode.capslock,
        GLFW_KEY_SCROLL_LOCK:
                KeyboardKeyCode.scrolllock,
        GLFW_KEY_NUM_LOCK:
                KeyboardKeyCode.numlockClear,
        GLFW_KEY_PRINT_SCREEN:
                KeyboardKeyCode.printscreen,
        GLFW_KEY_PAUSE:
                KeyboardKeyCode.pause,
        GLFW_KEY_F1:
                KeyboardKeyCode.f1,
        GLFW_KEY_F2:
                KeyboardKeyCode.f2,
        GLFW_KEY_F3:
                KeyboardKeyCode.f3,
        GLFW_KEY_F4:
                KeyboardKeyCode.f4,
        GLFW_KEY_F5:
                KeyboardKeyCode.f5,
        GLFW_KEY_F6:
                KeyboardKeyCode.f6,
        GLFW_KEY_F7:
                KeyboardKeyCode.f7,
        GLFW_KEY_F8:
                KeyboardKeyCode.f8,
        GLFW_KEY_F9:
                KeyboardKeyCode.f9,
        GLFW_KEY_F10:
                KeyboardKeyCode.f10,
        GLFW_KEY_F11:
                KeyboardKeyCode.f11,
        GLFW_KEY_F12:
                KeyboardKeyCode.f12,
        GLFW_KEY_F13:
                KeyboardKeyCode.f13,
        GLFW_KEY_F14:
                KeyboardKeyCode.f14,
        GLFW_KEY_F15:
                KeyboardKeyCode.f15,
        GLFW_KEY_F16:
                KeyboardKeyCode.f16,
        GLFW_KEY_F17:
                KeyboardKeyCode.f17,
        GLFW_KEY_F18:
                KeyboardKeyCode.f18,
        GLFW_KEY_F19:
                KeyboardKeyCode.f19,
        GLFW_KEY_F20:
                KeyboardKeyCode.f20,
        GLFW_KEY_F21:
                KeyboardKeyCode.f21,
        GLFW_KEY_F22:
                KeyboardKeyCode.f22,
        GLFW_KEY_F23:
                KeyboardKeyCode.f23,
        GLFW_KEY_F24:
                KeyboardKeyCode.f24,
        GLFW_KEY_F25:
                KeyboardKeyCode.f25,
        GLFW_KEY_KP_0:
                KeyboardKeyCode.keypadZero,
        GLFW_KEY_KP_1:
                KeyboardKeyCode.keypadOne,
        GLFW_KEY_KP_2:
                KeyboardKeyCode.keypadTwo,
        GLFW_KEY_KP_3:
                KeyboardKeyCode.keypadThree,
        GLFW_KEY_KP_4:
                KeyboardKeyCode.keypadFour,
        GLFW_KEY_KP_5:
                KeyboardKeyCode.keypadFive,
        GLFW_KEY_KP_6:
                KeyboardKeyCode.keypadSix,
        GLFW_KEY_KP_7:
                KeyboardKeyCode.keypadSeven,
        GLFW_KEY_KP_8:
                KeyboardKeyCode.keypadEight,
        GLFW_KEY_KP_9:
                KeyboardKeyCode.keypadNine,
        GLFW_KEY_KP_DECIMAL:
                KeyboardKeyCode.keypadPeriod,
        GLFW_KEY_KP_DIVIDE:
                KeyboardKeyCode.keypadDivide,
        GLFW_KEY_KP_MULTIPLY:
                KeyboardKeyCode.keypadMultiply,
        GLFW_KEY_KP_SUBTRACT:
                KeyboardKeyCode.keypadMinus,
        GLFW_KEY_KP_ADD:
                KeyboardKeyCode.keypadPlus,
        GLFW_KEY_KP_ENTER:
                KeyboardKeyCode.keypadEnter,
        GLFW_KEY_KP_EQUAL:
                KeyboardKeyCode.keypadEquals,
        GLFW_KEY_LEFT_SHIFT:
                KeyboardKeyCode.leftShift,
        GLFW_KEY_LEFT_CONTROL:
                KeyboardKeyCode.leftCtrl,
        GLFW_KEY_LEFT_ALT:
                KeyboardKeyCode.leftAlt,
        GLFW_KEY_LEFT_SUPER:
                KeyboardKeyCode.leftGui,
        GLFW_KEY_RIGHT_SHIFT:
                KeyboardKeyCode.rightShift,
        GLFW_KEY_RIGHT_CONTROL:
                KeyboardKeyCode.rightCtrl,
        GLFW_KEY_RIGHT_ALT:
                KeyboardKeyCode.rightAlt,
        GLFW_KEY_RIGHT_SUPER:
                KeyboardKeyCode.rightGui,
        GLFW_KEY_MENU:
                KeyboardKeyCode.menu
            ];

            glfwActionMap = [
        GLFW_RELEASE: InputEventAction.release,
        GLFW_PRESS:
                InputEventAction.press,
        GLFW_REPEAT:
                InputEventAction.repeat
            ];
        }

        void initialize(const PlatformSettings platformSettings)
        {
            auto ps = cast(const(GlfwPlatformSettings)) platformSettings;
            if (!ps)
            {
                logger.error("GLFW Platform: Unable to use platformSettings. Did you supply settings of type GlfwPlatformSettings?");
                return;
            }

            glfwSetErrorCallback(&errorCallback); //TODO: Move to update and use glfwGetError so we can use own logger

            if (!glfwInit())
            {
                logger.error("GLFW Platform: Failed to initialize.");
                return;
            }

            glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
            glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);

            window = glfwCreateWindow(ps.windowWidth, ps.windowHeight,
                    ps.windowTitle.toStringz(), null, null);

            if (!window)
            {
                glfwTerminate();
                logger.error("GLFW Platform: Failed to create window.");
                return;
            }

            glfwSetWindowUserPointer(window, &stateData);

            if (ps.enableKeyInputEvents)
            {
                glfwSetKeyCallback(window, &keyCallback);
            }

            if (ps.enableCharacterInputEvents)
            {
                glfwSetCharCallback(window, &characterCallback);
            }

            if (ps.enableMouseInputEvents)
            {
                glfwSetCursorPosCallback(window, &mouseCursorPositionCallback);
            }

            glfwMakeContextCurrent(window);
            glfwSwapInterval(ps.swapInterval);
        }

        void update()
        {
            if (glfwWindowShouldClose(window))
            {
                runtime.terminate();
            }
            else if (window)
            {
                glfwSwapBuffers(window);
                glfwPollEvents();
                processPolledEvents();
            }
        }

        void terminate()
        {
            if (window)
            {
                glfwDestroyWindow(window);
            }

            glfwTerminate();
        }

        private void processPolledEvents()
        {
            processKeyEvents();
            processCharacterEvents();
            processMouseMovementEvents();
        }

        private void processKeyEvents()
        {
            while (stateData.keyEvents.length > 0)
            {
                auto keyEvent = stateData.keyEvents.deQueue();

                const double magnitude = (keyEvent.action == GLFW_RELEASE) ? 0 : 1;

                auto message = KeyInputEventMessage.create(keyEvent.scanCode,
                        glfwKeyMap[keyEvent.key], glfwActionMap[keyEvent.action],
                        getRetrogradeKeyboardModifiers(keyEvent.modifiers), magnitude);

                messageHandler.sendMessage(inputEventChannel, message);
            }
        }

        private void processCharacterEvents()
        {
            while (stateData.charEvents.length > 0)
            {
                auto character = stateData.charEvents.deQueue();
                auto message = CharacterInputEventMessage.create(character);
                messageHandler.sendMessage(inputEventChannel, message);
            }
        }

        private void processMouseMovementEvents()
        {
            while (stateData.mouseMovementEvents.length > 0)
            {
                auto event = stateData.mouseMovementEvents.deQueue();
                auto message = AbsoluteMouseMovementEventMessage.create(event.xPosition,
                        event.yPosition);
                messageHandler.sendMessage(inputEventChannel, message);
            }
        }

        private KeyboardKeyModifier getRetrogradeKeyboardModifiers(int glfwModifiers)
        {
            auto modifiers = KeyboardKeyModifier.none;

            if (glfwModifiers & GLFW_MOD_SHIFT)
            {
                modifiers |= KeyboardKeyModifier.shift;
            }

            if (glfwModifiers & GLFW_MOD_CONTROL)
            {
                modifiers |= KeyboardKeyModifier.leftCtrl;
                modifiers |= KeyboardKeyModifier.rightCtrl;
            }

            if (glfwModifiers & GLFW_MOD_ALT)
            {
                modifiers |= KeyboardKeyModifier.leftAlt;
                modifiers |= KeyboardKeyModifier.rightAlt;
            }

            if (glfwModifiers & GLFW_MOD_SUPER)
            {
                modifiers |= KeyboardKeyModifier.leftGui;
                modifiers |= KeyboardKeyModifier.rightGui;
            }

            if (glfwModifiers & GLFW_MOD_CAPS_LOCK)
            {
                modifiers |= KeyboardKeyModifier.capslock;
            }

            if (glfwModifiers & GLFW_MOD_NUM_LOCK)
            {
                modifiers |= KeyboardKeyModifier.numlock;
            }

            return modifiers;
        }
    }

    private extern (C) void errorCallback(int error, const(char)* description) nothrow @nogc
    {
        debug
        {
            // Due to @nogc we cannot make use of the engine's logger
            import core.stdc.stdio;

            auto errorCode = toStringz(to!string(error));
            fprintf(stderr, "GLFW Platform Error %s: %s\n", errorCode, description);
        }
    }

    private extern (C) void keyCallback(GLFWwindow* window, int key,
            int scanCode, int action, int modifiers) @nogc nothrow
    {
        StateData* state = cast(StateData*) glfwGetWindowUserPointer(window);
        assert(state);

        state.keyEvents.enQueue(GlfwKeyEvent(key, scanCode, action, modifiers));
    }

    private extern (C) void characterCallback(GLFWwindow* window, uint codepoint) @nogc nothrow
    {
        StateData* state = cast(StateData*) glfwGetWindowUserPointer(window);
        assert(state);

        state.charEvents.enQueue(codepoint);
    }

    private extern (C) void mouseCursorPositionCallback(GLFWwindow* window,
            double xPosition, double yPosition) @nogc nothrow
    {
        StateData* state = cast(StateData*) glfwGetWindowUserPointer(window);
        assert(state);

        state.mouseMovementEvents.enQueue(GlfwMouseMovementEvent(xPosition, yPosition));
    }
}
