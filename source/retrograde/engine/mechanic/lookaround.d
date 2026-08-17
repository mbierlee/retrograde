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

module retrograde.engine.mechanic.lookaround;

import retrograde.engine.entity : addEntityProcessor, EntityId, getComponentData,
    withComponentData;
import retrograde.engine.event : Event, eventHandlers, Magnitude;
import retrograde.engine.input : addKeyMapping, addMouseModeMapping, addMouseMovementMapping,
    anyModifiers, Axis, getMouseMode, KeyboardKeyModifier, KeyboardScanCode, MouseMode,
    MouseMovementType, removeMouseModeMapping, setContinuousRelativeMouseMovement,
    setMouseMovementEnabled, setRawMouseMotion;

import retrograde.std.geometry : OrientationComponentType;
import retrograde.std.math : atan2, atan2f, degreesToRadians, PI, Quaternion, scalar, Vector3;
import retrograde.std.option : none, Option, some;
import retrograde.std.stringid : sid, StringId;

/**
 * The event that turns the entity to the left and to the right.
 *
 * Read as an axis rather than as a nudge: its magnitude is how far the entity
 * turns over an update, and a positive one turns it to the right, the way moving
 * the mouse to the right does. An update it is not emitted on leaves it at the
 * magnitude it last carried, so an axis that stops has to say so by emitting a
 * zero. That is what mouse movement does of its own accord, as long as it is
 * read as an axis: see $(D setContinuousRelativeMouseMovement).
 *
 * Bound to the horizontal movement of the mouse by
 * $(D mapMouseMovementToLookAround). A key turns the entity along the same axis
 * rather than through an event of its own: the one that turns it the other way
 * is bound at a negative multiplier, which is what
 * $(D mapKeyboardArrowsToLookAround) does with the left arrow.
 */
const StringId evLookHorizontal = "ev_look_horizontal".sid;

/**
 * The event that turns the entity up and down.
 *
 * Read as an axis the way $(D evLookHorizontal) is, and positive downwards: the
 * mouse is Y-down over the window, so moving it towards the user looks down.
 */
const StringId evLookVertical = "ev_look_vertical".sid;

/**
 * The events that have the entities look around at all, and that stop them.
 *
 * Whatever else the look-around is told, it turns nothing while it is switched
 * off, and the axes carry on being followed while it is: a look-around switched
 * back on picks up wherever the player is pointing by then rather than working
 * through everything they did while it was off.
 *
 * These are read as a state rather than as an impulse, the way a held key is: a
 * magnitude of anything but zero is the switch being held one way, and a zero is
 * it being let go. The two events are the two ways of saying the same thing, so
 * that either sense may be bound to whatever a game already has: an
 * $(D evLookingEnabled) of zero switches the look-around off just as an
 * $(D evLookingDisabled) of one does. Whichever event was heard last is the one
 * that counts.
 *
 * Nothing emits them of its own accord. Bind them to the mouse mode with
 * $(D mapMouseModeToLookAround), or emit them from a processor of the game's own:
 * a menu that opens, a cutscene that starts, a player who is dead.
 *
 * ---
 * // Stop looking around while the inventory is open.
 * eventQueue.enqueue(Event(evLookingDisabled, 1));
 * ---
 */
const StringId evLookingEnabled = "ev_looking_enabled".sid;

/// ditto
const StringId evLookingDisabled = "ev_looking_disabled".sid;

/**
 * The component that has an entity look around.
 *
 * Add it to the camera, or to whatever else the player is looking through. An
 * entity also needs an $(D OrientationComponentType) to have anything to turn.
 *
 * The component data is a $(D LookAroundConfiguration) of the entity's own, which
 * it may do without: an entity that carries the component without any data looks
 * around by $(D lookAroundDefaults), along with every other entity that does.
 *
 * ---
 * // Looking around the way the rest of the game does.
 * entity.addComponent(LookAroundComponentType);
 *
 * // Looking around twice as fast as the rest of the game.
 * auto configuration = lookAroundDefaults;
 * configuration.sensitivity = configuration.sensitivity * 2;
 * entity.addComponent(LookAroundComponentType, makeUnique(configuration));
 * ---
 */
enum LookAroundComponentType = sid("comp_look_around");

/**
 * How far an entity turns for what it is told to look around by.
 *
 * The same numbers stand for the game as a whole and for a single entity: they
 * are $(D lookAroundDefaults) when the game keeps them, and the data of an
 * entity's $(D LookAroundComponentType) when an entity keeps its own.
 *
 * An entity's own configuration stands on its own rather than filling the gaps
 * from the game's: a copy of $(D lookAroundDefaults) is the place to start from
 * when only one of these is meant to be different.
 */
