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

import retrograde.engine.entity : addEntityProcessor, EntityId, hasComponent, withComponentData;
import retrograde.engine.event : Event, eventHandlers;
import retrograde.engine.input : addKeyMapping, addMouseMovementMapping, Axis, getMouseMode,
    KeyboardScanCode, MouseMode, MouseMovementType, setContinuousRelativeMouseMovement,
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
 * $(D mapMouseMovementToLookAround). Turning by a key rather than by an axis is
 * what $(D evLookLeft) and $(D evLookRight) are for.
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
 * The events that turn the entity in a single direction, for as long as they are
 * up.
 *
 * These are the keyboard's side of looking around: a key is held rather than
 * moved, so it carries no distance of its own and turns the entity at
 * $(D lookAroundDirectionSpeed) for as long as it is down. Opposite directions
 * that are both up cancel each other out, leaving the entity where it is.
 *
 * Bound to the arrow keys by $(D mapKeyboardArrowsToLookAround).
 */
const StringId evLookLeft = "ev_look_left".sid;

/// ditto
const StringId evLookRight = "ev_look_right".sid;

/// ditto
const StringId evLookUp = "ev_look_up".sid;

/// ditto
const StringId evLookDown = "ev_look_down".sid;

/**
 * The component that has an entity look around.
 *
 * It carries no data: the look-around events are the game's, not the entity's,
 * so every entity that has this component looks around together. Add it to the
 * camera, or to whatever else the player is looking through. An entity also
 * needs an $(D OrientationComponentType) to have anything to turn.
 */
enum LookAroundComponentType = sid("comp_look_around");

/**
 * How far, in radians, a whole unit of $(D evLookHorizontal) or
 * $(D evLookVertical) turns the entity.
 *
 * The default is a tenth of a degree per unit, which suits the raw pixel
 * distances that $(D mapMouseMovementToLookAround) asks the platform for. A game
 * that leaves raw mouse motion off is handed the distance as a fraction of the
 * window instead, and wants this several hundred times larger.
 */
scalar lookAroundSensitivity = degreesToRadians(0.1);

/**
 * How far, in radians, an entity turns per update while a look direction such as
 * $(D evLookLeft) is up.
 *
 * The engine updates at a fixed rate, so this is a speed: the default of two
 * degrees per update comes down to 120 degrees per second at the default rate.
 */
scalar lookAroundDirectionSpeed = degreesToRadians(2);

/**
 * How far up or down, in radians, an entity is allowed to look.
 *
 * Looking further would take the entity over the top and leave it upside down,
 * so the pitch stops here while the turn to the left and right carries on. The
 * default of 89 degrees leaves the entity just short of looking straight up or
 * straight down. A limit of 90 degrees or more leaves the pitch unclamped.
 */
scalar maxLookAroundPitch = degreesToRadians(89);

/**
 * The axes and directions as they were last reported, in the magnitudes of the
 * events themselves.
 *
 * Kept as the readings rather than as the rotation they come down to, so that
 * the sensitivities can be changed while the game is running and take effect on
 * the very next update.
 */
private scalar horizontalMagnitude = 0;

/// ditto
private scalar verticalMagnitude = 0;

/// ditto
private scalar leftMagnitude = 0;

/// ditto
private scalar rightMagnitude = 0;

/// ditto
private scalar upMagnitude = 0;

/// ditto
private scalar downMagnitude = 0;

/// Whether the processor is already at work and its events listened to.
private bool lookAroundProcessorInstalled = false;

/**
 * The mode the mouse has to be in for the look-around to turn anything, if it has
 * to be in one at all. Set through $(D initLookAroundProcessor).
 */
private Option!MouseMode requiredMouseMode;

/**
 * Turns every entity that looks around by however far the look-around events say
 * it should, once per update.
 *
 * Put to work by $(D initLookAroundProcessor), which also has the events it goes
 * by listened to. A game that adds it with $(D addEntityProcessor) itself is left
 * with a processor that never hears anything.
 */
enum LookAroundProcessor = delegate(EntityId entity) {
    const scalar yaw = yawAngle();
    const scalar pitch = pitchAngle();
    if (yaw == 0 && pitch == 0) {
        return;
    }

