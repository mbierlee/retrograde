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

module retrograde.rendering.threedee.opengl.model;

version(Have_derelict_gl3) {

import retrograde.model;
import retrograde.rendering.threedee.opengl.renderer;
import retrograde.geometry;

import derelict.opengl3.gl3;

class OpenGlMesh {
    public immutable Mesh mesh;
    public GLuint vertexArrayObject;
    public GLuint vertexBufferObject;

    this(immutable Mesh mesh) {
        this.mesh = mesh;
    }
}

class OpenGlModel : Model {

    private OpenGlMesh[] meshes;
    private bool loaded;

    this(immutable Mesh[] meshes) {
        foreach (mesh ; meshes) {
            this.meshes ~= new OpenGlMesh(mesh);
        }
    }

    public override void loadIntoVram() {
        if (isLoadedIntoVram()) {
            throw new ModelLoadException("Cannot load OpenGL model into VRAM: Model has been previously loaded already. Unload model with unloadFromVram first.");
        }

        foreach (openGlMesh ; meshes) {
            // TODO: Optimize: load as actual vertex-face data if possible
            uint totalVertices = openGlMesh.mesh.faces.length * 3;
            Vertex[] vertexData = [];
            foreach(face; openGlMesh.mesh.faces) {
                vertexData ~= openGlMesh.mesh.vertices[face.vertexIndex1];
                vertexData ~= openGlMesh.mesh.vertices[face.vertexIndex2];
                vertexData ~= openGlMesh.mesh.vertices[face.vertexIndex3];
            }

            GLuint vertexArrayObject;
            GLuint vertexBufferObject;

            glCreateVertexArrays(1, &vertexArrayObject);
            glCreateBuffers(1, &vertexBufferObject);

            uint verticesByteSize = Vertex.sizeof * vertexData.length;
            glNamedBufferStorage(vertexBufferObject, verticesByteSize, vertexData.ptr, 0);

            glVertexArrayAttribBinding(vertexArrayObject, 0, 0);
            glVertexArrayAttribFormat(vertexArrayObject, 0, 4, GL_FLOAT, GL_FALSE, Vertex.x.offsetof);
            glEnableVertexArrayAttrib(vertexArrayObject, 0);

            glVertexArrayAttribBinding(vertexArrayObject, 1, 0);
            glVertexArrayAttribFormat(vertexArrayObject, 1, 4, GL_FLOAT, GL_FALSE, Vertex.r.offsetof);
            glEnableVertexArrayAttrib(vertexArrayObject, 1);

            glVertexArrayAttribBinding(vertexArrayObject, 2, 0);
            glVertexArrayAttribFormat(vertexArrayObject, 2, 2, GL_FLOAT, GL_FALSE, Vertex.u.offsetof);
            glEnableVertexArrayAttrib(vertexArrayObject, 2);

            glVertexArrayVertexBuffer(vertexArrayObject, 0, vertexBufferObject, 0, Vertex.sizeof);

            openGlMesh.vertexArrayObject = vertexArrayObject;
            openGlMesh.vertexBufferObject = vertexBufferObject;
        }

        loaded = true;
    }

    public override void unloadFromVram() {
        foreach (openGlMesh ; meshes) {
            glDeleteVertexArrays(1, &openGlMesh.vertexArrayObject);
            glDeleteBuffers(1, &openGlMesh.vertexBufferObject);
            openGlMesh.vertexArrayObject = 0;
            openGlMesh.vertexBufferObject = 0;
        }

        loaded = false;
    }

    public override bool isLoadedIntoVram() {
        return loaded;
    }

    public override void draw() {
        foreach (openGlMesh ; meshes) {
            glBindVertexArray(openGlMesh.vertexArrayObject);
            glDrawArrays(GL_TRIANGLES, 0, openGlMesh.mesh.faces.length * 3);
            glBindVertexArray(0);
        }
    }

}

} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict OpenGL3. Please add it as dependency to your project.");    
    }
}