struct LookAroundConfiguration {
    /**
     * How far, in radians, a whole unit of $(D evLookHorizontal) or
     * $(D evLookVertical) turns the entity.
     *
     * The default is a tenth of a degree per unit, which suits the raw pixel
     * distances that $(D mapMouseMovementToLookAround) asks the platform for. A
     * game that leaves raw mouse motion off is handed the distance as a fraction
     * of the window instead, and wants this several hundred times larger.
     */
    scalar sensitivity = degreesToRadians(0.1);

    /**
     * How far up or down, in radians, the entity is allowed to look.
     *
     * Looking further would take it over the top and leave it upside down, so the
     * pitch stops here while the turn to the left and right carries on. The
     * default of 89 degrees leaves it just short of looking straight up or
     * straight down. A limit of 90 degrees or more leaves the pitch unclamped.
     */
    scalar maxPitch = degreesToRadians(89);
}

/**
 * How far the entities that keep no configuration of their own turn.
 *
 * Changing this changes how the whole game looks around, from the very next
 * update on, and leaves the entities that carry a configuration of their own
 * where they are.
 */
LookAroundConfiguration lookAroundDefaults;

/**
 * The axes as they were last reported, in the magnitudes of the events
 * themselves.
 *
 * Kept as the readings rather than as the rotation they come down to, so that
 * the sensitivity can be changed while the game is running and take effect on
 * the very next update.
 */
private scalar horizontalMagnitude = 0;

/// ditto
private scalar verticalMagnitude = 0;

/// Whether the processor is already at work and its events listened to.
private bool lookAroundProcessorInstalled = false;

/**
 * Whether the look-around turns anything at all, as $(D evLookingEnabled) and
 * $(D evLookingDisabled) last had it.
 *
 * On until something says otherwise, so that a game that never switches it off
 * has nothing to switch on.
 */
private bool lookingEnabled = true;

/**
 * The mouse mode $(D mapMouseModeToLookAround) bound the enable event to, kept so
 * that binding another mode can unbind this one first.
 */
private Option!MouseMode mappedMouseMode;

/**
 * Turns every entity that looks around by however far the look-around events say
 * it should, once per update.
 *
 * Put to work by $(D initLookAroundProcessor), which also has the events it goes
 * by listened to. A game that adds it with $(D addEntityProcessor) itself is left
 * with a processor that never hears anything.
 */
enum LookAroundProcessor = delegate(EntityId entity) {
    // Nothing to be told apart from one entity to the next while every axis and
    // direction is at rest, which is most of the time.
    if (lookAroundAtRest()) {
        return;
    }

    if (!lookingEnabled) {
        return;
    }

    auto maybeConfiguration = entity.getComponentData!LookAroundConfiguration(
        LookAroundComponentType);
    if (maybeConfiguration.isEmpty) {
        return;
    }

    // A component added without any data of its own leaves the entity looking
    // around the way the rest of the game does.
    const LookAroundConfiguration configuration = maybeConfiguration.value is null ?
        lookAroundDefaults : *maybeConfiguration.value;

    const scalar yaw = yawAngle(configuration);
    const scalar pitch = pitchAngle(configuration);
    if (yaw == 0 && pitch == 0) {
        return;
    }

    entity.withComponentData!Quaternion(OrientationComponentType, (Quaternion* orientation) {
        Quaternion newOrientation = *orientation;

        if (yaw != 0) {
            // Turning around the world's up axis rather than around the entity's
            // own keeps the horizon level: an entity that is looking up would
            // otherwise turn around the axis it is looking along, which rolls it
            // over. Putting the turn on the left-hand side is what applies it in
            // the world rather than in the entity.
            newOrientation = Quaternion.createRotation(yaw, Vector3.upVector) * newOrientation;
        }

        if (pitch != 0) {
            // A pitch that would take the entity past the limit is cut down to
            // however much of it is left, so that it ends up looking as far up or
            // down as it is allowed rather than short of it.
            const scalar allowed = allowedPitch(newOrientation, pitch, configuration.maxPitch);
            if (allowed != 0) {
                // Looking up and down is the other way around from turning
                // sideways: it happens around the entity's own right axis,
                // wherever the entity is facing, which is what putting it on the
                // right-hand side comes down to.
                newOrientation = newOrientation * Quaternion.createRotation(allowed, Vector3(1, 0, 0));
            }
        }

        // Rotations that build on one another drift away from unit length over
        // a game's worth of updates, taking a skew along into the view matrix.
        *orientation = newOrientation.normalize();
    });
};

