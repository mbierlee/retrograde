/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2022 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.input;

import std.typecons : Nullable, nullable;

import retrograde.core.stringid : StringId, sid;
import retrograde.core.messaging : Message, MessageHandler, MagnitudeMessage;
import retrograde.core.algorithm : forEach;

/** 
 * Used by the InputMapper to capture HID input and map them to different channels.
 */
const auto inputEventChannel = sid("input_event_channel");

/**
 * An input event of any kind.
 */
abstract class InputEventMessage : MagnitudeMessage {
    this(const StringId id, const double magnitude) {
        super(id, magnitude);
    }
}

/**
 * An input event generated after pressing, holding or releasing a keyboard key.
 */
class KeyInputEventMessage : InputEventMessage {
    static const StringId msgId = sid("ev_key_input");

    int scanCode;
    KeyboardKeyCode keyCode;
    InputEventAction action;
    KeyboardKeyModifier modifiers;

    /**
     * Params:
     *  scanCode = Platform-specific keyboard scan code.
     *  keyCode = Literal keyboard key code.
     *  action = Button press action.
     *  modifiers = Modifier keys (shift, ctrl, etc.) held while the primary key was pressed.
     *  magnitude = Amount of pressure applied. Since keyboards are digital, this is either 0.0 or 1.0.
     */
    this(const int scanCode, const KeyboardKeyCode keyCode, const InputEventAction action,
        const KeyboardKeyModifier modifiers, const double magnitude) {
        super(msgId, magnitude);
        this.scanCode = scanCode;
        this.keyCode = keyCode;
        this.action = action;
        this.modifiers = modifiers;
    }

    /**
     * Creates a new immutable KeyInputEventMessage.
     *
     * Params:
     *  scanCode = Platform-specific keyboard scan code.
     *  keyCode = Literal keyboard key code.
     *  action = Button press action.
     *  modifiers = Modifier keys (shift, ctrl, etc.) held while the primary key was pressed.
     *  magnitude = Amount of pressure applied. Since keyboards are digital, this is either 0.0 or 1.0.
     */
    static immutable(KeyInputEventMessage) create(const int scanCode, const KeyboardKeyCode keyCode,
        const InputEventAction action, const KeyboardKeyModifier modifiers,
        const double magnitude) {
        return cast(immutable(KeyInputEventMessage)) new KeyInputEventMessage(scanCode,
            keyCode, action, modifiers, magnitude);
    }
}

/**
 * An event emitted when the mouse is moved.
 *
 * Depending on the platform and its configuration, this position may be absolute or relative. 
 * It may be that of the mouse over the window or the whole desktop.
 * Refer to the platform in use for specifics.
 */
class MouseMovementEventMessage : InputEventMessage {
    static const StringId msgId = sid("ev_mouse_movement");

    double xPosition;
    double yPosition;
    Axis axis;
    MouseMovementType movementType;

    /**
     * Params:
     *  xPosition = X position of the mouse in the platform's drawing space (window).
     *  yPosition = Y position of the mouse in the platform's drawing space (window).
     *  axis = Which axis is being reported. The other axis may stay 0 depending on this setting.
     *  movementType = Type of mouse movement (absolute/relative.)
     *  magnitude = Amount of movement in two-dimensions.
     */
    this(const double xPosition, const double yPosition, const Axis axis,
        const MouseMovementType movementType, const double magnitude) {
        super(msgId, magnitude);
        this.xPosition = xPosition;
        this.yPosition = yPosition;
        this.axis = axis;
        this.movementType = movementType;
    }

    /**
     * Creates a new immutable MouseMovementEventMessage.
     *
     * Params:
     *  xPosition = X position of the mouse in the platform's drawing space (window).
     *  yPosition = Y position of the mouse in the platform's drawing space (window).
     *  axis = Which axis is being reported. The other axis may stay 0 depending on this setting.
     *  movementType = Type of mouse movement (absolute/relative.)
     *  magnitude = Amount of movement in two-dimensions.
     */
    static immutable(MouseMovementEventMessage) create(const double xPosition, const double yPosition,
        const Axis axis, const MouseMovementType movementType, const double magnitude) {
        return cast(immutable(MouseMovementEventMessage)) new MouseMovementEventMessage(xPosition,
            yPosition, axis, movementType, magnitude);
    }
}

