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

module retrograde.camera;

import retrograde.entity;
import retrograde.math;
import retrograde.input;
import retrograde.messaging;
import retrograde.camera;
import retrograde.stringid;

import std.math;

import poodinis;

class CameraComponent : EntityComponent {
    mixin EntityComponentIdentity!"CameraComponent";
}

class PitchYawComponent : EntityComponent {
    mixin EntityComponentIdentity!"PitchYawComponent";

    public Vector2D pitchYawVector;

    this() {
        this(Vector2D(0));
    }

    this(Vector2D pitchYawVector) {
        this.pitchYawVector = pitchYawVector;
    }
}

class FirstPersonCameraEntityFactory : EntityFactory {
    public const string entityName = "CameraEntity";

    this() {
        super(entityName);
    }

    public override Entity createEntity(CreationParameters parameters = null) {
        auto entity = createBlankEntity();

        entity.addComponent!CameraComponent;
        entity.addComponent!Position3DComponent;
        entity.addComponent!PitchYawComponent;

        return entity;
    }
}

enum CameraRotateCommand : StringId {
    pitch = sid("cmd_camera_rotate_pitch"),
    yaw = sid("cmd_camera_rotate_yaw")
}

enum CameraRotationModeCommand : StringId {
    setMouseLook = sid("cmd_camera_mode_set_mouse_look"),
    setStickLook = sid("cmd_camera_mode_set_stick_look")
}

enum CameraMoveCommand : StringId {
    moveForwardBackward = sid("cmd_camera_move_forward_back"),
    moveSideways = sid("cmd_camera_move_sideways")
}

class FirstPersonCameraProcessor : EntityProcessor {

    private Entity activeCamera;

    private double addedPitch = 0;
    private double addedYaw = 0;
    private double addedMovement = 0;
    private double addedStrafe = 0;
    private CameraRotationModeCommand rotationMode = CameraRotationModeCommand.setMouseLook;
    private const double pitchIncrements = (2 * PI) / 200;
    private const double yawIncrements = pitchIncrements;

    @Autowire
    private MappedInputCommandChannel mappedInputCommandChannel; //TODO: Receive from different channel. Route from mapped command.

    public override void initialize() {
        mappedInputCommandChannel.connect(&handleInputEvent);
    };

    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!CameraComponent && entity.hasComponent!PitchYawComponent;
    }

    public override void processAcceptedEntity(Entity entity) {
        activeCamera = entity;
    }

    public override void update() {
        auto pitchYawComponent = activeCamera.getComponent!PitchYawComponent;
        auto currentPitchYaw = pitchYawComponent.pitchYawVector;

        if ((addedPitch != 0 || addedYaw != 0)) {
            auto newPitchYaw = currentPitchYaw - Vector2D(pitchIncrements * addedPitch, yawIncrements * addedYaw);
            constrainPitchYaw(&newPitchYaw);
            pitchYawComponent.pitchYawVector = newPitchYaw;
            currentPitchYaw = newPitchYaw;

            if (rotationMode == CameraRotationModeCommand.setMouseLook) {
                addedPitch = 0;
                addedYaw = 0;
            }
        }

        if (addedMovement != 0 || addedStrafe) {
            auto sideDirectionVector = radiansToUnitVector(currentPitchYaw.y);
            auto directionVector = radiansToUnitVector(currentPitchYaw.y - PI_2);

            auto positionComponent = activeCamera.getComponent!Position3DComponent;
            auto newPosition = positionComponent.position;

            if (addedMovement != 0) {
                auto translation = Vector3D(directionVector.x, 0, -directionVector.y) * addedMovement;
                newPosition = newPosition + translation;
            }

            if (addedStrafe != 0) {
                auto translation = Vector3D(sideDirectionVector.x, 0, -sideDirectionVector.y) * addedStrafe;
                newPosition = newPosition + translation;
            }

            positionComponent.position = newPosition;
        }
    };

    private void constrainPitchYaw(Vector2D* vector) {
        vector.x = clampPitch(vector.x.wrapAngle);
        vector.y = vector.y.wrapAngle;
    }

    private double clampPitch(double pitch) {
        if (pitch > PI_2 && pitch < TwoPI - PI_2) {
            if (pitch > PI) return TwoPI - PI_2;
            return PI_2;
        }

        return pitch;
    }

    private void handleInputEvent(const(Event) event) {
        switch (event.type) {
            case CameraRotateCommand.pitch:
                if (rotationMode == CameraRotationModeCommand.setStickLook) {
                    addedPitch = event.magnitude;
                } else {
                    addedPitch += event.magnitude;
                }
                break;

            case CameraRotateCommand.yaw:
                if (rotationMode == CameraRotationModeCommand.setStickLook) {
                    addedYaw = event.magnitude;
                } else {
                    addedYaw += event.magnitude;
                }
                break;

            case CameraMoveCommand.moveForwardBackward:
                addedMovement = -event.magnitude;
                break;

            case CameraMoveCommand.moveSideways:
                addedStrafe = event.magnitude;
                break;

            case CameraRotationModeCommand.setMouseLook:
                rotationMode = CameraRotationModeCommand.setMouseLook;
                break;

            case CameraRotationModeCommand.setStickLook:
                rotationMode = CameraRotationModeCommand.setStickLook;
                break;

            default:
                break;
        }
    }

}
