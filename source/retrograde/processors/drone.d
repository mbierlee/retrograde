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

module retrograde.processors.drone;

import retrograde.core.entity : Entity, EntityProcessor, StandardEntityProcessorPriority;
import retrograde.core.stringid : sid;
import retrograde.core.messaging : MessageHandler, MagnitudeMessage;
import retrograde.core.math : Vector3D, scalar, QuaternionD;
import retrograde.core.input : InputMapper, KeyboardKeyCode, MappingTarget;

import retrograde.components.drone : DroneControllableComponent;
import retrograde.components.animation : TranslationComponent, RotationComponent;

import std.math : PI;

/** 
 * Used by the DroneControllerProcessor to move entities with drone controls.
 * Typically processed maped input from an InputMapper.
 */
const auto droneChannel = sid("drone_channel");

const auto cmdDroneMoveUp = sid("cmd_drone_move_up");
const auto cmdDroneMoveDown = sid("cmd_drone_move_down");
const auto cmdDroneMoveLeft = sid("cmd_drone_move_left");
const auto cmdDroneMoveRight = sid("cmd_drone_move_right");
const auto cmdDroneMoveForwards = sid("cmd_drone_move_forwards");
const auto cmdDroneMoveBackwards = sid("cmd_drone_move_backwards");

const auto cmdDroneYawLeft = sid("cmd_drone_yaw_left");
const auto cmdDroneYawRight = sid("cmd_drone_yaw_right");
const auto cmdDronePitchUp = sid("cmd_drone_pitch_up");
const auto cmdDronePitchDown = sid("cmd_drone_pitch_down");
const auto cmdDroneBankLeft = sid("cmd_drone_bank_left");
const auto cmdDroneBankRight = sid("cmd_drone_bank_right");

/** 
 * Controls entities with a DroneControllableComponent.
 *
 * The drone controller works in conjunction with the RotationEntityProcessor and
 * TranslationEntityProcessor to provide actual movement and rotation. As such all entities need
 * to have the following components:
 * - DroneControllableComponent
 * - RotationComponent
 * - TranslationComponent
 * - Orientation3DComponent
 * - Position3DComponent
 *
 * And the aforementioned processors need to be active.
 */
class DroneControllerProcessor : EntityProcessor {
    private MessageHandler messageHandler;
    private const defaultRotationSpeedFactor = (2 * PI) / 100;

    this(MessageHandler messageHandler) {
        priority = StandardEntityProcessorPriority.input;
        this.messageHandler = messageHandler;
    }