/**
 * An event emitted when the mouse enters or leaves a platform's drawing space (window).
 */
class MouseEnteredEventMessage : InputEventMessage {
    static const StringId msgId = sid("ev_mouse_entered");

    bool entered;

    this(const bool entered) {
        super(msgId, 1.0);
        this.entered = entered;
    }

    /**
     * Creates a new immutable MouseEnteredEventMessage.
     *
     * Params:
     *  entered = true if the mouse entered the drawing space (window), false if it left.
     */
    static immutable(MouseEnteredEventMessage) create(const bool entered) {
        return cast(immutable(MouseEnteredEventMessage)) new MouseEnteredEventMessage(entered);
    }
}

/**
 * An input event generated after pressing or releasing a mouse button.
 */
class MouseButtonInputEventMessage : InputEventMessage {
    static const StringId msgId = sid("ev_mouse_button_input");

    MouseButton mouseButton;
    InputEventAction action;
    KeyboardKeyModifier modifiers;

    /**
     * Params:
     *  mouseButton = Mouse button pressed.
     *  action = Button press action.
     *  modifiers = Modifier keys (shift, ctrl, etc.) held while the primary key was pressed.
     *  magnitude = Amount of pressure applied. Since keyboards are digital, this is either 0.0 or 1.0.
     */
    this(const MouseButton mouseButton, const InputEventAction action,
        const KeyboardKeyModifier modifiers, const double magnitude) {
        super(msgId, magnitude);
        this.mouseButton = mouseButton;
        this.action = action;
        this.modifiers = modifiers;
    }

    /**
     * Creates a new immutable MouseButtonInputEventMessage.
     *
     * Params:
     *  mouseButton = Mouse button pressed.
     *  action = Button press action.
     *  modifiers = Modifier keys (shift, ctrl, etc.) held while the primary key was pressed.
     *  magnitude = Amount of pressure applied. Since keyboards are digital, this is either 0.0 or 1.0.
     */
    static immutable(MouseButtonInputEventMessage) create(const MouseButton mouseButton,
        const InputEventAction action, const KeyboardKeyModifier modifiers,
        const double magnitude) {
        return cast(immutable(MouseButtonInputEventMessage)) new MouseButtonInputEventMessage(mouseButton,
            action, modifiers, magnitude);
    }
}

/**
 * An input event generated scrolling a one or two-dimensional mousewheel.
 */
class MouseScrollInputEventMessage : InputEventMessage {
    static const StringId msgId = sid("ev_mouse_scroll");

    double xOffset;
    double yOffset;

    /**
     * Params:
     *  xOffset = Amount of scrollage on the X-axis.
     *  yOffset = Amount of scrollage on the Y-axis.
     *  magnitude = Amount of scroll in two-dimensions.
     */
    this(const double xOffset, double yOffset, const double magnitude) {
        super(msgId, magnitude);
        this.xOffset = xOffset;
        this.yOffset = yOffset;
    }

    /**
     * Creates a new immutable MouseScrollInputEventMessage.
     * 
     * Params:
     *  xOffset = Amount of scrollage on the X-axis.
     *  yOffset = Amount of scrollage on the Y-axis.
     *  magnitude = Amount of scroll in two-dimensions.
     */
    static immutable(MouseScrollInputEventMessage) create(const double xOffset,
        double yOffset, const double magnitude) {
        return cast(immutable(MouseScrollInputEventMessage)) new MouseScrollInputEventMessage(xOffset,
            yOffset, magnitude);
    }
}

/**
 * A character input event coming from (virtual) keyboard input.
 */
class CharacterInputEventMessage : InputEventMessage {
    static const StringId msgId = sid("ev_char_input");

    dchar character;

