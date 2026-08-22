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

module retrograde.engine.mechanic.walk;

import retrograde.engine.entity : addEntityProcessor, EntityId, getComponentData,
    withComponentData;
import retrograde.engine.event : Event, eventHandlers, Magnitude;
import retrograde.engine.input : addKeyMapping, addMouseModeMapping, anyModifiers, getMouseMode,
    KeyboardKeyModifier, KeyboardScanCode, MouseMode, removeMouseModeMapping;

import retrograde.std.geometry : OrientationComponentType, PositionComponentType;
import retrograde.std.math : Quaternion, scalar, Vector3;
import retrograde.std.option : none, Option, some;
import retrograde.std.stringid : sid, StringId;

/**
 * The event that walks the entity forwards and backwards.
 *
 * Read as an axis rather than as a nudge: its magnitude is how far the entity
 * walks over an update, in whole steps of its
 * $(D WalkConfiguration.speed), and a positive one walks it forwards. An update
 * it is not emitted on leaves it at the magnitude it last carried, so an axis
 * that stops has to say so by emitting a zero. That is what a key does of its own
 * accord: it emits its magnitude when it goes down and a zero when it comes back
 * up.
 *
 * Bound to the W and S keys by $(D mapWasdToWalking). Walking backwards is not an
 * event of its own: the key that does it is bound at a negative multiplier, which
 * is what $(D mapWasdToWalking) does with S.
 */
const StringId evWalk = "ev_walk".sid;

/**
 * The event that walks the entity sideways, without turning it.
 *
 * Read as an axis the way $(D evWalk) is, and positive to the right of wherever
 * the entity is facing.
 */
const StringId evStrafe = "ev_strafe".sid;

/**
 * The events that have the entities walk at all, and that stop them.
 *
 * Whatever else the walking is told, it moves nothing while it is switched off,
 * and the axes carry on being followed while it is: a walk switched back on picks
 * up from whichever keys are held by then rather than covering all the ground the
 * player asked for while it was off.
 *
 * These are read as a state rather than as an impulse, the way a held key is: a
 * magnitude of anything but zero is the switch being held one way, and a zero is
 * it being let go. The two events are the two ways of saying the same thing, so
 * that either sense may be bound to whatever a game already has: an
 * $(D evWalkingEnabled) of zero switches the walking off just as an
 * $(D evWalkingDisabled) of one does. Whichever event was heard last is the one
 * that counts.
 *
 * Nothing emits them of its own accord. Bind them to the mouse mode with
 * $(D mapMouseModeToWalking), or emit them from a processor of the game's own: a
 * menu that opens, a rope the player is climbing, a foot they broke landing on
 * it.
 *
 * ---
 * // Stand still while the conversation is on.
 * eventQueue.enqueue(Event(evWalkingDisabled, 1));
 * ---
 */
const StringId evWalkingEnabled = "ev_walking_enabled".sid;

/// ditto
const StringId evWalkingDisabled = "ev_walking_disabled".sid;

/**
 * The component that has an entity walk around.
 *
 * Add it to the player, or to whatever else walks the world. An entity also needs
 * a $(D PositionComponentType) to have anything to move, and usually an
 * $(D OrientationComponentType) to walk relative to: one without an orientation
 * walks the way the world faces, along its negative Z axis.
 *
 * The component data is a $(D WalkConfiguration) of the entity's own, which it may
 * do without: an entity that carries the component without any data walks by
 * $(D walkDefaults), along with every other entity that does.
 *
 * ---
 * // Walking at the pace the rest of the game does.
 * entity.addComponent(WalkerComponentType);
 *
 * // Walking twice as fast as the rest of the game.
 * auto configuration = walkDefaults;
 * configuration.speed = configuration.speed * 2;
 * entity.addComponent(WalkerComponentType, makeUnique(configuration));
 * ---
 */
enum WalkerComponentType = sid("comp_walker");

/**
 * How far an entity walks for what it is told to walk by.
 *
 * The same numbers stand for the game as a whole and for a single entity: they
 * are $(D walkDefaults) when the game keeps them, and the data of an entity's
 * $(D WalkerComponentType) when an entity keeps its own.
 *
 * An entity's own configuration stands on its own rather than filling the gaps
 * from the game's: a copy of $(D walkDefaults) is the place to start from when
 * only one of these is meant to be different.
 */
