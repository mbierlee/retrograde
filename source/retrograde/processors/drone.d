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

module retrograde.processors.drone;

import retrograde.core.entity : Entity, EntityProcessor;
import retrograde.core.stringid : sid;
import retrograde.core.messaging : MessageHandler, MagnitudeMessage;
import retrograde.core.math : Vector3D, scalar, QuaternionD;

import retrograde.components.drone : DroneControllableComponent;
import retrograde.components.animation : TranslatingComponent, SpinningComponent;
import retrograde.components.geometry : Orientation3DComponent, Position3DComponent;

import std.math : PI;

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
 * The drone controller works in conjunction with the SpinningEntityProcessor and
 * TranslatingEntityProcessor to provide actual movement and rotation. As such all entities need
 * to have the following components:
 * - DroneControllableComponent
 * - SpinningComponent
 * - TranslatingComponent
 * - Orientation3DComponent
 * - Position3DComponent
 *
 * And the aforementioned processors need to be active.
 */
class DroneControllerProcessor : EntityProcessor {
    private MessageHandler messageHandler;
    private const defaultRotationSpeedFactor = (2 * PI) / 100;

    this(MessageHandler messageHandler) {
        this.messageHandler = messageHandler;
    }

    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!DroneControllableComponent;
    }

    public override void update() {
        //TODO: Make translation dependent on rotation
        bool receivedPitchUp = false;
        bool receivedPitchDown = false;
        bool receivedYawLeft = false;
        bool receivedYawRight = false;
        bool receivedBankLeft = false;
        bool receivedBankRight = false;

        scalar pitchUp = 0;
        scalar pitchDown = 0;
        scalar yawLeft = 0;
        scalar yawRight = 0;
        scalar bankLeft = 0;
        scalar bankRight = 0;

        messageHandler.receiveMessages(droneChannel, (immutable MagnitudeMessage message) {
            switch (message.id) {
                // case cmdDroneMoveLeft:
                //     receivedXTranslation = true;
                //     newTranslation.x = -message.magnitude;
                //     break;

                // case cmdDroneMoveRight:
                //     receivedXTranslation = true;
                //     newTranslation.x = message.magnitude;
                //     break;

                // case cmdDroneMoveUp:
                //     receivedYTranslation = true;
                //     newTranslation.y = message.magnitude;
                //     break;

                // case cmdDroneMoveDown:
                //     receivedYTranslation = true;
                //     newTranslation.y = -message.magnitude;
                //     break;

                // case cmdDroneMoveForwards:
                //     receivedZTranslation = true;
                //     newTranslation.z = -message.magnitude;
                //     break;

                // case cmdDroneMoveBackwards:
                //     receivedZTranslation = true;
                //     newTranslation.z = message.magnitude;
                //     break;

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

        if (receivedRotation) {
            foreach (entity; entities) {
                // auto translationSpeedModifier = entity.getFromComponent!DroneControllableComponent(
                //     c => c.translationSpeedModifier, 1);

                // entity.maybeWithComponent!TranslatingComponent((c) {
                //     if (receivedXTranslation) {
                //         c.translation.x = newTranslation.x * translationSpeedModifier;
                //     }

                //     if (receivedYTranslation) {
                //         c.translation.y = newTranslation.y * translationSpeedModifier;
                //     }

                //     if (receivedZTranslation) {
                //         c.translation.z = newTranslation.z * translationSpeedModifier;
                //     }
                // });

                if (!entity.hasComponent!DroneControllableComponent) {
                    continue;
                }

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

                if (receivedRotation) {
                    entity.maybeWithComponent!SpinningComponent((c) {
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
            }
        }
    }

    public static void addExpectedComponents(Entity entity) {
        entity.addComponent!DroneControllableComponent;
        entity.addComponent!SpinningComponent;
        entity.addComponent!TranslatingComponent;
        entity.addComponent!Orientation3DComponent;
        entity.addComponent!Position3DComponent;
    }
}