    /**
     * Params:
     *  character = Unicode character
     */
    this(const dchar character) {
        super(msgId, 1.0);
        this.character = character;
    }

    /**
     * Creates a new immutable CharacterInputEventMessage.
     *
     * Params:
     *  character = Unicode character
     */
    static immutable(CharacterInputEventMessage) create(const dchar character) {
        return cast(immutable(CharacterInputEventMessage)) new CharacterInputEventMessage(character);
    }
}

/**
 * Mouse mode for desktop platforms.
 */
enum MouseMode {
    // Shows the mouse on-screen.
    normal,

    // Hides the mouse, but does not lock it to the window.
    hidden,

    // Hides the mouse and locks it to the window.
    disabled
}

/**
 * Type of mouse movement.
 *
 * It depends on the platform whether one or the other is available.
 */
enum MouseMovementType {
    // Absolute X/Y movement over the screen/desktop
    absolute,

    // Relative movement to the previous mouse movement event (delta movement.)
    relative
}

/**
 * Input axis definition for multi-axis control input, such as joysticks or mouse-movement.
 */
enum Axis {
    x,
    y,
    z,
    both
}

/**
 * An abstract representation of a mapping key.
 *
 * The event name should be a generic name of an input event type.
 * The components are typically buttons or other such control inputs.
 */
struct MappingKey {
    const StringId eventName;
    immutable Nullable!int componentOne;
    immutable Nullable!int componentTwo;
    immutable Nullable!int componentThree;
}

/**
 * Target properties of an event mapping.
 */
struct MappingTarget {
    StringId channel;
    StringId messageId;
}

/**
 * Maps input events into other events or actions.
 *
 * The input mapper is typically used to map key input into concrete actions, such as Key W -> Walk Forward.
 * The input event's magnitude is preserved unless modified, making it perfect for mapping both digital and analog input.
 */
class InputMapper {
    private MappingTarget[MappingKey] mappings;
    private MessageHandler messageHandler;

    this(MessageHandler messageHandler) {
        this.messageHandler = messageHandler;
    }

    /**
     * Add a generic type of mapping.
     *
     * Params:
     *  mappingKey = Mapping key describing the input event.
     *  mappingTarget = Target properties of the mapping.
     */
    void addMapping(MappingKey mappingKey, MappingTarget mappingTarget) {
        mappings[mappingKey] = mappingTarget;
    }

    /**
     * Add a keyboard key mapping.
     *
     * Mapping is added on InputEventActions.press and InputEventActions.release only,
     * not InputEventActions.repeat. Use one of the overloads to also map on repeat.
     * 
     * Params:
     *  keyCode = Key code to map from.
     *  mappingTarget = Target properties of the mapping.
     */
    void addKeyMapping(KeyboardKeyCode keyCode, MappingTarget mappingTarget) {
        addKeyMapping(
            keyCode,
            [
                InputEventAction.press,
                InputEventAction.release
            ],
            mappingTarget
        );
    }

    /**
     * Add a keyboard key mapping.
     * 
     * Params:
     *  keyCode = Key code to map from.
     *  action = Input action to map.
     *  mappingTarget = Target properties of the mapping.
     */
    void addKeyMapping(KeyboardKeyCode keyCode, InputEventAction action, MappingTarget mappingTarget) {
        addMapping(MappingKey(KeyInputEventMessage.msgId, (cast(int) keyCode)
                .nullable, (cast(int) action).nullable), mappingTarget);
    }

    /**
     * Add a keyboard key mapping.
     * 
     * Params:
     *  keyCode = Key code to map from.
     *  actions = Input actions to map.
     *  mappingTarget = Target properties of the mapping.
     */
    void addKeyMapping(KeyboardKeyCode keyCode, InputEventAction[] actions, MappingTarget mappingTarget) {
        actions.forEach((InputEventAction action) {
            addMapping(MappingKey(KeyInputEventMessage.msgId, (cast(int) keyCode)
                .nullable, (cast(int) action).nullable), mappingTarget);
        });
    }

