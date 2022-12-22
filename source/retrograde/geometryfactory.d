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

module retrograde.geometryfactory;

import retrograde.core.model : Vertex;
import retrograde.core.rendering : Color;

/** 
 * Creates geometry, that is vertex and model data.
 */
class GeometryFactory {

    /** 
     * Create vertices for a plane.
     */
    public Vertex[] createPlaneVertices(
        const uint width = 1,
        const uint height = 1,
        const Color vertexColor = Color(1, 1, 1, 1)
    ) {
        double halfWidth = width / 2.0;
        double halfHeight = height / 2.0;

        auto upperLeft = Vertex(
            -halfWidth, halfHeight, 0.0, 1.0,
            vertexColor.r, vertexColor.g, vertexColor.b, vertexColor.a,
            0, 1, 0
        );
        auto lowerLeft = Vertex(
            -halfWidth, -halfHeight, 0.0, 1.0,
            vertexColor.r, vertexColor.g, vertexColor.b, vertexColor.a,
            0, 0, 0
        );
        auto lowerRight = Vertex(
            halfWidth, -halfHeight, 0.0, 1.0,
            vertexColor.r, vertexColor.g, vertexColor.b, vertexColor.a,
            1, 0, 0
        );
        auto upperRight = Vertex(
            halfWidth, halfHeight, 0.0, 1.0,
            vertexColor.r, vertexColor.g, vertexColor.b, vertexColor.a,
            1, 1, 0
        );

        return [
            upperLeft, lowerLeft, upperRight,
            lowerLeft, lowerRight, upperRight,
        ];
    }
}
