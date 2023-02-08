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

module retrograde.entityfactory.rendering;

import retrograde.core.entity : Entity, EntityFactory, EntityFactoryParameters, ofType;
import retrograde.core.storage : StorageSystem;
import retrograde.core.rendering : TextureFilteringMode;
import retrograde.core.image : ColorFormat, ColorDepth;

import retrograde.components.geometry : Position3DComponent, Orientation3DComponent;
import retrograde.components.rendering : RenderableComponent, ModelComponent,
    TextureComponent, OrthoBackgroundComponent, DepthMapComponent;

import retrograde.model : CommonModelLoader;
import retrograde.image : CommonImageLoader;

import poodinis : Autowire;

class ModelEntityFactoryParameters : EntityFactoryParameters {
    string modelFilePath;
    string textureFilePath;
}

/** 
 * Creates entities that are renderable models.
 */
class ModelEntityFactory : EntityFactory {
    @Autowire CommonModelLoader modelLoader;
    @Autowire CommonImageLoader imageLoader;
    @Autowire StorageSystem storage;

    public override void addComponents(Entity entity, const EntityFactoryParameters parameters = new ModelEntityFactoryParameters()) {
        auto p = parameters.ofType!ModelEntityFactoryParameters;

        if (p.modelFilePath.length > 0) {
            auto modelFile = storage.readFileRelative(p.modelFilePath);
            auto model = modelLoader.load(modelFile);
            entity.maybeAddComponent(new ModelComponent(model));
        }

        if (p.textureFilePath.length > 0) {
            auto textureFile = storage.readFileRelative(p.textureFilePath);
            auto texture = imageLoader.load(textureFile);
            entity.maybeAddComponent(new TextureComponent(texture));
        }

        entity.maybeAddComponent!RenderableComponent;
        entity.maybeAddComponent!Position3DComponent;
        entity.maybeAddComponent!Orientation3DComponent;
    }
}

class BackgroundEntityFactoryParameters : EntityFactoryParameters {
    string textureFilePath;
    string depthMapFilePath;
}

/** 
 * Creates entities that are renderable backgrounds.
 */
class BackgroundEntityFactory : EntityFactory {
    @Autowire CommonImageLoader imageLoader;
    @Autowire StorageSystem storage;

    public override void addComponents(Entity entity, const EntityFactoryParameters parameters = new BackgroundEntityFactoryParameters()) {
        auto p = parameters.ofType!BackgroundEntityFactoryParameters;

        if (p.textureFilePath.length > 0) {
            auto textureFile = storage.readFileRelative(p.textureFilePath);
            auto texture = imageLoader.load(textureFile);
            auto component = new TextureComponent(texture);
            component.minificationFilteringMode = TextureFilteringMode.nearestNeighbour;
            component.magnificationFilteringMode = TextureFilteringMode.nearestNeighbour;
            component.generateMipMaps = false;
            entity.maybeAddComponent(component);
        }

        if (p.depthMapFilePath.length > 0) {
            auto depthMapFile = storage.readFileRelative(p.depthMapFilePath);
            auto depthMap = imageLoader.load(depthMapFile);
            auto component = new DepthMapComponent(depthMap);
            entity.maybeAddComponent(component);
        }

        entity.maybeAddComponent!RenderableComponent;
        entity.maybeAddComponent!OrthoBackgroundComponent;
    }
}