    /**
     * Clears all currently bound mappings.
     */
    void clearMappings() {
        mappings.destroy();
    }

    /**
     * Process all input events and map them to corresponding messages.
     */
    void update() {
        messageHandler.receiveMessages(inputEventChannel, (immutable Message message) {
            if (message.id == KeyInputEventMessage.msgId) {
                auto keyInputMessage = cast(KeyInputEventMessage) message;
                if (keyInputMessage) {
                    auto key = MappingKey(message.id, (cast(int) keyInputMessage.keyCode)
                        .nullable, (cast(int) keyInputMessage.action).nullable);
                    auto mapping = key in mappings;
                    if (mapping) {
                        messageHandler.sendMessage(mapping.channel,
                            MagnitudeMessage.create(mapping.messageId, keyInputMessage.magnitude));
                    }
                }
            }
        });
    }
}

// InputMapper tests
version (unittest) {
    import std.math.operations : isClose;

    @("Add mapping")
    unittest {
        auto mapper = new InputMapper(null);
        mapper.addMapping(MappingKey(KeyInputEventMessage.msgId, (cast(int) KeyboardKeyCode.e)
                .nullable), MappingTarget(sid("test_channel"), sid("cmd_rejoice")));

        mapper.addKeyMapping(KeyboardKeyCode.b, MappingTarget(sid("test_channel"), sid(
                "cmd_buckle_up")));
    }

    @("Process KeyInputEventMessage mapping")
    unittest {
        auto expectedChannel = sid("test");
        auto expectedMessageId = sid("b");

        auto messageHandler = new MessageHandler();
        auto mapper = new InputMapper(messageHandler);
        mapper.addKeyMapping(KeyboardKeyCode.a, MappingTarget(expectedChannel, expectedMessageId));

        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.press, KeyboardKeyModifier.none, 0.6));
        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.repeat, KeyboardKeyModifier.none, 0.4));
        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.release, KeyboardKeyModifier.none, 0));

        messageHandler.shiftStandbyToActiveQueue();
        mapper.update();
        messageHandler.shiftStandbyToActiveQueue();

        int receivedMessages = 0;
        bool expectedPressMessageReceived = false;
        bool unexpectedRepeatMessageReceived = false;
        bool expectedReleaseMessageReceived = false;
        messageHandler.receiveMessages(expectedChannel, (immutable Message message) {
            auto magnitudeMessage = cast(MagnitudeMessage) message;
            if (magnitudeMessage) {
                receivedMessages += 1;
                expectedPressMessageReceived = expectedPressMessageReceived ||
                    (magnitudeMessage.id == expectedMessageId && isClose(magnitudeMessage.magnitude, 0.6));
                unexpectedRepeatMessageReceived = unexpectedRepeatMessageReceived ||
                    (magnitudeMessage.id == expectedMessageId && isClose(magnitudeMessage.magnitude, 0.4));
                expectedReleaseMessageReceived = expectedReleaseMessageReceived ||
                    (magnitudeMessage.id == expectedMessageId && isClose(magnitudeMessage.magnitude, 0));

            }
        });

        assert(expectedPressMessageReceived);
        assert(!unexpectedRepeatMessageReceived);
        assert(expectedReleaseMessageReceived);
        assert(receivedMessages == 2);
    }

    @(
        "Only process KeyInputEventMessage mapping of certain InputEventActions when mapping one action")
    unittest {
        auto expectedChannel = sid("test");
        auto expectedMessageId = sid("b");

        auto messageHandler = new MessageHandler();
        auto mapper = new InputMapper(messageHandler);
        mapper.addKeyMapping(KeyboardKeyCode.a, InputEventAction.press, MappingTarget(expectedChannel, expectedMessageId));

        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.press, KeyboardKeyModifier.none, 0.6));
        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.repeat, KeyboardKeyModifier.none, 0.4));
        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.release, KeyboardKeyModifier.none, 0));

        messageHandler.shiftStandbyToActiveQueue();
        mapper.update();
        messageHandler.shiftStandbyToActiveQueue();

        int receivedMessages = 0;
        bool expectedMessageReceived = false;
        messageHandler.receiveMessages(expectedChannel, (immutable Message message) {
            auto magnitudeMessage = cast(MagnitudeMessage) message;
            if (magnitudeMessage) {
                receivedMessages += 1;
                expectedMessageReceived = magnitudeMessage.id == expectedMessageId &&
                    isClose(magnitudeMessage.magnitude, 0.6);
            }
        });

        assert(expectedMessageReceived);
        assert(receivedMessages == 1);
    }

    @(
        "Only process KeyInputEventMessage mapping of certain InputEventActions when mapping multiple actions")
    unittest {
        auto expectedChannel = sid("test");
        auto expectedMessageId = sid("b");

        auto messageHandler = new MessageHandler();
        auto mapper = new InputMapper(messageHandler);
        mapper.addKeyMapping(KeyboardKeyCode.a, [
                InputEventAction.press, InputEventAction.release
            ], MappingTarget(expectedChannel, expectedMessageId));

        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.press, KeyboardKeyModifier.none, 0.6));
        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.repeat, KeyboardKeyModifier.none, 0.4));
        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.release, KeyboardKeyModifier.none, 0));

        messageHandler.shiftStandbyToActiveQueue();
        mapper.update();
        messageHandler.shiftStandbyToActiveQueue();

        int receivedMessages = 0;
        bool expectedPressMessageReceived = false;
        bool unexpectedRepeatMessageReceived = false;
        bool expectedReleaseMessageReceived = false;
        messageHandler.receiveMessages(expectedChannel, (immutable Message message) {
            auto magnitudeMessage = cast(MagnitudeMessage) message;
            if (magnitudeMessage) {
                receivedMessages += 1;
                expectedPressMessageReceived = expectedPressMessageReceived ||
                    (magnitudeMessage.id == expectedMessageId && isClose(magnitudeMessage.magnitude, 0.6));
                unexpectedRepeatMessageReceived = unexpectedRepeatMessageReceived ||
                    (magnitudeMessage.id == expectedMessageId && isClose(magnitudeMessage.magnitude, 0.4));
                expectedReleaseMessageReceived = expectedReleaseMessageReceived ||
                    (magnitudeMessage.id == expectedMessageId && isClose(magnitudeMessage.magnitude, 0));
            }
        });

        assert(expectedPressMessageReceived);
        assert(!unexpectedRepeatMessageReceived);
        assert(expectedReleaseMessageReceived);
        assert(receivedMessages == 2);
    }

    @("Clear mapping")
    unittest {
        auto expectedChannel = sid("test");
        auto expectedMessageId = sid("b");

        auto messageHandler = new MessageHandler();
        auto mapper = new InputMapper(messageHandler);
        mapper.addKeyMapping(KeyboardKeyCode.a, MappingTarget(expectedChannel, expectedMessageId));

        messageHandler.sendMessage(inputEventChannel, KeyInputEventMessage.create(123,
                KeyboardKeyCode.a, InputEventAction.press, KeyboardKeyModifier.none, 0.6));

        messageHandler.shiftStandbyToActiveQueue();
        mapper.clearMappings();
        mapper.update();
        messageHandler.shiftStandbyToActiveQueue();

        bool messageReceived = false;
        messageHandler.receiveMessages(expectedChannel, (immutable Message message) {
            messageReceived = message && message.id == expectedMessageId;
        });

        assert(!messageReceived);
    }
}

/**
 * Available keyboard codes for keyboard-input.
 * This list is based off of SDL2's key code list.
 * Not all platforms may map all of them.
 */
enum KeyboardKeyCode {
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
    unknown,
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
 * Available mouse buttons.
 *
 * These weird-ass gamer mice with a million buttons are probably not fully supported by the platform API.
 */
enum MouseButton {
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
    unknown
}

/**
 * Types of action that can be performed on an input event,
 * such as pressing a keyboard button or releasing a gamepad button.
 */
enum InputEventAction {
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