    override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!DroneControllableComponent;
    }

    override void update() {
        bool receivedPitchUp = false;
        bool receivedPitchDown = false;
        bool receivedYawLeft = false;
        bool receivedYawRight = false;
        bool receivedBankLeft = false;
        bool receivedBankRight = false;

        bool receivedMoveForwards = false;
        bool receivedMoveBackwards = false;
        bool receivedMoveLeft = false;
        bool receivedMoveRight = false;
        bool receivedMoveUp = false;
        bool receivedMoveDown = false;

        scalar pitchUp = 0;
        scalar pitchDown = 0;
        scalar yawLeft = 0;
        scalar yawRight = 0;
        scalar bankLeft = 0;
        scalar bankRight = 0;

        scalar moveForwards = 0;
        scalar moveBackwards = 0;
        scalar moveLeft = 0;
        scalar moveRight = 0;
        scalar moveUp = 0;
        scalar moveDown = 0;

        messageHandler.receiveMessages(droneChannel, (immutable MagnitudeMessage message) {
            switch (message.id) {
            case cmdDroneMoveLeft:
                receivedMoveLeft = true;
                moveLeft = message.magnitude;
                break;

            case cmdDroneMoveRight:
                receivedMoveRight = true;
                moveRight = message.magnitude;
                break;

            case cmdDroneMoveUp:
                receivedMoveUp = true;
                moveUp = message.magnitude;
                break;

            case cmdDroneMoveDown:
                receivedMoveDown = true;
                moveDown = message.magnitude;
                break;

            case cmdDroneMoveForwards:
                receivedMoveForwards = true;
                moveForwards = message.magnitude;
                break;

            case cmdDroneMoveBackwards:
                receivedMoveBackwards = true;
                moveBackwards = message.magnitude;
                break;

            case cmdDroneYawLeft:
                receivedYawLeft = true;
                yawLeft = message.magnitude;
                break;

            case cmdDroneYawRight:
                receivedYawRight = true;
                yawRight = message.magnitude;
                break;

            case cmdDronePitchUp:
                receivedPitchUp = true;
                pitchUp = message.magnitude;
                break;

            case cmdDronePitchDown:
                receivedPitchDown = true;
                pitchDown = message.magnitude;
                break;

            case cmdDroneBankLeft:
                receivedBankLeft = true;
                bankLeft = message.magnitude;
                break;

            case cmdDroneBankRight:
                receivedBankRight = true;
                bankRight = message.magnitude;
                break;

            default:
                break;
            }
        });

        bool receivedRotation = receivedBankLeft || receivedBankRight || receivedPitchUp || receivedPitchDown || receivedYawLeft || receivedYawRight;
        bool receivedTranslation = receivedMoveBackwards || receivedMoveForwards || receivedMoveLeft || receivedMoveRight || receivedMoveUp || receivedMoveDown;

        if (receivedRotation || receivedTranslation) {
            foreach (entity; entities) {
                auto dc = entity.getComponent!DroneControllableComponent;

                if (receivedBankLeft)
                    dc.bankLeft = bankLeft;
                if (receivedBankRight)
                    dc.bankRight = bankRight;
                if (receivedPitchUp)
                    dc.pitchUp = pitchUp;
                if (receivedPitchDown)
                    dc.pitchDown = pitchDown;
                if (receivedYawLeft)
                    dc.yawLeft = yawLeft;
                if (receivedYawRight)
                    dc.yawRight = yawRight;

                if (receivedMoveForwards)
                    dc.moveForwards = moveForwards;
                if (receivedMoveBackwards)
                    dc.moveBackwards = moveBackwards;
                if (receivedMoveLeft)
                    dc.moveLeft = moveLeft;
                if (receivedMoveRight)
                    dc.moveRight = moveRight;
                if (receivedMoveUp)
                    dc.moveUp = moveUp;
                if (receivedMoveDown)
                    dc.moveDown = moveDown;

                if (receivedRotation) {
                    entity.maybeWithComponent!RotationComponent((c) {
                        QuaternionD newRotation =
                            QuaternionD.createRotation(
                                (dc.yawLeft + -dc.yawRight) * defaultRotationSpeedFactor * dc.rotationSpeedModifier,
                                Vector3D(0, 1, 0)
                            ) *
                            QuaternionD.createRotation(
                                (-dc.pitchUp + dc.pitchDown) * defaultRotationSpeedFactor * dc.rotationSpeedModifier,
                                Vector3D(1, 0, 0)
                            ) *
                            QuaternionD.createRotation(
                                (-dc.bankLeft + dc.bankRight) * defaultRotationSpeedFactor * dc.rotationSpeedModifier,
                                Vector3D(0, 0, 1)
                            );

                        c.rotation = newRotation;
                    });
                }

                if (receivedTranslation) {
                    entity.maybeWithComponent!TranslationComponent((c) {
                        c.translation = Vector3D(
                            (dc.moveRight - dc.moveLeft) * dc.translationSpeedModifier,
                            (dc.moveUp - dc.moveDown) * dc.translationSpeedModifier,
                            (dc.moveBackwards - dc.moveForwards) * dc.translationSpeedModifier
                        );
                    });
                }
            }
        }
    }
}

/**
 * Adds standard keyboard-based drone controls mapping.
 *
 * WASD: Move forwards, left, backwards, right.
 * Q/E:  Tilt (roll) left/right.
 * R/F:  Move up/down.
 * Arrow keys: rotate up, down, left, right.
 */
void mapStandardDroneKeyboardControls(InputMapper inputMapper) {
    inputMapper.addKeyMapping(KeyboardKeyCode.r, MappingTarget(droneChannel, cmdDroneMoveUp));
    inputMapper.addKeyMapping(KeyboardKeyCode.f, MappingTarget(droneChannel, cmdDroneMoveDown));
    inputMapper.addKeyMapping(KeyboardKeyCode.w, MappingTarget(droneChannel, cmdDroneMoveForwards));
    inputMapper.addKeyMapping(KeyboardKeyCode.a, MappingTarget(droneChannel, cmdDroneMoveLeft));
    inputMapper.addKeyMapping(KeyboardKeyCode.s, MappingTarget(droneChannel, cmdDroneMoveBackwards));
    inputMapper.addKeyMapping(KeyboardKeyCode.d, MappingTarget(droneChannel, cmdDroneMoveRight));
    inputMapper.addKeyMapping(KeyboardKeyCode.left, MappingTarget(droneChannel, cmdDroneYawLeft));
    inputMapper.addKeyMapping(KeyboardKeyCode.right, MappingTarget(droneChannel, cmdDroneYawRight));
    inputMapper.addKeyMapping(KeyboardKeyCode.down, MappingTarget(droneChannel, cmdDronePitchUp));
    inputMapper.addKeyMapping(KeyboardKeyCode.up, MappingTarget(droneChannel, cmdDronePitchDown));
    inputMapper.addKeyMapping(KeyboardKeyCode.q, MappingTarget(droneChannel, cmdDroneBankLeft));
    inputMapper.addKeyMapping(KeyboardKeyCode.e, MappingTarget(droneChannel, cmdDroneBankRight));
}