/**
 * Put $(D LookAroundProcessor) to work and start listening to the events it goes
 * by.
 *
 * Call this once, before the game loop starts, and where the looking around
 * belongs among the game's other processors: they run in the order they were
 * added. Calling it more than once leaves the processor where it is rather than
 * adding it again, so a game may call it a second time to change the mode the
 * look-around asks for.
 *
 * The events still have to come from somewhere: see
 * $(D mapMouseMovementToLookAround) and $(D mapKeyboardArrowsToLookAround), or
 * map the events by hand for a game that looks around by other controls.
 */
void initLookAroundProcessor() {
    unmapMouseModeFromLookAround();
    lookingEnabled = true;
    installLookAroundProcessor();
}

/**
 * Put the look-around to work for one mode of the mouse only.
 *
 * Shorthand for $(D initLookAroundProcessor) followed by
 * $(D mapMouseModeToLookAround), for the game that wants both and wants them of
 * the same mode.
 *
 * Params:
 *  requiredMouseMode = The mode the mouse has to be in for the entities to turn.
 */
void initLookAroundProcessor(MouseMode requiredMouseMode) {
    installLookAroundProcessor();
    mapMouseModeToLookAround(requiredMouseMode);
}

/**
 * Have the mouse taking on the given mode switch the look-around on, and leaving
 * it switch the look-around off again.
 *
 * A game that looks around by the mouse usually wants it locked to the window
 * while it does, and wants nothing to turn while the player has the pointer back:
 *
 * ---
 * mapMouseModeToLookAround(MouseMode.disabled);
 * setMouseMode(MouseMode.disabled);
 * ---
 *
 * The events are still followed while the mouse is in another mode, so nothing
 * piles up to be worked through the moment the mode comes back: the entity picks
 * up wherever the player is pointing by then. Which mode the mouse is really in is
 * what counts here rather than which one it was asked for, the same as
 * $(D getMouseMode) reports, so a browser that has not handed over the pointer
 * lock yet leaves the look-around alone until it does.
 *
 * The mouse is one voice among several rather than the last word: the look-around
 * is switched by $(D evLookingEnabled) and $(D evLookingDisabled), and whatever
 * else emits those has as much say as the mouse mode does. A game that both binds
 * the mouse mode and stops the player looking around in a menu is left with a
 * look-around that comes back on the next time the mouse changes mode, which is
 * why a menu that closes wants to switch it back on itself.
 *
 * The look-around takes the mode the mouse is in as this is called, rather than
 * waiting for the next change of it, so that the order this is set up in does not
 * matter. Only one mode is bound at a time: binding another unbinds the one
 * before it, and $(D initLookAroundProcessor) without a mode unbinds it
 * altogether.
 *
 * Params:
 *  mouseMode = The mode the mouse has to be in for the entities to turn.
 */
void mapMouseModeToLookAround(MouseMode mouseMode) {
    unmapMouseModeFromLookAround();

    addMouseModeMapping(mouseMode, evLookingEnabled);
    mappedMouseMode = some(mouseMode);
    lookingEnabled = getMouseMode() == mouseMode;
}

/// Unbinds the mouse mode the look-around was last bound to, if it was bound.
private void unmapMouseModeFromLookAround() {
    if (mappedMouseMode.isEmpty) {
        return;
    }

    removeMouseModeMapping(mappedMouseMode.value, evLookingEnabled);
    mappedMouseMode = none!MouseMode;
}

/// Adds the processor and its event handler, once and no more than once.
private void installLookAroundProcessor() {
    if (lookAroundProcessorInstalled) {
        return;
    }

    addEntityProcessor(LookAroundProcessor);
    eventHandlers.add(lookAroundEventHandler);
    lookAroundProcessorInstalled = true;
}

/**
 * Have the mouse look around, the way it does in a first-person game.
 *
 * The distance the mouse moved is what the entity turns by, so the platform is
 * asked for relative movement, in the raw values of the platform, read as an axis
 * that comes to rest on its own. That last part is what keeps a mouse that lies
 * still from turning the entity forever: see
 * $(D setContinuousRelativeMouseMovement).
 *
 * The mouse is left in the mode it is in. A game that looks around by the mouse
 * usually wants it locked to the window as well, which is
 * $(D setMouseMode(MouseMode.disabled)), but that also hides it from the rest of
 * the game and is left to be asked for on purpose. Asking the look-around for
 * that same mode, through $(D initLookAroundProcessor), keeps it from turning
 * anything while the mouse is not locked.
 */
void mapMouseMovementToLookAround() {
    setMouseMovementEnabled(MouseMovementType.relative, true);
    setContinuousRelativeMouseMovement(true);
    setRawMouseMotion(true);

    addMouseMovementMapping(Axis.x, evLookHorizontal, MouseMovementType.relative);
    addMouseMovementMapping(Axis.y, evLookVertical, MouseMovementType.relative);
}