struct WalkConfiguration {
    /**
     * How far, in world units, a whole unit of $(D evWalk) or $(D evStrafe) moves
     * the entity over one update.
     *
     * The default of a tenth of a unit per update comes down to six units a
     * second at the default update rate, for the whole-unit magnitude
     * $(D mapWasdToWalking) binds its keys at.
     *
     * An entity told to walk and to strafe at once covers this same distance over
     * the diagonal rather than the distance of both axes at once: the two axes
     * say which way it walks, and the larger of them how far. A key bound at
     * twice the magnitude still walks twice as far, over a diagonal as much as
     * over a straight line.
     */
    scalar speed = 0.1;
}

/**
 * How far the entities that keep no configuration of their own walk.
 *
 * Changing this changes how the whole game walks, from the very next update on,
 * and leaves the entities that carry a configuration of their own at the pace
 * they keep.
 */
WalkConfiguration walkDefaults;

/**
 * The axes as they were last reported, in the magnitudes of the events
 * themselves.
 *
 * Kept as the readings rather than as the distance they come down to, so that the
 * speed can be changed while the game is running and take effect on the very next
 * update.
 */
private scalar walkMagnitude = 0;

/// ditto
private scalar strafeMagnitude = 0;

/// Whether the processor is already at work and its events listened to.
private bool walkProcessorInstalled = false;

/**
 * Whether the walking moves anything at all, as $(D evWalkingEnabled) and
 * $(D evWalkingDisabled) last had it.
 *
 * On until something says otherwise, so that a game that never switches it off
 * has nothing to switch on.
 */
private bool walkingEnabled = true;

/**
 * The mouse mode $(D mapMouseModeToWalking) bound the enable event to, kept so
 * that binding another mode can unbind this one first.
 */
private Option!MouseMode mappedMouseMode;

/**
 * Moves every entity that walks by however far the walk events say it should,
 * once per update.
 *
 * The entity keeps the height it is at: it walks over the horizontal plane it
 * stands on, whichever way it is facing and however far up or down it happens to
 * be looking. Where that plane is is the entity's own business, so an entity that
 * has to fall or climb is left to something else to move up and down.
 *
 * Put to work by $(D initWalkProcessor), which also has the events it goes by
 * listened to. A game that adds it with $(D addEntityProcessor) itself is left
 * with a processor that never hears anything.
 */
enum WalkProcessor = delegate(EntityId entity) {
    // Out before the per-entity lookup: at rest is most of the updates there are,
    // and it is the game's answer rather than anything this entity has a say in.
    if (walkAtRest()) {
        return;
    }

    if (!walkingEnabled) {
        return;
    }

    auto maybeConfiguration = entity.getComponentData!WalkConfiguration(WalkerComponentType);
    if (maybeConfiguration.isEmpty) {
        return;
    }

    // Null for a component that was added without any data of its own, which
    // leaves the entity walking at the pace the rest of the game does.
    const WalkConfiguration configuration = maybeConfiguration.value is null ?
        walkDefaults : *maybeConfiguration.value;

    // The larger of the two readings rather than the two of them together, so that
    // a diagonal does not outrun a straight line, and rather than a fixed step, so
    // that a key bound at twice the magnitude still walks twice as far.
    const scalar distance = largerReading(walkMagnitude, strafeMagnitude) * configuration.speed;
    if (distance == 0) {
        return;
    }

    // Taken from the heading rather than from the entity's own right axis, so that
    // an entity rolled onto its side still strafes over the ground it stands on.
    const Vector3 heading = headingOf(entity);
    const Vector3 right = heading.cross(Vector3.upVector);

    const Vector3 direction = ((heading * walkMagnitude) + (right * strafeMagnitude)).normalize();
    const Vector3 step = direction * distance;

    entity.withComponentData!Vector3(PositionComponentType, (Vector3* position) {
        *position = *position + step;
    });
};

/**
 * Put $(D WalkProcessor) to work and start listening to the events it goes by.
 *
 * Call this once, before the game loop starts, and where the walking belongs
 * among the game's other processors: they run in the order they were added. A
 * game that also looks around usually wants to look first and walk after, so that
 * the entity walks the way the player is facing by now rather than the way they
 * were facing an update ago. Calling it more than once leaves the processor where
 * it is rather than adding it again, so a game may call it a second time to change
 * the mode the walking asks for.
 *
 * The events still have to come from somewhere: see $(D mapWasdToWalking), or map
 * the events by hand for a game that walks by other controls.
 */
void initWalkProcessor() {
    unmapMouseModeFromWalking();
    walkingEnabled = true;
    installWalkProcessor();
}

/**
 * Put the walking to work for one mode of the mouse only.
 *
 * Shorthand for $(D initWalkProcessor) followed by $(D mapMouseModeToWalking),
 * for the game that wants both and wants them of the same mode.
 *
 * Params:
 *  requiredMouseMode = The mode the mouse has to be in for the entities to walk.
 */
