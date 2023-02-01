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

module retrograde.components.rendering;

import retrograde.core.entity : EntityComponent, EntityComponentIdentity;
import retrograde.core.rendering : CameraConfiguration, TextureFilteringMode;
import retrograde.core.model : Model;
import retrograde.core.image : Image;

/**
 * Entities with the RenderableComponent will be rendered by a render system.
 */
class RenderableComponent : EntityComponent {
    mixin EntityComponentIdentity!"RenderableComponent";
}

/**
 * Entities with the CameraComponent are considered cameras.
 *
 * Together with a Position3DComponent and Orientation3DComponent they will determine
 * what the user will see.
 */
class CameraComponent : EntityComponent {
    mixin EntityComponentIdentity!"CameraComponent";

    CameraConfiguration cameraConfiguration;

    this() {
    }

    this(CameraConfiguration cameraConfiguration) {
        this.cameraConfiguration = cameraConfiguration;
    }
}

/**
 * Entities with an ActiveCameraComponent are considered active and
 * will be the ones used to render the view.
 *
 * Typically there is only one camera active. Entities still need to have a CameraComponent 
 * as well or else they are not considered to be cameras.
 */
class ActiveCameraComponent : EntityComponent {
    mixin EntityComponentIdentity!"ActiveCameraComponent";
}

/** 
 * Entities with a RandomFaceColorsComponent will be rendered with their faces given pseudo-random colors.
 *
 * It makes use of vertex colors. The way vertex colors are rendered depends on the used shaders.
 * Some shaders may blend the colors into textures. The entity's name will be used as seed for the random colors,
 * so entities with the same name will produce the same color pattern. This component is particularly handy for 
 * debugging purposes.
 */
class RandomFaceColorsComponent : EntityComponent {
    mixin EntityComponentIdentity!"RandomFaceColorsComponent";
}

/**
 * An entity component containing 3D model data.
 */
class ModelComponent : EntityComponent {
    mixin EntityComponentIdentity!"ModelComponent";

    public Model model;

    /** 
     * Remove the ModelComponent after it has been loaded in video memory.
     * It will be unlinked and, if not being reused, eventually collected by
     * the garbage collector.
     *
     * Whether this is actually done is up to the implementation of the RenderSystem.
     * The GenericRenderSystem honors this option.
     */
    public bool removeWhenLoadedIntoVideoMemory;

    this() {
    }

    this(Model model, bool removeWhenLoadedIntoVideoMemory = false) {
        this.model = model;
    }
}

/** 
 * An entity component containing a texture for 3D meshes or backgrounds.
 */
class TextureComponent : EntityComponent {
    mixin EntityComponentIdentity!"TextureComponent";

    public Image texture;
    public TextureFilteringMode minificationFilteringMode = TextureFilteringMode.globalDefault;
    public TextureFilteringMode magnificationFilteringMode = TextureFilteringMode.globalDefault;
    public bool generateMipMaps = true;

    this() {
    }

    this(Image texture, TextureFilteringMode minificationFilteringMode = TextureFilteringMode.globalDefault,
        TextureFilteringMode magnificationFilteringMode = TextureFilteringMode.globalDefault,
        bool generateMipMaps = true) {
        this.texture = texture;
        this.minificationFilteringMode = minificationFilteringMode;
        this.magnificationFilteringMode = magnificationFilteringMode;
        this.generateMipMaps = generateMipMaps;
    }
}

/** 
 * Renders the entity's TextureComponent as background using an orthographic
 * projections.
 * Backgrounds do not move based on the position of the camera, but can be
 * moved themselves using Position2DComponents. The origin of a background is in
 * the top-left.
 */
class OrthoBackgroundComponent : EntityComponent {
    mixin EntityComponentIdentity!"OrthoBackgroundComponent";
}