/**
 * Have the arrow keys look around, turning the entity for as long as they are
 * held.
 *
 * The keys drive the same two axes the mouse drives, each pair of them at the
 * opposite ends of one: the right and down arrows stand for a movement the
 * positive way along their axis, the left and up arrows for the same movement
 * the negative way.
 *
 * A key carries no distance of its own, so $(D keyMagnitude) is the distance it
 * stands for: it is the reading of the axis while the key is down, in the same
 * units a mouse reports, and is turned into an angle by the entity's
 * $(D LookAroundConfiguration.sensitivity) the way a mouse movement of that same
 * distance would be. The keys turn an entity that is more sensitive further, the
 * same as the mouse does.
 *
 * The two ends of an axis are one reading rather than two, so the arrow pressed
 * last is the one that counts: holding both leaves the entity turning the way
 * the second of them says, and letting that one go stops the turn rather than
 * handing it back to the arrow still held.
 *
 * Params:
 *  keyMagnitude = The distance a held arrow key stands for. The default of 20
 *                 comes down to two degrees per update, or 120 degrees per
 *                 second at the default update rate, for an entity of the
 *                 default sensitivity.
 */
void mapKeyboardArrowsToLookAround(Magnitude keyMagnitude = 20) {
    addKeyMapping(KeyboardScanCode.left, evLookHorizontal, KeyboardKeyModifier.none,
        anyModifiers, -keyMagnitude);
    addKeyMapping(KeyboardScanCode.right, evLookHorizontal, KeyboardKeyModifier.none,
        anyModifiers, keyMagnitude);
    addKeyMapping(KeyboardScanCode.up, evLookVertical, KeyboardKeyModifier.none,
        anyModifiers, -keyMagnitude);
    addKeyMapping(KeyboardScanCode.down, evLookVertical, KeyboardKeyModifier.none,
        anyModifiers, keyMagnitude);
}

/**
 * Takes the magnitude of each look-around event as the reading of the axis it
 * belongs to.
 *
 * The magnitude is kept rather than added up: both the axis of a mouse read as
 * one and a key that is down report where they stand on every update they change
 * on, and say nothing at all while they stay where they are. Adding them up
 * would have an entity keep turning by everything the player ever did.
 */
private enum lookAroundEventHandler = delegate(ref const Event event) {
    if (event.name == evLookHorizontal) {
        horizontalMagnitude = cast(scalar) event.magnitude;
    } else if (event.name == evLookVertical) {
        verticalMagnitude = cast(scalar) event.magnitude;
    } else if (event.name == evLookingEnabled) {
        lookingEnabled = event.magnitude != 0;
    } else if (event.name == evLookingDisabled) {
        lookingEnabled = event.magnitude == 0;
    }
};

/**
 * Returns: Whether both axes are at rest, leaving nothing for any entity to turn
 *          by.
 *
 * Asked before an entity's configuration is looked up at all: how far an entity
 * turns is its own, but whether there is anything to turn by is the game's.
 */
private bool lookAroundAtRest() {
    return horizontalMagnitude == 0 && verticalMagnitude == 0;
}

/**
 * Returns: How far an entity configured this way turns to the left and right this
 *          update, in radians around the world's up axis.
 *
 * Turning to the right is a rotation the negative way around that axis, which is
 * where the sign comes from: the events themselves are positive to the right.
 */
private scalar yawAngle(const ref LookAroundConfiguration configuration) {
    return -(horizontalMagnitude * configuration.sensitivity);
}

/**
 * Returns: How far an entity configured this way looks up and down this update,
 *          in radians around its own right axis.
 *
 * Negative the way $(D yawAngle) is: the events are positive downwards, and
 * looking down is a rotation the negative way around the right axis.
 */
private scalar pitchAngle(const ref LookAroundConfiguration configuration) {
    return -(verticalMagnitude * configuration.sensitivity);
}

/**
 * Returns: How much of the given pitch the given orientation may take on without
 *          looking further up or down than the given limit allows.
 *
 * The pitch is cut down to what is left of the limit rather than left out
 * altogether, so that a mouse flung upwards leaves the entity looking as far up
 * as it may rather than wherever its last whole step happened to land. An
 * orientation that is already beyond the limit is handed the pitch that brings it
 * back to it.
 */
private scalar allowedPitch(const Quaternion orientation, const scalar pitch,
    const scalar maxPitch) {
    if (maxPitch >= PI / 2) {
        return pitch;
    }

    static if (is(scalar == float)) {
        alias _atan2 = atan2f;
    } else {
        alias _atan2 = atan2;
    }

    // An orientation looks along its negative Z axis and holds up its Y axis,
    // which are the third and second column of its rotation matrix. How far up it
    // is looking is how high the first of those reaches; how high the second
    // reaches says which side of straight up that is, which the first cannot tell
    // on its own: it is just as high ten degrees over the top as ten degrees short
    // of it.
    auto const rotation = orientation.toRotationMatrix();
    auto const currentPitch = _atan2(-rotation[1, 2], rotation[1, 1]);
    auto const newPitch = currentPitch + pitch;

    if (newPitch > maxPitch) {
        return maxPitch - currentPitch;
    }

    if (newPitch < -maxPitch) {
        return -maxPitch - currentPitch;
    }

    return pitch;
}

