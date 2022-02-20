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

module retrograde.components.geometry;

import retrograde.core.entity : EntityComponent, EntityComponentIdentity;
import retrograde.core.math : Vector3D, QuaternionD, scalar;
import retrograde.core.model : Model;

/**
 * An entity component representing three-dimensional position in world space.
 */
class Position3DComponent : EntityComponent {
    mixin EntityComponentIdentity!"Position3D";

    /**
     * A three-dimensional position.
     */
    public Vector3D position = Vector3D(0);

    /** 
     * Create a position component at (0,0,0).
     */
    this() {
    }

    /** 
     * Create a position component at the given position.
     */
    this(const Vector3D position) {
        this.position = position;
    }

    /** 
     * Create a position component at the given coordinates.
     */
    this(const scalar x, const scalar y, const scalar z) {
        this.position = Vector3D(x, y, z);
    }
}

/**
 * An entity component representing three-dimensional orientation in world space.
 */
class Orientation3DComponent : EntityComponent {
    mixin EntityComponentIdentity!"Orientation3D";

    /**
     * An orientation in 3D space.
     */
    public QuaternionD orientation;

    /** 
     * Create an orientation without any rotation.
     */
    this() {
    }

    /** 
     * Create an orientation with the given rotation.
     */
    this(const QuaternionD orientation) {
        this.orientation = orientation;
    }
}

/**
 * An entity component representing three-dimensional scale in world space.
 */
class Scale3DComponent : EntityComponent {
    mixin EntityComponentIdentity!"Scale3D";

    /**
     * A three-dimensional scale.
     *
     * Each individual axis is scaled at the given components.
     */
    public Vector3D scale = Vector3D(1);

    /** 
     * Create a scale component without any scaling applied.
     *
     * All components are set to 1.
     */
    this() {
    }

    /** 
     * Create a scale component with the given scale applied.
     */
    this(const Vector3D scale) {
        this.scale = scale;
    }

    /** 
     * Create a scale component with the given scale applied to all components.
     */
    this(const scalar scale) {
        this.scale = Vector3D(scale);
    }

    /** 
     * Create a scale component with the given scale applied to each component.
     */
    this(const scalar xScale, const scalar yScale, const scalar zScale) {
        this.scale = Vector3D(xScale, yScale, zScale);
    }
}

/**
 * An entity component containing 3D model data.
 */
class ModelComponent : EntityComponent {
    mixin EntityComponentIdentity!"Model";

    public Model model;

    this() {
    }

    this(Model model) {
        this.model = model;
    }
}

// Position3DComponent tests
version (unittest) {
    @("Create Position3DComponent")
    unittest {
        auto const componentOne = new Position3DComponent();
        assert(componentOne.position == Vector3D(0, 0, 0));

        auto const expectedVector = Vector3D(1, 2, 3);
        auto const componentTwo = new Position3DComponent(expectedVector);
        assert(componentTwo.position == expectedVector);

        auto const componentThree = new Position3DComponent(5, 6, 7);
        assert(componentThree.position == Vector3D(5, 6, 7));
    }
}

// Orientation3DComponent tests
version (unittest) {
    @("Create Orientation3DComponent")
    unittest {
        auto const componentOne = new Orientation3DComponent();
        assert(componentOne.orientation == QuaternionD());

        auto const expectedQuaternion = QuaternionD(1, 2, 3, 4);
        auto const componentTwo = new Orientation3DComponent(expectedQuaternion);
        assert(componentTwo.orientation == expectedQuaternion);

    }
}

// Scale3DComponent tests
version (unittest) {
    @("Create Scale3DComponent")
    unittest {
        auto const componentOne = new Scale3DComponent();
        assert(componentOne.scale == Vector3D(1, 1, 1));

        auto const componentTwo = new Scale3DComponent(2);
        assert(componentTwo.scale == Vector3D(2, 2, 2));

        auto const componentThree = new Scale3DComponent(7, 8, 9);
        assert(componentThree.scale == Vector3D(7, 8, 9));
    }
}