void initWalkProcessor(MouseMode requiredMouseMode) {
    installWalkProcessor();
    mapMouseModeToWalking(requiredMouseMode);
}

/**
 * Have the mouse taking on the given mode switch the walking on, and leaving it
 * switch the walking off again.
 *
 * A game that walks and looks around at once usually wants the two to come and go
 * together, so that the player who has the pointer back neither turns nor walks
 * off while they use it:
 *
 * ---
 * mapMouseModeToLookAround(MouseMode.disabled);
 * mapMouseModeToWalking(MouseMode.disabled);
 * setMouseMode(MouseMode.disabled);
 * ---
 *
 * The events are still followed while the mouse is in another mode, so nothing
 * piles up to be walked off the moment the mode comes back: the entity picks up
 * from whichever keys are held by then. Which mode the mouse is really in is what
 * counts here rather than which one it was asked for, the same as
 * $(D getMouseMode) reports, so a browser that has not handed over the pointer
 * lock yet leaves the walking alone until it does.
 *
 * The mouse is one voice among several rather than the last word: the walking is
 * switched by $(D evWalkingEnabled) and $(D evWalkingDisabled), and whatever else
 * emits those has as much say as the mouse mode does. A game that both binds the
 * mouse mode and stops the player walking in a menu is left with a walk that comes
 * back on the next time the mouse changes mode, which is why a menu that closes
 * wants to switch it back on itself.
 *
 * The walking takes the mode the mouse is in as this is called, rather than
 * waiting for the next change of it, so that the order this is set up in does not
 * matter. Only one mode is bound at a time: binding another unbinds the one before
 * it, and $(D initWalkProcessor) without a mode unbinds it altogether.
 *
 * Params:
 *  mouseMode = The mode the mouse has to be in for the entities to walk.
 */
void mapMouseModeToWalking(MouseMode mouseMode) {
    unmapMouseModeFromWalking();

    addMouseModeMapping(mouseMode, evWalkingEnabled);
    mappedMouseMode = some(mouseMode);
    walkingEnabled = getMouseMode() == mouseMode;
}

/// Unbinds the mouse mode the walking was last bound to, if it was bound.
private void unmapMouseModeFromWalking() {
    if (mappedMouseMode.isEmpty) {
        return;
    }

    removeMouseModeMapping(mappedMouseMode.value, evWalkingEnabled);
    mappedMouseMode = none!MouseMode;
}

/// Adds the processor and its event handler, once and no more than once.
private void installWalkProcessor() {
    if (walkProcessorInstalled) {
        return;
    }

    addEntityProcessor(WalkProcessor);
    eventHandlers.add(walkEventHandler);
    walkProcessorInstalled = true;
}

/**
 * Have the WASD keys walk, moving the entity for as long as they are held.
 *
 * The keys drive the two walk axes, each pair of them at the opposite ends of
 * one: W and D stand for a movement the positive way along their axis, which is
 * forwards and to the right, and S and A for the same movement the negative way.
 *
 * A key carries no distance of its own, so $(D keyMagnitude) is the reading of the
 * axis while the key is down, and is turned into a distance by the entity's
 * $(D WalkConfiguration.speed). The keys walk a faster entity further, and a key
 * bound at twice the magnitude walks twice as far: that is what a sprint is bound
 * as.
 *
 * The two ends of an axis are one reading rather than two, so the key pressed last
 * is the one that counts: holding both leaves the entity walking the way the
 * second of them says, and letting that one go stops it rather than handing it
 * back to the key still held.
 *
 * Params:
 *  keyMagnitude = The distance a held key stands for, as a multiple of the
 *                 entity's speed. The default of a whole unit walks an entity of
 *                 the default speed six units a second at the default update
 *                 rate.
 */
void mapWasdToWalking(Magnitude keyMagnitude = 1) {
    addKeyMapping(KeyboardScanCode.w, evWalk, KeyboardKeyModifier.none,
        anyModifiers, keyMagnitude);
    addKeyMapping(KeyboardScanCode.s, evWalk, KeyboardKeyModifier.none,
        anyModifiers, -keyMagnitude);
    addKeyMapping(KeyboardScanCode.d, evStrafe, KeyboardKeyModifier.none,
        anyModifiers, keyMagnitude);
    addKeyMapping(KeyboardScanCode.a, evStrafe, KeyboardKeyModifier.none,
        anyModifiers, -keyMagnitude);
}

/**
 * Takes the magnitude of each walk event as the reading of the axis it belongs
 * to.
 *
 * The magnitude is kept rather than added up: a key that is down reports where it
 * stands on every update it changes on, and says nothing at all while it stays
 * where it is. Adding them up would have an entity keep walking by everything the
 * player ever did.
 */