version (UnitTesting)  :  ///

import retrograde.engine.entity : addComponent, addEntityProcessor, createEntity, getComponentData,
    resetEcs, updateEntities;
import retrograde.engine.event : eventQueue, processEvents;
import retrograde.engine.input : EventMapping, hasKeyMapping, hasMouseModeMapping,
    hasMouseMovementMapping, KeyBinding, keyMapping, processInput, resetInput, setMouseMode;

import retrograde.std.math : approxEqual, sin, sinf, Vector4;
import retrograde.std.memory : makeUnique;
import retrograde.std.test : test, writeSection;

private void resetLookAround() {
    horizontalMagnitude = 0;
    verticalMagnitude = 0;

    lookAroundDefaults = LookAroundConfiguration.init;

    version (WasmMemTest) {
        // The WasmMemTest harness wipes the heap before each test, so the handlers
        // already hold a dangling pointer. Reset them to their init state without
        // freeing: clear() would log a benign "double free" for memory that is
        // gone already.
        import retrograde.std.memory : memset;

        memset(&eventHandlers, 0, eventHandlers.sizeof);
    } else {
        eventHandlers.clear();
    }

    lookAroundProcessorInstalled = false;
    lookingEnabled = true;
    mappedMouseMode = none!MouseMode;
}

/**
 * Sets up a game that looks around: nothing in the world, no input mapped, the
 * processor at work and its events listened to.
 */
private void setUpLookAround() {
    startLookAroundGame();
    initLookAroundProcessor();
}

/// ditto, for a game that only looks around in one mode of the mouse.
private void setUpLookAround(MouseMode requiredMouseMode) {
    startLookAroundGame();
    initLookAroundProcessor(requiredMouseMode);
}

/// Puts everything the look-around leans on back at the start.
private void startLookAroundGame() {
    resetEcs();
    resetInput();
    resetLookAround();

    // The mouse is the platform's rather than the input layer's, so it is left in
    // whichever mode the test before this one put it in until it is put back.
    takeMouseMode(MouseMode.normal);
}

/**
 * Has the mouse take the given mode and hands the events of the change to the
 * handlers that are listening, the way an update of the game would.
 */
private void takeMouseMode(MouseMode mouseMode) {
    setMouseMode(mouseMode);
    processInput();
    processEvents();
}

private EntityId createLookAroundEntity() {
    EntityId entity = createEntity("ent_look_around_test").value;
    entity.addComponent(LookAroundComponentType);
    entity.addComponent(OrientationComponentType, makeUnique(Quaternion.init));
    return entity;
}

/// An entity that looks around by a configuration of its own.
private EntityId createLookAroundEntity(LookAroundConfiguration configuration) {
    EntityId entity = createEntity("ent_configured_look_around_test").value;
    entity.addComponent(LookAroundComponentType, makeUnique(configuration));
    entity.addComponent(OrientationComponentType, makeUnique(Quaternion.init));
    return entity;
}

private EntityId createOrientedEntity() {
    EntityId entity = createEntity("ent_oriented_test").value;
    entity.addComponent(OrientationComponentType, makeUnique(Quaternion.init));
    return entity;
}

/**
 * Emits the given event as the input layer would, and hands it to the handlers
 * that are listening.
 */
private void emitLookEvent(StringId eventName, Magnitude magnitude) {
    eventQueue.enqueue(Event(eventName, magnitude));
    processEvents();
}

/**
 * Returns: The multiplier the given key emits the given event at.
 *
 * Asked of the mapping itself rather than of the events a press produces: the
 * keys cannot be pressed from here, and what the arrows are bound at is the
 * whole of what the mapping has to get right.
 */
private Magnitude keyMappingMultiplier(KeyboardScanCode scanCode, StringId eventName) {
    auto maybeEventMappings = keyMapping.getRef(KeyBinding(scanCode));
    assert(maybeEventMappings.isDefined, "The key is not bound at all");

    auto eventMappings = maybeEventMappings.value;
    foreach (i; 0 .. eventMappings.length) {
        const EventMapping eventMapping = (*eventMappings)[i];
        if (eventMapping.eventName == eventName) {
            return eventMapping.multiplier;
        }
    }

    assert(false, "The key does not emit the event");
}

