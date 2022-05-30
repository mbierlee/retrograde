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
import retrograde.core.math : Vector3D;

import retrograde.components.drone : DroneControllableComponent;
import retrograde.components.animation : TranslatingComponent, SpinningComponent;
import retrograde.components.geometry : Orientation3DComponent, Position3DComponent;

const auto droneChannel = sid("drone_channel");

const auto cmdDroneMoveUp = sid("cmd_drone_move_up");
const auto cmdDroneMoveDown = sid("cmd_drone_move_down");
const auto cmdDroneMoveLeft = sid("cmd_drone_move_left");
const auto cmdDroneMoveRight = sid("cmd_drone_move_right");

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

    this(MessageHandler messageHandler) {
        this.messageHandler = messageHandler;
    }

    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!DroneControllableComponent;
    }

    public override void update() {
        //TODO: Rotation
        auto newTranslation = Vector3D(0);
        bool receivedMessages = false;
        messageHandler.receiveMessages(droneChannel, (immutable MagnitudeMessage message) {
            switch (message.id) {
            case cmdDroneMoveUp:
                receivedMessages = true;
                newTranslation = newTranslation + Vector3D(0, message.magnitude, 0);
                break;

            case cmdDroneMoveDown:
                receivedMessages = true;
                newTranslation = newTranslation + Vector3D(0, -message.magnitude, 0);
                break;

            case cmdDroneMoveLeft:
                receivedMessages = true;
                newTranslation = newTranslation + Vector3D(-message.magnitude, 0, 0);
                break;

            case cmdDroneMoveRight:
                receivedMessages = true;
                newTranslation = newTranslation + Vector3D(message.magnitude, 0, 0);
                break;

            default:
                break;
            }
        });

        if (receivedMessages) {
            foreach (entity; entities) {
                auto translationSpeedModifier = entity.getFromComponent!DroneControllableComponent(
                    c => c.translationSpeedModifier, 1);

                entity.maybeWithComponent!TranslatingComponent((c) {
                    c.translation = newTranslation * translationSpeedModifier;
                });
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
