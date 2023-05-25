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

module retrograde.geometryfactory;

import retrograde.core.model : Vertex, Face;
import retrograde.core.rendering : Color;

/** 
 * Creates geometry, that is vertex and model data.
 */
class GeometryFactory {

    /** 
     * Create vertices for a plane.
     */
    Vertex[] createPlaneVertices(
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

    /** 
     * Create vertices for a capsule.
     *
     * Params: 
     *  vertices - The array to store the vertices in.
     *  faces - The array to store the faces in.
     */
    void createCapsuleVertices(out Vertex[] vertices, out Face[] faces) {
        vertices = [
            Vertex(-0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.0, 1.7, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.2, 0.9, 0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.2, 0.9, -0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.2, 0.9, -0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.2, 0.9, 0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.2, 1.3, 0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.2, 1.3, -0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.2, 1.3, -0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.2, 1.3, 0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.2, 0.4, -0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.2, 0.4, -0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.2, 0.4, 0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.2, 0.4, 0.2, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.3, 0.9, -0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.3, 0.9, -0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.3, 1.3, -0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.3, 1.3, -0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.3, 0.4, -0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(0.3, 0.4, -0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.0, 0.9, 0.3, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.0, 0.9, -0.3, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.0, 1.3, 0.3, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.0, 1.3, -0.3, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.0, 0.4, -0.3, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0),
            Vertex(-0.0, 0.4, 0.3, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
        ];

        int[] indices = [
            17, 1, 7,
            23, 1, 8,
            16, 1, 9,
            22, 1, 6,
            9, 20, 12,
            8, 14, 11,
            6, 15, 13,
            0, 18, 10,
            0, 24, 11,
            0, 19, 12,
            0, 25, 13,
            0, 11, 19,
            0, 13, 18,
            20, 6, 2,
            21, 8, 4,
            8, 1, 16,
            6, 1, 17,
            0, 12, 25,
            0, 10, 24,
            15, 7, 3,
            14, 9, 5,
            9, 1, 22,
            7, 1, 23,
            12, 1, 9,
            7, 21, 10,
            12, 5, 9,
            9, 22, 20,
            20, 25, 12,
            11, 4, 8,
            8, 16, 14,
            14, 19, 11,
            13, 2, 6,
            6, 17, 15,
            15, 18, 13,
            13, 25, 20,
            20, 22, 6,
            2, 13, 20,
            11, 24, 21,
            21, 23, 8,
            4, 11, 21,
            10, 18, 15,
            15, 17, 7,
            3, 10, 15,
            12, 19, 14,
            14, 16, 9,
            5, 12, 14,
            12, 0, 1,
            10, 3, 7,
            7, 23, 21,
            21, 24, 10
        ];

        foreach (i; 0 .. indices.length / 3) {
            faces ~= Face(indices[i * 3], indices[i * 3 + 1], indices[i * 3 + 2]);
        }
    }
}
