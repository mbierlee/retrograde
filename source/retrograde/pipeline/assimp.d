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

module retrograde.pipeline.assimp;

version(Have_derelict_assimp3) {

import retrograde.file;
import retrograde.geometry;
import retrograde.math;

import std.string;
import std.exception;

import derelict.assimp3.assimp;

class AssimpImportException : Exception {
    mixin basicExceptionCtors;
}

class AssimpSceneImporter {

    public const(aiScene*) importScene(File file) {
        auto scene = aiImportFile(file.fileName.toStringz(), aiProcess_CalcTangentSpace | aiProcess_Triangulate | aiProcess_JoinIdenticalVertices | aiProcess_SortByPType | aiProcess_GenUVCoords | aiProcess_TransformUVCoords);

        if (!scene) {
            auto errorMessage = cast(string) aiGetErrorString().fromStringz();
            throw new AssimpImportException(errorMessage);
        }

        return scene;
    }

    public void releaseImport(const(aiScene*) scene) {
        aiReleaseImport(scene);
    }

}

version(Have_derelict_gl3) {

import retrograde.graphics.threedee.opengl.model;

class ModelCreationException : Exception {
    mixin basicExceptionCtors;
}

class AssimpOpenglModelFactory {

    public OpenGlModel createFromScene(const(aiScene*) scene) {
        Mesh[] meshes;

        foreach(meshIndex; 0 .. scene.mNumMeshes) {
            auto assimpMesh = scene.mMeshes[meshIndex];

            aiColor4D* assimpColorSet;
            if (assimpMesh.mColors[0]) {
                assimpColorSet = cast(aiColor4D*) assimpMesh.mColors[0];
            }

            aiVector3D* assimpTextureCoordinates;
            if (assimpMesh.mTextureCoords[0]) {
                assimpTextureCoordinates = cast(aiVector3D*) assimpMesh.mTextureCoords[0];
            }


            Vertex[] vertices;
            foreach(vertexIndex; 0 .. assimpMesh.mNumVertices) {
                auto assimpVertex = assimpMesh.mVertices[vertexIndex];

                float red = 1;
                float green = 1;
                float blue = 1;
                float alpha = 1;
                if (assimpColorSet) {
                    auto color = assimpColorSet[vertexIndex];
                    red = color.r;
                    green = color.g;
                    blue = color.b;
                    alpha = color.a;
                }

                float u = 0;
                float v = 0;
                if (assimpTextureCoordinates) {
                    u = assimpTextureCoordinates[vertexIndex].x;
                    v = assimpTextureCoordinates[vertexIndex].y;
                }

                vertices ~= Vertex(assimpVertex.x, assimpVertex.y, assimpVertex.z, 1,    red, green, blue, alpha,    u, v);
            }

            Face[] faces;
            foreach(faceIndex; 0 .. assimpMesh.mNumFaces) {
                auto assimpFace = assimpMesh.mFaces[faceIndex];
                if (assimpFace.mNumIndices != 3) {
                    throw new ModelCreationException(format("Face in mesh contains an unexpect amount of indices (expected 3, got %s), is the mesh triangulated?", assimpFace.mNumIndices));
                }

                faces ~= Face(assimpFace.mIndices[0], assimpFace.mIndices[1], assimpFace.mIndices[2]);
            }

            meshes ~= Mesh(cast(immutable Vertex[]) vertices, cast(immutable Face[]) faces);
        }

        return new OpenGlModel(cast(immutable Mesh[]) meshes);
    }

}

} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict OpenGL3. Please add it as dependency to your project.");    
    }
}
} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict Assimp3. Please add it as dependency to your project.");    
    }
}