    if (!inRequiredMouseMode()) {
        return;
    }

    if (!entity.hasComponent(LookAroundComponentType)) {
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
            const scalar allowed = allowedPitch(newOrientation, pitch);
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
    requiredMouseMode = none!MouseMode;
    installLookAroundProcessor();
}

/**
 * Put the look-around to work for one mode of the mouse only.
 *
 * A game that looks around by the mouse usually wants it locked to the window
 * while it does, and wants nothing to turn while the player has the pointer back:
 *
 * ---
 * initLookAroundProcessor(MouseMode.disabled);
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
 * Params:
 *  requiredMouseMode = The mode the mouse has to be in for the entities to turn.
 */
void initLookAroundProcessor(MouseMode requiredMouseMode) {
    .requiredMouseMode = some(requiredMouseMode);
    installLookAroundProcessor();
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
 * How fast they turn it is $(D lookAroundDirectionSpeed) rather than
 * $(D lookAroundSensitivity): a key carries no distance of its own, so the speed
 * is the mechanic's to decide.
 */
void mapKeyboardArrowsToLookAround() {
    addKeyMapping(KeyboardScanCode.left, evLookLeft);
    addKeyMapping(KeyboardScanCode.right, evLookRight);
    addKeyMapping(KeyboardScanCode.up, evLookUp);
    addKeyMapping(KeyboardScanCode.down, evLookDown);
}

/**
 * Takes the magnitude of each look-around event as the reading of the axis or
 * direction it belongs to.
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
    } else if (event.name == evLookLeft) {
        leftMagnitude = cast(scalar) event.magnitude;
    } else if (event.name == evLookRight) {
        rightMagnitude = cast(scalar) event.magnitude;
    } else if (event.name == evLookUp) {
        upMagnitude = cast(scalar) event.magnitude;
    } else if (event.name == evLookDown) {
        downMagnitude = cast(scalar) event.magnitude;
    }
};

/**
 * Returns: Whether the mouse is in the mode the look-around was set up for, or
 *          whether it was set up for whichever mode the mouse happens to be in.
 */
private bool inRequiredMouseMode() {
    return requiredMouseMode.isEmpty || getMouseMode() == requiredMouseMode.value;
}

/**
 * Returns: How far the entity turns to the left and right this update, in
 *          radians around the world's up axis.
 *
 * Turning to the right is a rotation the negative way around that axis, which is
 * where the sign comes from: the events themselves are positive to the right.
 */
private scalar yawAngle() {
    return -(horizontalMagnitude * lookAroundSensitivity + (
            rightMagnitude - leftMagnitude) * lookAroundDirectionSpeed);
}

/**
 * Returns: How far the entity looks up and down this update, in radians around
 *          its own right axis.
 *
 * Negative the way $(D yawAngle) is: the events are positive downwards, and
 * looking down is a rotation the negative way around the right axis.
 */
private scalar pitchAngle() {
    return -(verticalMagnitude * lookAroundSensitivity +
            (
                downMagnitude - upMagnitude) * lookAroundDirectionSpeed);
}

/**
 * Returns: How much of the given pitch the given orientation may take on without
 *          looking further up or down than $(D maxLookAroundPitch) allows.
 *
 * The pitch is cut down to what is left of the limit rather than left out
 * altogether, so that a mouse flung upwards leaves the entity looking as far up
 * as it may rather than wherever its last whole step happened to land. An
 * orientation that is already beyond the limit is handed the pitch that brings it
 * back to it.
 */
private scalar allowedPitch(const Quaternion orientation, const scalar pitch) {
    if (maxLookAroundPitch >= PI / 2) {
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

    if (newPitch > maxLookAroundPitch) {
        return maxLookAroundPitch - currentPitch;
    }

    if (newPitch < -maxLookAroundPitch) {
        return -maxLookAroundPitch - currentPitch;
    }

    return pitch;
}

version (UnitTesting)  :  ///

import retrograde.engine.entity : addComponent, addEntityProcessor, createEntity, getComponentData,
    resetEcs, updateEntities;
import retrograde.engine.event : eventQueue, Magnitude, processEvents;
import retrograde.engine.input : hasKeyMapping, hasMouseMovementMapping, resetInput, setMouseMode;

import retrograde.std.math : approxEqual, sin, sinf, Vector4;
import retrograde.std.memory : makeUnique;
import retrograde.std.test : test, writeSection;

private void resetLookAround() {
    horizontalMagnitude = 0;
    verticalMagnitude = 0;
    leftMagnitude = 0;
    rightMagnitude = 0;
    upMagnitude = 0;
    downMagnitude = 0;

    lookAroundSensitivity = degreesToRadians(0.1);
    lookAroundDirectionSpeed = degreesToRadians(2);
    maxLookAroundPitch = degreesToRadians(89);

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
    requiredMouseMode = none!MouseMode;
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
}

private EntityId createLookAroundEntity() {
    EntityId entity = createEntity("ent_look_around_test").value;
    entity.addComponent(LookAroundComponentType);
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

    test("the arrow keys are mapped to the look-around directions", {
        setUpLookAround();
        mapKeyboardArrowsToLookAround();

        assert(hasKeyMapping(KeyboardScanCode.left, evLookLeft));
        assert(hasKeyMapping(KeyboardScanCode.right, evLookRight));
        assert(hasKeyMapping(KeyboardScanCode.up, evLookUp));
        assert(hasKeyMapping(KeyboardScanCode.down, evLookDown));
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

    test("a look direction keeps turning the entity while it is held", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookLeft, 1);
        updateEntities();
        auto const afterOne = forwardOf(entity);

        updateEntities();
        auto const afterTwo = forwardOf(entity);

        assert(afterOne.x < 0);
        assert(afterTwo.x < afterOne.x);
    });

    test("letting go of a look direction stops the turn", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookLeft, 1);
        updateEntities();
        auto const turned = forwardOf(entity);

        emitLookEvent(evLookLeft, 0);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.x.approxEqual(turned.x));
        assert(forward.z.approxEqual(turned.z));
    });

