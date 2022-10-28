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

module retrograde.components.image;

import retrograde.core.entity : EntityComponent, EntityComponentIdentity;
import retrograde.core.image : Image;

/** 
 * An entity component containing a texture for 3D meshes.
 */
class TextureComponent : EntityComponent {
    mixin EntityComponentIdentity!"TextureComponent";

    public Image texture;

    this() {
    }

    this(Image texture) {
        this.texture = texture;
    }
}