private enum walkEventHandler = delegate(ref const Event event) {
    if (event.name == evWalk) {
        walkMagnitude = cast(scalar) event.magnitude;
    } else if (event.name == evStrafe) {
        strafeMagnitude = cast(scalar) event.magnitude;
    } else if (event.name == evWalkingEnabled) {
        walkingEnabled = event.magnitude != 0;
    } else if (event.name == evWalkingDisabled) {
        walkingEnabled = event.magnitude == 0;
    }
};

/**
 * Returns: Whether both axes are at rest, leaving nothing for any entity to walk
 *          by.
 *
 * Asked before an entity's configuration is looked up at all: how far an entity
 * walks is its own, but whether there is anything to walk by is the game's.
 */
private bool walkAtRest() {
    return walkMagnitude == 0 && strafeMagnitude == 0;
}

/**
 * Returns: How far the two axes stand from rest between them, being however far
 *          the further of the two stands.
 *
 * How far an entity walks rather than which way: the two axes are read as one
 * step in the direction they come down to, and this is the length of that step,
 * in whole units of the entity's speed.
 */
private scalar largerReading(const scalar walk, const scalar strafe) {
    const scalar walked = walk < 0 ? -walk : walk;
    const scalar strafed = strafe < 0 ? -strafe : strafe;
    return walked > strafed ? walked : strafed;
}

/**
 * Returns: The way the given entity faces over the ground, as a unit vector on
 *          the horizontal plane.
 *
 * An entity that carries no orientation faces the way the world does, along its
 * negative Z axis.
 */
private Vector3 headingOf(EntityId entity) {
    auto maybeOrientation = entity.getComponentData!Quaternion(OrientationComponentType);
    if (maybeOrientation.isEmpty || maybeOrientation.value is null) {
        return Vector3(0, 0, -1);
    }

    return headingOf(*maybeOrientation.value);
}

/**
 * Returns: The way the given orientation faces over the ground, as a unit vector
 *          on the horizontal plane.
 *
 * An orientation looks along its negative Z axis and holds up its Y axis, which
 * are the third and second column of its rotation matrix. Dropping the height off
 * the first of those leaves the way it faces over the ground, which is what
 * walking goes by: looking up and down changes where the entity is looking rather
 * than where its feet take it.
 */
private Vector3 headingOf(const Quaternion orientation) {
    auto const rotation = orientation.toRotationMatrix();
    auto const forward = Vector3(-rotation[0, 2], -rotation[1, 2], -rotation[2, 2]);
    auto const overGround = Vector3(forward.x, 0, forward.z);

    // What little of the forward axis is left this close to straight up or down is
    // mostly the rounding of the numbers it came from, so the up axis stands in
    // for it: that one lies over the ground by then, behind the entity while it
    // looks up and ahead of it while it looks down.
    if (overGround.magnitude < headingEpsilon) {
        auto const up = Vector3(rotation[0, 1], rotation[1, 1], rotation[2, 1]);
        auto const upOverGround = Vector3(up.x, 0, up.z);
        return (forward.y > 0 ? upOverGround * -1 : upOverGround).normalize();
    }

    return overGround.normalize();
}

/**
 * How much of a heading over the ground has to be left for it to be worth
 * anything, being a hundredth of a degree away from straight up or down.
 */
private enum scalar headingEpsilon = 0.0001;

version (UnitTesting)  :  ///

import retrograde.engine.entity : addComponent, createEntity, resetEcs, updateEntities;
import retrograde.engine.event : eventQueue, processEvents;
import retrograde.engine.input : EventMapping, hasKeyMapping, hasMouseModeMapping, KeyBinding,
    keyMapping, processInput, resetInput, setMouseMode;

import retrograde.std.math : approxEqual, degreesToRadians;
import retrograde.std.memory : makeUnique;
import retrograde.std.test : test, writeSection;

private void resetWalk() {
    walkMagnitude = 0;
    strafeMagnitude = 0;

    walkDefaults = WalkConfiguration.init;

    eventHandlers.clear();

    walkProcessorInstalled = false;
    walkingEnabled = true;
    mappedMouseMode = none!MouseMode;
}

/**
 * Sets up a game that walks: nothing in the world, no input mapped, the processor
 * at work and its events listened to.
 */
private void setUpWalk() {
    startWalkGame();
    initWalkProcessor();
}

/// ditto, for a game that only walks in one mode of the mouse.
private void setUpWalk(MouseMode requiredMouseMode) {
    startWalkGame();
    initWalkProcessor(requiredMouseMode);
}

