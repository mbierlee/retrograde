/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.processors.firstperson;

import retrograde.core.entity : Entity, EntityProcessor;
import retrograde.core.stringid : sid;
import retrograde.core.messaging : MessageHandler, MagnitudeMessage;
import retrograde.core.math : scalar, Vector3D, QuaternionD;
import retrograde.core.input : InputMapper, KeyboardKeyCode, MappingTarget;

import retrograde.components.firstperson : FirstPersonControllableComponent;
import retrograde.components.animation : TranslationComponent, RotationComponent, AxisRotationComponent;

import std.math : PI;

const auto movementChannel = sid("first_person_movement_channel");

const auto cmdMoveForwards = sid("cmd_move_forwards");
const auto cmdMoveBackwards = sid("cmd_move_backwards");
const auto cmdStrafeLeft = sid("cmd_strafe_left");
const auto cmdStrafeRight = sid("cmd_strafe_right");

const auto cmdLookUp = sid("cmd_look_up");
const auto cmdLookDown = sid("cmd_look_down");
const auto cmdLookLeft = sid("cmd_look_left");
const auto cmdLookRight = sid("cmd_look_right");

/** 
 * This processor handles the movement of entities with the FirstPersonControllableComponent.
 * 
 * When the entity has a camera its view will be updated to match the movement and view of the entity.
 */
class FirstPersonControllableProcessor : EntityProcessor {
    private MessageHandler messageHandler;

    private const defaultRotationSpeedFactor = (2 * PI) / 100;

    this(MessageHandler messageHandler) {
        this.messageHandler = messageHandler;
    }

    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!FirstPersonControllableComponent;
    }

    public override void update() {
        bool receivedMoveForwards = false;
        bool receivedMoveBackwards = false;
        bool receivedStrafeLeft = false;
        bool receivedStrafeRight = false;

        bool receivedLookUp = false;
        bool receivedLookDown = false;
        bool receivedLookLeft = false;
        bool receivedLookRight = false;

        scalar moveForwards = 0;
        scalar moveBackwards = 0;
        scalar strafeLeft = 0;
        scalar strafeRight = 0;

        scalar lookUp = 0;
        scalar lookDown = 0;
        scalar lookLeft = 0;
        scalar lookRight = 0;

        messageHandler.receiveMessages(movementChannel, (immutable MagnitudeMessage message) {
            switch (message.id) {
            case cmdMoveForwards:
                receivedMoveForwards = true;
                moveForwards = message.magnitude;
                break;

            case cmdMoveBackwards:
                receivedMoveBackwards = true;
                moveBackwards = message.magnitude;
                break;

            case cmdStrafeLeft:
                receivedStrafeLeft = true;
                strafeLeft = message.magnitude;
                break;

            case cmdStrafeRight:
                receivedStrafeRight = true;
                strafeRight = message.magnitude;
                break;

            case cmdLookUp:
                receivedLookUp = true;
                lookUp = message.magnitude;
                break;

            case cmdLookDown:
                receivedLookDown = true;
                lookDown = message.magnitude;
                break;

            case cmdLookLeft:
                receivedLookLeft = true;
                lookLeft = message.magnitude;
                break;

            case cmdLookRight:
                receivedLookRight = true;
                lookRight = message.magnitude;
                break;

            default:
                break;
            }
        });

        bool receivedTranslation = receivedMoveForwards || receivedMoveBackwards || receivedStrafeLeft || receivedStrafeRight;
        bool receivedRotation = receivedLookUp || receivedLookDown || receivedLookLeft || receivedLookRight;

        if (receivedTranslation || receivedRotation) {
            foreach (entity; entities) {
                auto mc = entity.getComponent!FirstPersonControllableComponent;

                if (receivedMoveForwards) {
                    mc.moveForwards = moveForwards;
                }

                if (receivedMoveBackwards) {
                    mc.moveBackwards = moveBackwards;
                }

                if (receivedStrafeLeft) {
                    mc.strafeLeft = strafeLeft;
                }

                if (receivedStrafeRight) {
                    mc.strafeRight = strafeRight;
                }

                if (receivedLookUp) {
                    mc.lookUp = lookUp;
                }

                if (receivedLookDown) {
                    mc.lookDown = lookDown;
                }

                if (receivedLookLeft) {
                    mc.lookLeft = lookLeft;
                }

                if (receivedLookRight) {
                    mc.lookRight = lookRight;
                }

                if (receivedLookLeft || receivedLookRight) {
                    entity.maybeWithComponent!AxisRotationComponent((c) {
                        if (c.axis == Vector3D.upVector) {
                            c.radianAngle = (
                                -mc.lookRight + mc.lookLeft) * defaultRotationSpeedFactor * mc
                                .rotationSpeedModifier;
                        }
                    });
                }

                if (receivedRotation) {
                    entity.maybeWithComponent!RotationComponent((c) {
                        //TODO: Invert look: -mc.lookUp + mc.lookDown
                        QuaternionD newRotation =
                            QuaternionD.createRotation(
                                (-mc.lookRight + mc.lookLeft) * defaultRotationSpeedFactor * mc.rotationSpeedModifier,
                                Vector3D(0, 1, 0)
                            ) *
                            QuaternionD.createRotation(
                                (-mc.lookDown + mc.lookUp) * defaultRotationSpeedFactor * mc.rotationSpeedModifier,
                                Vector3D(1, 0, 0)
                            );

                        c.rotation = newRotation;
                    });
                }

                if (receivedTranslation) {
                    entity.maybeWithComponent!TranslationComponent((c) {
                        c.translation = Vector3D(
                            (mc.strafeRight - mc.strafeLeft) * mc.translationSpeedModifier,
                            0,
                            (mc.moveBackwards - mc.moveForwards) * mc.translationSpeedModifier
                        );
                    });
                }
            }
        }
    }
}

void mapStandardMovementKeyboardControls(InputMapper inputMapper) {
    inputMapper.addKeyMapping(KeyboardKeyCode.w, MappingTarget(movementChannel, cmdMoveForwards));
    inputMapper.addKeyMapping(KeyboardKeyCode.a, MappingTarget(movementChannel, cmdStrafeLeft));
    inputMapper.addKeyMapping(KeyboardKeyCode.s, MappingTarget(movementChannel, cmdMoveBackwards));
    inputMapper.addKeyMapping(KeyboardKeyCode.d, MappingTarget(movementChannel, cmdStrafeRight));
}

void mapStandardLookKeyboardControls(InputMapper inputMapper) {
    inputMapper.addKeyMapping(KeyboardKeyCode.up, MappingTarget(movementChannel, cmdLookUp));
    inputMapper.addKeyMapping(KeyboardKeyCode.down, MappingTarget(movementChannel, cmdLookDown));
    inputMapper.addKeyMapping(KeyboardKeyCode.left, MappingTarget(movementChannel, cmdLookLeft));
    inputMapper.addKeyMapping(KeyboardKeyCode.right, MappingTarget(movementChannel, cmdLookRight));
}
