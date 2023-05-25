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

module retrograde.factory.model;

import retrograde.factory.geometry : GeometryFactory;
import retrograde.core.model : Vertex, Model, Mesh, Face, TextureCoordinate;

import poodinis;

class ModelFactory {
    private @Inject GeometryFactory geometryFactory;

    /**
     * Creates a plane model.
     */
    Model createPlaneModel() {
        auto vertices = geometryFactory.createPlaneVertices();
        return createModelFromVertices(vertices);
    }

    Model createCapsuleModel() {
        Vertex[] vertices;
        Face[] faces;
        geometryFactory.createCapsuleVertices(vertices, faces);
        return createModelFromVerticesAndFaces(vertices, faces);
    }

    private Model createModelFromVerticesAndFaces(Vertex[] vertices, Face[] faces) {
        auto textureCoordinates = getTextureCoordinatesFromVertices(vertices);
        auto mesh = new Mesh(vertices, faces, textureCoordinates);
        auto model = new Model([mesh]);
        return model;
    }

    private Model createModelFromVertices(Vertex[] vertices) {
        auto faces = createFacesFromVertices(vertices);
        auto textureCoordinates = getTextureCoordinatesFromVertices(vertices);
        auto mesh = new Mesh(vertices, faces, textureCoordinates);
        auto model = new Model([mesh]);
        return model;
    }

    private Face[] createFacesFromVertices(Vertex[] vertices) {
        Face[] faces;
        for (size_t i = 0; i < vertices.length; i += 3) {
            Face face;
            face.vA = i;
            face.vB = i + 1;
            face.vC = i + 2;
            face.vtA = i;
            face.vtB = i + 1;
            face.vtC = i + 2;
            faces ~= face;
        }

        return faces;
    }

    private TextureCoordinate[] getTextureCoordinatesFromVertices(Vertex[] vertices) {
        TextureCoordinate[] textureCoordinates;
        foreach (vertex; vertices) {
            TextureCoordinate textureCoordinate;
            textureCoordinate.u = vertex.u;
            textureCoordinate.v = vertex.v;
            textureCoordinate.w = vertex.tw;
            textureCoordinates ~= textureCoordinate;
        }

        return textureCoordinates;
    }

}