/// Returns: The direction the given entity is looking in.
private Vector3 forwardOf(EntityId entity) {
    auto maybeOrientation = entity.getComponentData!Quaternion(OrientationComponentType);
    assert(maybeOrientation.isDefined);

    auto const forward = maybeOrientation.value.toRotationMatrix * Vector4(0, 0, -1, 0);
    return Vector3(forward.x, forward.y, forward.z);
}

void runLookAroundTests() {
    writeSection("-- Look-around tests --");

    test("mouse movement is mapped to the look-around axes", {
        setUpLookAround();
        mapMouseMovementToLookAround();

        assert(hasMouseMovementMapping(Axis.x, evLookHorizontal, MouseMovementType.relative));
        assert(hasMouseMovementMapping(Axis.y, evLookVertical, MouseMovementType.relative));
    });

    test("the arrow keys are mapped to the look-around axes", {
        setUpLookAround();
        mapKeyboardArrowsToLookAround();

        assert(hasKeyMapping(KeyboardScanCode.left, evLookHorizontal));
        assert(hasKeyMapping(KeyboardScanCode.right, evLookHorizontal));
        assert(hasKeyMapping(KeyboardScanCode.up, evLookVertical));
        assert(hasKeyMapping(KeyboardScanCode.down, evLookVertical));
    });

    test("the arrows of an axis are mapped as the opposites of one another", {
        setUpLookAround();
        mapKeyboardArrowsToLookAround();

        assert(keyMappingMultiplier(KeyboardScanCode.left, evLookHorizontal) ==
                -keyMappingMultiplier(KeyboardScanCode.right, evLookHorizontal));
        assert(keyMappingMultiplier(KeyboardScanCode.up, evLookVertical) ==
                -keyMappingMultiplier(KeyboardScanCode.down, evLookVertical));

        // The right and down arrows are the positive way along their axis, which
        // is to the right and downwards.
        assert(keyMappingMultiplier(KeyboardScanCode.right, evLookHorizontal) > 0);
        assert(keyMappingMultiplier(KeyboardScanCode.down, evLookVertical) > 0);
    });

    test("the arrow keys are mapped at the magnitude they were asked for", {
        setUpLookAround();
        mapKeyboardArrowsToLookAround(5);

        assert(keyMappingMultiplier(KeyboardScanCode.left, evLookHorizontal) == -5);
        assert(keyMappingMultiplier(KeyboardScanCode.right, evLookHorizontal) == 5);
        assert(keyMappingMultiplier(KeyboardScanCode.up, evLookVertical) == -5);
        assert(keyMappingMultiplier(KeyboardScanCode.down, evLookVertical) == 5);
    });

    test("a held arrow key turns as far as it used to per update", {
        setUpLookAround();
        mapKeyboardArrowsToLookAround();
        auto entity = createLookAroundEntity();

        // The default magnitude of an arrow key is what an entity of the default
        // sensitivity turns two degrees per update by.
        emitLookEvent(evLookHorizontal,
            keyMappingMultiplier(KeyboardScanCode.right, evLookHorizontal));
        updateEntities();

        assert(forwardOf(entity).x.approxEqual(sineOf(degreesToRadians(2)),
                cast(scalar) 0.001));
    });

    test("moving the mouse to the right turns the entity to the right", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.x > 0);
        assert(forward.z < 0);
        assert(forward.y.approxEqual(cast(scalar) 0));
    });

    test("moving the mouse towards the user looks down", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookVertical, 100);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.y < 0);
        assert(forward.z < 0);
        assert(forward.x.approxEqual(cast(scalar) 0));
    });

    test("an axis that comes to rest stops the turn", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();
        auto const turned = forwardOf(entity);

        emitLookEvent(evLookHorizontal, 0);
        updateEntities();
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.x.approxEqual(turned.x));
        assert(forward.z.approxEqual(turned.z));
    });

    test("a negative magnitude turns the entity the other way", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookHorizontal, -100);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.x < 0);
        assert(forward.z < 0);
    });

    test("an axis that stays where it is keeps turning the entity", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        // What a held key comes down to: the axis says where it stands once and
        // stays there, and the entity carries on turning by it every update.
        emitLookEvent(evLookHorizontal, -20);
        updateEntities();
        auto const afterOne = forwardOf(entity);

        updateEntities();
        auto const afterTwo = forwardOf(entity);

        assert(afterOne.x < 0);
        assert(afterTwo.x < afterOne.x);
    });

    test("the last magnitude an axis was given is the one it turns by", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        // The two ends of an axis are one reading rather than two, so the arrow
        // pressed last is the one the entity turns by rather than the two of them
        // cancelling out.
        emitLookEvent(evLookHorizontal, -20);
        emitLookEvent(evLookHorizontal, 20);
        updateEntities();

        assert(forwardOf(entity).x > 0);
    });

    test("looking up and down stops at the pitch limit", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        // Twenty degrees down per update, kept up for far longer than it takes to
        // reach the limit.
        emitLookEvent(evLookVertical, 200);
        foreach (i; 0 .. 20) {
            updateEntities();
        }

        auto const down = forwardOf(entity);
        assert(down.y.approxEqual(-sineOf(lookAroundDefaults.maxPitch), cast(scalar) 0.001));

        // Still facing the way it started rather than having gone over the top and
        // come back around.
        assert(down.z < 0);

        emitLookEvent(evLookVertical, -200);
        foreach (i; 0 .. 20) {
            updateEntities();
        }

        auto const up = forwardOf(entity);
        assert(up.y.approxEqual(sineOf(lookAroundDefaults.maxPitch), cast(scalar) 0.001));
        assert(up.z < 0);
    });

    test("turning sideways carries on while the pitch is clamped", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookVertical, 200);
        emitLookEvent(evLookHorizontal, 100);
        foreach (i; 0 .. 20) {
            updateEntities();
        }

        // Twenty updates of ten degrees each is 200 degrees around, which leaves
        // the entity facing the way it came from.
        auto const forward = forwardOf(entity);
        assert(forward.z > 0);
    });

    test("an entity turns by the configuration it carries", {
        setUpLookAround();
        auto configuration = lookAroundDefaults;
        configuration.sensitivity = lookAroundDefaults.sensitivity * 2;
        auto entity = createLookAroundEntity(configuration);
        auto otherEntity = createLookAroundEntity();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        // Twice as sensitive, so twice as far around: ten degrees against twenty.
        assert(forwardOf(entity).x.approxEqual(sineOf(degreesToRadians(20)),
                cast(scalar) 0.001));
        assert(forwardOf(otherEntity).x.approxEqual(sineOf(degreesToRadians(10)),
                cast(scalar) 0.001));
    });

    test("an entity stops at the pitch limit it carries", {
        setUpLookAround();
        auto configuration = lookAroundDefaults;
        configuration.maxPitch = degreesToRadians(30);
        auto entity = createLookAroundEntity(configuration);
        auto otherEntity = createLookAroundEntity();

        emitLookEvent(evLookVertical, 200);
        foreach (i; 0 .. 20) {
            updateEntities();
        }

        assert(forwardOf(entity).y.approxEqual(-sineOf(degreesToRadians(30)),
                cast(scalar) 0.001));
        assert(forwardOf(otherEntity).y.approxEqual(-sineOf(lookAroundDefaults.maxPitch),
                cast(scalar) 0.001));
    });

    test("the entities without a configuration follow the game's", {
        setUpLookAround();
        lookAroundDefaults.sensitivity = degreesToRadians(0.2);
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        assert(forwardOf(entity).x.approxEqual(sineOf(degreesToRadians(20)),
                cast(scalar) 0.001));
    });

    test("an entity that does not look around is left alone", {
        setUpLookAround();
        auto entity = createOrientedEntity();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.x.approxEqual(cast(scalar) 0));
        assert(forward.z.approxEqual(cast(scalar)-1));
    });

    test("a processor added without its events hears nothing", {
        startLookAroundGame();
        addEntityProcessor(LookAroundProcessor);
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.z.approxEqual(cast(scalar)-1));
    });

    // A hidden mouse is what these go by rather than a disabled one: nothing has
    // to be granted for the mouse to be hidden, so it is really in that mode on
    // every platform. See the pointer lock test below for the disabled one.
    test("a look-around set up for a mouse mode turns nothing in another one", {
        setUpLookAround(MouseMode.hidden);
        auto entity = createLookAroundEntity();

        // The mouse starts out the normal one, which is not the mode that was
        // asked for.
        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        auto const held = forwardOf(entity);
        assert(held.x.approxEqual(cast(scalar) 0));
        assert(held.z.approxEqual(cast(scalar)-1));
    });

    test("a look-around set up for a mouse mode turns in that mode", {
        setUpLookAround(MouseMode.hidden);
        auto entity = createLookAroundEntity();
        takeMouseMode(MouseMode.hidden);

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        auto const turned = forwardOf(entity);
        assert(turned.x > 0);

        // And stops again the moment the mouse is back to the normal one.
        takeMouseMode(MouseMode.normal);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.x.approxEqual(turned.x));
        assert(forward.z.approxEqual(turned.z));
    });

    test("a look-around set up without a mouse mode turns in any of them", {
        setUpLookAround();
        auto entity = createLookAroundEntity();
        takeMouseMode(MouseMode.hidden);

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();
        auto const whileHidden = forwardOf(entity);
        assert(whileHidden.x > 0);

        // Carries on turning in the normal mode, rather than only in the one it
        // happened to start in.
        takeMouseMode(MouseMode.normal);
        updateEntities();
        assert(forwardOf(entity).x > whileHidden.x);
    });

    test("a look-around set up for the disabled mouse waits for the pointer lock", {
        setUpLookAround(MouseMode.disabled);
        auto entity = createLookAroundEntity();
        takeMouseMode(MouseMode.disabled);

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        version (Native) {
            // Nothing stands between asking for the mouse and having it here, so
            // the look-around has the mode it asked for right away.
            assert(forwardOf(entity).x > 0);
        }

        version (WebAssembly) {
            // The browser only hands the pointer lock over once the user has
            // clicked the render area, so the mouse is still the normal one and
            // nothing turns until they do.
            auto const forward = forwardOf(entity);
            assert(forward.x.approxEqual(cast(scalar) 0));
            assert(forward.z.approxEqual(cast(scalar)-1));
        }
    });

    test("a disabled look-around turns nothing until it is enabled again", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookingDisabled, 1);
        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        auto const held = forwardOf(entity);
        assert(held.x.approxEqual(cast(scalar) 0));
        assert(held.z.approxEqual(cast(scalar)-1));

        emitLookEvent(evLookingEnabled, 1);
        updateEntities();

        assert(forwardOf(entity).x > 0);
    });

    test("the two switching events are the two ways of saying the same thing", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        // A zero is the switch being let go, whichever of the two it is on: an
        // enable of zero switches the look-around off, and a disable of zero
        // switches it back on.
        emitLookEvent(evLookingEnabled, 0);
        emitLookEvent(evLookHorizontal, 100);
        updateEntities();
        assert(forwardOf(entity).x.approxEqual(cast(scalar) 0));

        emitLookEvent(evLookingDisabled, 0);
        updateEntities();
        assert(forwardOf(entity).x > 0);
    });

    test("a look-around switched back on picks up where the player is pointing", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        // The axes are followed while the look-around is off, so that what the
        // player did in the meantime is not worked through all at once when it
        // comes back on: the last reading is where they are pointing by now.
        emitLookEvent(evLookingDisabled, 1);
        emitLookEvent(evLookHorizontal, 100);
        foreach (i; 0 .. 10) {
            updateEntities();
        }

        emitLookEvent(evLookHorizontal, 0);
        emitLookEvent(evLookingEnabled, 1);
        updateEntities();

        assert(forwardOf(entity).x.approxEqual(cast(scalar) 0));
    });

    test("the mouse mode is mapped to the switching event", {
        setUpLookAround();
        mapMouseModeToLookAround(MouseMode.hidden);

        assert(hasMouseModeMapping(MouseMode.hidden, evLookingEnabled));
    });

    test("mapping another mouse mode unbinds the one before it", {
        setUpLookAround();
        mapMouseModeToLookAround(MouseMode.hidden);
        mapMouseModeToLookAround(MouseMode.disabled);

        assert(!hasMouseModeMapping(MouseMode.hidden, evLookingEnabled));
        assert(hasMouseModeMapping(MouseMode.disabled, evLookingEnabled));
    });

    test("the look-around takes the mode the mouse is already in", {
        startLookAroundGame();
        initLookAroundProcessor();
        auto entity = createLookAroundEntity();
        takeMouseMode(MouseMode.hidden);

        // Bound after the mouse took the mode rather than before, which emits
        // nothing of its own: the look-around goes by the mode it finds rather
        // than by waiting for the next change of it.
        mapMouseModeToLookAround(MouseMode.hidden);

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        assert(forwardOf(entity).x > 0);
    });

    test("setting up the look-around again changes the mouse mode it asks for", {
        setUpLookAround(MouseMode.hidden);
        auto entity = createLookAroundEntity();

        initLookAroundProcessor();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        // Turning while the mouse is the normal one, which the look-around no
        // longer asks anything of.
        assert(forwardOf(entity).x > 0);
    });

    test("setting up the look-around twice does not turn the entity twice", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();
        auto const turnedOnce = forwardOf(entity);

        setUpLookAround();
        initLookAroundProcessor();
        auto const otherEntity = createLookAroundEntity();

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        auto const forward = forwardOf(otherEntity);
        assert(forward.x.approxEqual(turnedOnce.x));
        assert(forward.z.approxEqual(turnedOnce.z));
    });
}

/**
 * Returns: The sine of the given angle, which is how far along an axis a direction
 *          turned by that angle reaches.
 */
private scalar sineOf(const scalar angle) {
    static if (is(scalar == float)) {
        alias _sin = sinf;
    } else {
        alias _sin = sin;
    }

    return _sin(angle);
}