    test("opposite look directions cancel each other out", {
        setUpLookAround();
        auto entity = createLookAroundEntity();

        emitLookEvent(evLookLeft, 1);
        emitLookEvent(evLookRight, 1);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.x.approxEqual(cast(scalar) 0));
        assert(forward.z.approxEqual(cast(scalar)-1));
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
        assert(down.y.approxEqual(-pitchLimitHeight(), cast(scalar) 0.001));

        // Still facing the way it started rather than having gone over the top and
        // come back around.
        assert(down.z < 0);

        emitLookEvent(evLookVertical, -200);
        foreach (i; 0 .. 20) {
            updateEntities();
        }

        auto const up = forwardOf(entity);
        assert(up.y.approxEqual(pitchLimitHeight(), cast(scalar) 0.001));
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
        setMouseMode(MouseMode.hidden);

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();

        auto const turned = forwardOf(entity);
        assert(turned.x > 0);

        // And stops again the moment the mouse is back to the normal one.
        setMouseMode(MouseMode.normal);
        updateEntities();

        auto const forward = forwardOf(entity);
        assert(forward.x.approxEqual(turned.x));
        assert(forward.z.approxEqual(turned.z));
    });

    test("a look-around set up without a mouse mode turns in any of them", {
        setUpLookAround();
        auto entity = createLookAroundEntity();
        setMouseMode(MouseMode.hidden);

        emitLookEvent(evLookHorizontal, 100);
        updateEntities();
        auto const whileHidden = forwardOf(entity);
        assert(whileHidden.x > 0);

        // Carries on turning in the normal mode, rather than only in the one it
        // happened to start in.
        setMouseMode(MouseMode.normal);
        updateEntities();
        assert(forwardOf(entity).x > whileHidden.x);
    });

    test("a look-around set up for the disabled mouse waits for the pointer lock", {
        setUpLookAround(MouseMode.disabled);
        auto entity = createLookAroundEntity();
        setMouseMode(MouseMode.disabled);

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

/// Returns: How high the direction an entity looks in reaches at the pitch limit.
private scalar pitchLimitHeight() {
    static if (is(scalar == float)) {
        alias _sin = sinf;
    } else {
        alias _sin = sin;
    }

    return _sin(maxLookAroundPitch);
}