/// Puts everything the walking leans on back at the start.
private void startWalkGame() {
    resetEcs();
    resetInput();
    resetWalk();

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

/// An entity that walks, standing at the origin and facing the way the world does.
private EntityId createWalkerEntity() {
    EntityId entity = createEntity("ent_walker_test").value;
    entity.addComponent(WalkerComponentType);
    entity.addComponent(PositionComponentType, makeUnique(Vector3(0, 0, 0)));
    entity.addComponent(OrientationComponentType, makeUnique(Quaternion.init));
    return entity;
}

/// ditto, for an entity that walks by a configuration of its own.
private EntityId createWalkerEntity(WalkConfiguration configuration) {
    EntityId entity = createEntity("ent_configured_walker_test").value;
    entity.addComponent(WalkerComponentType, makeUnique(configuration));
    entity.addComponent(PositionComponentType, makeUnique(Vector3(0, 0, 0)));
    entity.addComponent(OrientationComponentType, makeUnique(Quaternion.init));
    return entity;
}

/// ditto, for an entity that walks while facing the given way.
private EntityId createWalkerEntity(Quaternion orientation) {
    EntityId entity = createEntity("ent_oriented_walker_test").value;
    entity.addComponent(WalkerComponentType);
    entity.addComponent(PositionComponentType, makeUnique(Vector3(0, 0, 0)));
    entity.addComponent(OrientationComponentType, makeUnique(orientation));
    return entity;
}

/// An entity that stands somewhere but does not walk.
private EntityId createStandingEntity() {
    EntityId entity = createEntity("ent_standing_test").value;
    entity.addComponent(PositionComponentType, makeUnique(Vector3(0, 0, 0)));
    entity.addComponent(OrientationComponentType, makeUnique(Quaternion.init));
    return entity;
}

/// An entity that walks without carrying an orientation to walk relative to.
private EntityId createUnorientedWalkerEntity() {
    EntityId entity = createEntity("ent_unoriented_walker_test").value;
    entity.addComponent(WalkerComponentType);
    entity.addComponent(PositionComponentType, makeUnique(Vector3(0, 0, 0)));
    return entity;
}

/**
 * Emits the given event as the input layer would, and hands it to the handlers
 * that are listening.
 */
private void emitWalkEvent(StringId eventName, Magnitude magnitude) {
    eventQueue.enqueue(Event(eventName, magnitude));
    processEvents();
}

/// Returns: Where the given entity stands.
private Vector3 positionOf(EntityId entity) {
    auto maybePosition = entity.getComponentData!Vector3(PositionComponentType);
    assert(maybePosition.isDefined);
    return *maybePosition.value;
}

/**
 * Returns: The multiplier the given key emits the given event at.
 *
 * Asked of the mapping itself rather than of the events a press produces: the
 * keys cannot be pressed from here, and what they are bound at is the whole of
 * what the mapping has to get right.
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

/// An orientation turned the given way around the world's up axis.
private Quaternion turnedBy(const scalar degrees) {
    return Quaternion.createRotation(degreesToRadians(degrees), Vector3.upVector);
}

/// An orientation looking the given way up or down, positive being up.
private Quaternion pitchedBy(const scalar degrees) {
    return Quaternion.createRotation(degreesToRadians(degrees), Vector3(1, 0, 0));
}

void runWalkTests() {
    writeSection("-- Walk tests --");

    test("the WASD keys are mapped to the walk axes", {
        setUpWalk();
        mapWasdToWalking();

        assert(hasKeyMapping(KeyboardScanCode.w, evWalk));
        assert(hasKeyMapping(KeyboardScanCode.s, evWalk));
        assert(hasKeyMapping(KeyboardScanCode.a, evStrafe));
        assert(hasKeyMapping(KeyboardScanCode.d, evStrafe));
    });

    test("the keys of an axis are mapped as the opposites of one another", {
        setUpWalk();
        mapWasdToWalking();

        assert(keyMappingMultiplier(KeyboardScanCode.s, evWalk) ==
                -keyMappingMultiplier(KeyboardScanCode.w, evWalk));
        assert(keyMappingMultiplier(KeyboardScanCode.a, evStrafe) ==
                -keyMappingMultiplier(KeyboardScanCode.d, evStrafe));

        // Which end of an axis is the positive one is a decision rather than a
        // given, and the decision is forwards and to the right.
        assert(keyMappingMultiplier(KeyboardScanCode.w, evWalk) > 0);
        assert(keyMappingMultiplier(KeyboardScanCode.d, evStrafe) > 0);
    });

    test("the WASD keys are mapped at the magnitude they were asked for", {
        setUpWalk();
        mapWasdToWalking(2);

        assert(keyMappingMultiplier(KeyboardScanCode.w, evWalk) == 2);
        assert(keyMappingMultiplier(KeyboardScanCode.s, evWalk) == -2);
        assert(keyMappingMultiplier(KeyboardScanCode.d, evStrafe) == 2);
        assert(keyMappingMultiplier(KeyboardScanCode.a, evStrafe) == -2);
    });

    test("walking forwards moves the entity the way it faces", {
        setUpWalk();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, 1);
        updateEntities();

        auto const position = positionOf(entity);
        assert(position.z.approxEqual(-walkDefaults.speed));
        assert(position.x.approxEqual(cast(scalar) 0));
        assert(position.y.approxEqual(cast(scalar) 0));
    });

    test("walking backwards moves the entity the other way", {
        setUpWalk();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, -1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(walkDefaults.speed));
    });

    test("strafing moves the entity sideways without turning it", {
        setUpWalk();
        auto entity = createWalkerEntity();

        emitWalkEvent(evStrafe, 1);
        updateEntities();

        auto const right = positionOf(entity);
        assert(right.x.approxEqual(walkDefaults.speed));
        assert(right.z.approxEqual(cast(scalar) 0));

        emitWalkEvent(evStrafe, -1);
        updateEntities();
        updateEntities();

        auto const left = positionOf(entity);
        assert(left.x.approxEqual(-walkDefaults.speed));
        assert(left.z.approxEqual(cast(scalar) 0));
    });

    test("a key held stands for a whole step per update", {
        setUpWalk();
        mapWasdToWalking();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, keyMappingMultiplier(KeyboardScanCode.w, evWalk));
        updateEntities();

        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed));
    });

    test("an axis that comes to rest stops the walk", {
        setUpWalk();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, 1);
        updateEntities();
        auto const walked = positionOf(entity);

        emitWalkEvent(evWalk, 0);
        updateEntities();
        updateEntities();

        auto const position = positionOf(entity);
        assert(position.x.approxEqual(walked.x));
        assert(position.z.approxEqual(walked.z));
    });

    test("an axis that stays where it is keeps walking the entity", {
        setUpWalk();
        auto entity = createWalkerEntity();

        // Emitted once for the two updates, which is what a held key comes down
        // to: it says where it stands and then says nothing more.
        emitWalkEvent(evWalk, 1);
        updateEntities();
        updateEntities();

        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed * 2));
    });

    test("the last magnitude an axis was given is the one it walks by", {
        setUpWalk();
        auto entity = createWalkerEntity();

        // The two ends of an axis are one reading rather than two, so these do not
        // cancel out: the second is simply where the axis stands by now.
        emitWalkEvent(evWalk, 1);
        emitWalkEvent(evWalk, -1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(walkDefaults.speed));
    });

    test("walking and strafing at once moves the entity diagonally", {
        setUpWalk();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, 1);
        emitWalkEvent(evStrafe, 1);
        updateEntities();

        auto const position = positionOf(entity);
        assert(position.z < 0);
        assert(position.x.approxEqual(-position.z, cast(scalar) 0.0001));
        assert(position.y.approxEqual(cast(scalar) 0));
    });

    test("a diagonal covers no more ground than a straight line", {
        setUpWalk();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, 1);
        emitWalkEvent(evStrafe, 1);
        updateEntities();

        // Adding the axes up would leave this half again as far, which is the
        // diagonal this is here to keep from happening.
        assert(positionOf(entity).magnitude.approxEqual(walkDefaults.speed,
                cast(scalar) 0.0001));
    });

    test("an axis read further walks further, over a diagonal as well", {
        setUpWalk();
        auto entity = createWalkerEntity();

        // Twice the magnitude is what a sprint is bound as, so holding the
        // diagonal to a single step must not hold it to a single speed as well.
        emitWalkEvent(evWalk, 2);
        updateEntities();
        assert(positionOf(entity).magnitude.approxEqual(walkDefaults.speed * 2,
                cast(scalar) 0.0001));

        setUpWalk();
        auto diagonalEntity = createWalkerEntity();

        emitWalkEvent(evWalk, 2);
        emitWalkEvent(evStrafe, 2);
        updateEntities();
        assert(positionOf(diagonalEntity).magnitude.approxEqual(walkDefaults.speed * 2,
                cast(scalar) 0.0001));
    });

    test("an axis read short of a whole unit walks short of a whole step", {
        setUpWalk();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, 0.5);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed / 2));
    });

    test("walking follows the way the entity is turned", {
        setUpWalk();

        // Turned a quarter of the way to the right, which leaves it facing along
        // the world's positive X axis.
        auto entity = createWalkerEntity(turnedBy(-90));

        emitWalkEvent(evWalk, 1);
        updateEntities();

        auto const position = positionOf(entity);
        assert(position.x.approxEqual(walkDefaults.speed, cast(scalar) 0.0001));
        assert(position.z.approxEqual(cast(scalar) 0, cast(scalar) 0.0001));
    });

    test("strafing follows the way the entity is turned", {
        setUpWalk();
        auto entity = createWalkerEntity(turnedBy(-90));

        emitWalkEvent(evStrafe, 1);
        updateEntities();

        // Facing along the positive X axis leaves its right along the positive Z
        // one.
        auto const position = positionOf(entity);
        assert(position.z.approxEqual(walkDefaults.speed, cast(scalar) 0.0001));
        assert(position.x.approxEqual(cast(scalar) 0, cast(scalar) 0.0001));
    });

    test("an entity that is looking down walks over the ground it stands on", {
        setUpWalk();
        auto entity = createWalkerEntity(pitchedBy(-45));

        emitWalkEvent(evWalk, 1);
        updateEntities();

        // Going by where it is looking would cover less ground the further down it
        // looked, and would take it underground besides.
        auto const position = positionOf(entity);
        assert(position.y.approxEqual(cast(scalar) 0));
        assert(position.z.approxEqual(-walkDefaults.speed, cast(scalar) 0.0001));
    });

    test("an entity that is looking straight up walks the way it faces", {
        setUpWalk();
        auto entity = createWalkerEntity(pitchedBy(90));

        emitWalkEvent(evWalk, 1);
        updateEntities();

        // Nothing of its forward axis is left over the ground to face by, so this
        // is the axis it holds up standing in: still the way it started out.
        auto const position = positionOf(entity);
        assert(position.y.approxEqual(cast(scalar) 0));
        assert(position.z.approxEqual(-walkDefaults.speed, cast(scalar) 0.0001));
    });

    test("an entity that is looking straight down walks the way it faces", {
        setUpWalk();
        auto entity = createWalkerEntity(pitchedBy(-90));

        emitWalkEvent(evWalk, 1);
        updateEntities();

        auto const position = positionOf(entity);
        assert(position.y.approxEqual(cast(scalar) 0));
        assert(position.z.approxEqual(-walkDefaults.speed, cast(scalar) 0.0001));
    });

    test("an entity without an orientation walks the way the world faces", {
        setUpWalk();
        auto entity = createUnorientedWalkerEntity();

        emitWalkEvent(evWalk, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed));
    });

    test("an entity walks by the configuration it carries", {
        setUpWalk();
        auto configuration = walkDefaults;
        configuration.speed = walkDefaults.speed * 2;
        auto entity = createWalkerEntity(configuration);
        auto otherEntity = createWalkerEntity();

        emitWalkEvent(evWalk, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed * 2));
        assert(positionOf(otherEntity).z.approxEqual(-walkDefaults.speed));
    });

    test("the entities without a configuration follow the game's", {
        setUpWalk();
        walkDefaults.speed = 1;
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(cast(scalar)-1));
    });

    test("an entity that does not walk is left where it stands", {
        setUpWalk();
        auto entity = createStandingEntity();

        emitWalkEvent(evWalk, 1);
        emitWalkEvent(evStrafe, 1);
        updateEntities();

        auto const position = positionOf(entity);
        assert(position.x.approxEqual(cast(scalar) 0));
        assert(position.z.approxEqual(cast(scalar) 0));
    });

    test("a processor added without its events hears nothing", {
        startWalkGame();
        addEntityProcessor(WalkProcessor);
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(cast(scalar) 0));
    });

    // A hidden mouse is what these go by rather than a disabled one: nothing has to
    // be granted for the mouse to be hidden, so it is really in that mode on every
    // platform. See the pointer lock test below for the disabled one.
    test("a walk set up for a mouse mode moves nothing in another one", {
        setUpWalk(MouseMode.hidden);
        auto entity = createWalkerEntity();

        // The mouse starts out the normal one, which is not the mode that was
        // asked for.
        emitWalkEvent(evWalk, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(cast(scalar) 0));
    });

    test("a walk set up for a mouse mode moves in that mode", {
        setUpWalk(MouseMode.hidden);
        auto entity = createWalkerEntity();
        takeMouseMode(MouseMode.hidden);

        emitWalkEvent(evWalk, 1);
        updateEntities();

        auto const walked = positionOf(entity);
        assert(walked.z.approxEqual(-walkDefaults.speed));

        // And stands still again the moment the mouse is back to the normal one,
        // rather than walking on by an axis nobody let go of.
        takeMouseMode(MouseMode.normal);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(walked.z));
    });

    test("a walk set up without a mouse mode moves in any of them", {
        setUpWalk();
        auto entity = createWalkerEntity();
        takeMouseMode(MouseMode.hidden);

        emitWalkEvent(evWalk, 1);
        updateEntities();
        auto const whileHidden = positionOf(entity);
        assert(whileHidden.z.approxEqual(-walkDefaults.speed));

        takeMouseMode(MouseMode.normal);
        updateEntities();
        assert(positionOf(entity).z < whileHidden.z);
    });

    test("a walk set up for the disabled mouse waits for the pointer lock", {
        setUpWalk(MouseMode.disabled);
        auto entity = createWalkerEntity();
        takeMouseMode(MouseMode.disabled);

        emitWalkEvent(evWalk, 1);
        updateEntities();

        version (Native) {
            // Nothing stands between asking for the mouse and having it here, so
            // the walking has the mode it asked for right away.
            assert(positionOf(entity).z.approxEqual(-walkDefaults.speed));
        }

        version (WebAssembly) {
            // The browser only hands the pointer lock over once the user has
            // clicked the render area, so the mouse is still the normal one and
            // nothing walks until they do.
            assert(positionOf(entity).z.approxEqual(cast(scalar) 0));
        }
    });

    test("a disabled walk moves nothing until it is enabled again", {
        setUpWalk();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalkingDisabled, 1);
        emitWalkEvent(evWalk, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(cast(scalar) 0));

        emitWalkEvent(evWalkingEnabled, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed));
    });

    test("the two switching events are the two ways of saying the same thing", {
        setUpWalk();
        auto entity = createWalkerEntity();

        // A zero is the switch being let go, whichever of the two it is on: an
        // enable of zero switches the walking off, and a disable of zero switches
        // it back on.
        emitWalkEvent(evWalkingEnabled, 0);
        emitWalkEvent(evWalk, 1);
        updateEntities();
        assert(positionOf(entity).z.approxEqual(cast(scalar) 0));

        emitWalkEvent(evWalkingDisabled, 0);
        updateEntities();
        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed));
    });

    test("a walk switched back on picks up from the keys held by then", {
        setUpWalk();
        auto entity = createWalkerEntity();

        // The axes are followed while the walking is off, so that the ground the
        // player asked for in the meantime is not covered all at once when it
        // comes back on: a key let go of in the meantime walks nowhere.
        emitWalkEvent(evWalkingDisabled, 1);
        emitWalkEvent(evWalk, 1);
        foreach (i; 0 .. 10) {
            updateEntities();
        }

        emitWalkEvent(evWalk, 0);
        emitWalkEvent(evWalkingEnabled, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(cast(scalar) 0));
    });

    test("the mouse mode is mapped to the switching event", {
        setUpWalk();
        mapMouseModeToWalking(MouseMode.hidden);

        assert(hasMouseModeMapping(MouseMode.hidden, evWalkingEnabled));
    });

    test("mapping another mouse mode unbinds the one before it", {
        setUpWalk();
        mapMouseModeToWalking(MouseMode.hidden);
        mapMouseModeToWalking(MouseMode.disabled);

        assert(!hasMouseModeMapping(MouseMode.hidden, evWalkingEnabled));
        assert(hasMouseModeMapping(MouseMode.disabled, evWalkingEnabled));
    });

    test("the walking takes the mode the mouse is already in", {
        startWalkGame();
        initWalkProcessor();
        auto entity = createWalkerEntity();
        takeMouseMode(MouseMode.hidden);

        // Bound after the mouse took the mode rather than before, which emits
        // nothing of its own: the walking goes by the mode it finds rather than by
        // waiting for the next change of it.
        mapMouseModeToWalking(MouseMode.hidden);

        emitWalkEvent(evWalk, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed));
    });

    test("setting up the walking again changes the mouse mode it asks for", {
        setUpWalk(MouseMode.hidden);
        auto entity = createWalkerEntity();

        initWalkProcessor();

        emitWalkEvent(evWalk, 1);
        updateEntities();

        // Walking while the mouse is the normal one, which the walking no longer
        // asks anything of.
        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed));
    });

    test("setting up the walking twice does not walk the entity twice", {
        setUpWalk();
        initWalkProcessor();
        auto entity = createWalkerEntity();

        emitWalkEvent(evWalk, 1);
        updateEntities();

        assert(positionOf(entity).z.approxEqual(-walkDefaults.speed));
    });
}
