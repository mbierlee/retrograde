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

module retrograde.entityfactory.camera;

import retrograde.core.entity : Entity, EntityFactory, EntityFactoryParameters, ofType;
import retrograde.core.rendering : CameraConfiguration;

import retrograde.components.rendering : CameraComponent, ActiveCameraComponent;

import std.typecons : No;

class CameraEntityFactoryParameters : EntityFactoryParameters {
    CameraConfiguration cameraConfiguration;
    bool isActive;
}

/** 
 * Creates a camera entity used by renderers.
 */
class CameraEntityFactory : EntityFactory {
    public override void addComponents(Entity entity, const EntityFactoryParameters parameters = new CameraEntityFactoryParameters()) {
        auto p = parameters.ofType!CameraEntityFactoryParameters;

        entity.maybeAddComponent(new CameraComponent(p.cameraConfiguration));
        if (p.isActive) {
            entity.maybeAddComponent!ActiveCameraComponent;
        }
    }
}
