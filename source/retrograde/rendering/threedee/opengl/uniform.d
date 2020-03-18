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

module retrograde.rendering.threedee.opengl.uniform;

version(Have_derelict_gl3) {

import retrograde.math;
import retrograde.rendering.threedee.opengl.shader;
import retrograde.rendering.threedee.opengl.error;

import std.string;
import std.exception;

import derelict.opengl3.gl3;

import poodinis;

enum UniformType {
    glFloat,
    glDouble,
    glInt,
    glVec4,
    glMat4,
    glBool
}

struct Uniform {
    public string name;
    public UniformType type;
    public double[] values;
    public bool isUpdated = true;

    this(string name, UniformType type, double value) {
        enforce(type != UniformType.glVec4, "Uniform constructor taking a single value cannot be used for vector uniforms. See other constructors.");
        enforce(type != UniformType.glMat4, "Uniform constructor taking a single value cannot be used for matrix uniforms. See other constructors.");

        this.name = name;
        this.type = type;
        this.values = [value];
    }

    this(string name, Vector4D vector) {
        this.name = name;
        this.type = UniformType.glVec4;
        this.values = [vector.x, vector.y, vector.z, vector.w];
    }

    this(string name, Matrix4D matrix) {
        this.name = name;
        this.type = UniformType.glMat4;

        for(uint columnIndex = 0; columnIndex < Matrix4D._Columns; columnIndex++) {
            for(uint rowIndex = 0; rowIndex < Matrix4D._Rows; rowIndex++) {
                this.values ~= matrix[rowIndex, columnIndex];
            }
        }
    }

    this(string name, bool boolean) {
        this.name = name;
        this.type = UniformType.glBool;
        this.values = [boolean];
    }
}

class UniformContainer {
    private Uniform[string] uniforms;
    private bool _uniformsAreUpdated;

    public @property bool uniformsAreUpdated() {
        return _uniformsAreUpdated;
    }

    public @property size_t length() {
        return uniforms.length;
    }

    this(Uniform[] uniforms = []) {
        foreach (uniform; uniforms) {
            set(uniform);
        }
    }

    public void set(Uniform uniform) {
        uniforms[uniform.name] = uniform;
        _uniformsAreUpdated = true;
    }

    public Uniform[] getAll() {
        return uniforms.values;
    }

    public string[] getAllNames() {
        return uniforms.keys;
    }

    public Uniform get(string uniformName) {
        return uniforms[uniformName];
    }

    public void clearUniforms() {
        uniforms.clear;
        _uniformsAreUpdated = true;
    }

    public void clearUniformsUpdated() {
        _uniformsAreUpdated = false;
        foreach(uniform; uniforms.byValue()) {
            uniform.isUpdated = false;
        }
    }
}

class UniformBlock {
    public string blockName;
    public UniformBlockLayout layout;

    public bool hasBuffer = false;
    public uint buffer;
    public uint bindingPoint;

    public UniformContainer uniforms;

    this(string blockName, Uniform[] uniforms = [], UniformBlockLayout layout = UniformBlockLayout.sharedLayout) {
        this.blockName = blockName;
        this.layout = layout;
        this.uniforms = new UniformContainer(uniforms);
    }
}

enum UniformBlockLayout {
    std140Layout,
    sharedLayout
//	packedLayout -- Not supported yet
}

interface UniformBlockBuilder {
    void buildData(UniformBlock uniformBlock, OpenGlShaderProgram shaderProgram);
}

class SharedUniformBlockBuilder : UniformBlockBuilder {
    //TODO: Reject packed uniform blocks and make a builder for it
    //TODO: Reject std140 uniform blocks and make a builder for it

    private static uint nextAvailableBindingPoint = 0;

    @Autowire
    private ErrorService errorService;

    public override void buildData(UniformBlock uniformBlock, OpenGlShaderProgram shaderProgram) {
        if (uniformBlock is null || !uniformBlock.uniforms.uniformsAreUpdated) {
            return;
        }

        auto programHandle = shaderProgram.program;
        auto uniformCount = uniformBlock.uniforms.length;
        const(GLchar)*[] uniformNames;
        foreach(uniformName; uniformBlock.uniforms.getAllNames()) {
            uniformNames ~= (uniformBlock.blockName ~ "." ~ uniformName).toStringz;
        }

        GLuint[] uniformIndices = new GLuint[uniformCount];
        glGetUniformIndices(programHandle, uniformCount, uniformNames.ptr, uniformIndices.ptr);

        foreach(index, uniformIndex; uniformIndices) {
            if (uniformIndex == GL_INVALID_INDEX) {
                throw new UniformBlockBuildException(format("Uniform index for uniform block member %s is invalid. Does it exist in the shader?", uniformNames[index]));
            }
        }

        GLint[] uniformOffsets = new GLint[uniformCount];
        GLint[] arrayStrides = new GLint[uniformCount];
        GLint[] matrixStrides = new GLint[uniformCount];
        glGetActiveUniformsiv(programHandle, uniformCount, uniformIndices.ptr, GL_UNIFORM_OFFSET, uniformOffsets.ptr);
        glGetActiveUniformsiv(programHandle, uniformCount, uniformIndices.ptr, GL_UNIFORM_ARRAY_STRIDE, arrayStrides.ptr);
        glGetActiveUniformsiv(programHandle, uniformCount, uniformIndices.ptr, GL_UNIFORM_MATRIX_STRIDE, matrixStrides.ptr);

        GLint blockSize;
        auto blockIndex = glGetUniformBlockIndex(programHandle, uniformBlock.blockName.toStringz);
        glGetActiveUniformBlockiv(programHandle, blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, &blockSize);
        GLubyte[] blockData = new GLubyte[blockSize];

        //TODO: Optimize. Only change what's been updated. Directly stream to GPU buffer.
        foreach(index, uniform; uniformBlock.uniforms.getAll()) {
            ubyte* uniformDataOffset = blockData.ptr + uniformOffsets[index];
            if (uniform.type == UniformType.glFloat) {
                *(cast(float*) uniformDataOffset) = cast(float) uniform.values[0];
            } else if (uniform.type == UniformType.glVec4) {
                (cast(float*) uniformDataOffset)[0] = cast(float) uniform.values[0];
                (cast(float*) uniformDataOffset)[1] = cast(float) uniform.values[1];
                (cast(float*) uniformDataOffset)[2] = cast(float) uniform.values[2];
                (cast(float*) uniformDataOffset)[3] = cast(float) uniform.values[3];
            } else if (uniform.type == UniformType.glMat4) {
                foreach (i; 0 .. 4) {
                    uint offset = matrixStrides[index] * i;
                    foreach (j; 0 .. 4) {
                        *(cast(float*) (uniformDataOffset + offset)) = cast(float) uniform.values[i * 4 + j];
                        offset += float.sizeof;
                    }
                }
            } else if (uniform.type == UniformType.glBool) {
                *(cast(GLboolean*) uniformDataOffset) = cast(GLboolean) uniform.values[0];
            } else {
                throw new UniformBlockBuildException(format("Uniform of type %s not supported in uniform block creation for block %s", uniform.type, uniformBlock.blockName));
            }
        }

        if (uniformBlock.hasBuffer) {
            glNamedBufferSubData(uniformBlock.buffer, 0, blockSize, blockData.ptr);
        } else {
            GLint maxBlockBindings;
            glGetIntegerv(GL_MAX_UNIFORM_BUFFER_BINDINGS, &maxBlockBindings);
            if (nextAvailableBindingPoint > maxBlockBindings) {
                uniformBlock.uniforms.clearUniformsUpdated();
                throw new UniformBlockBuildException(format("No more block bindings available, maximum of %s reached.", maxBlockBindings));
            }

            GLuint buffer;
            glCreateBuffers(1, &buffer);
            glNamedBufferData(buffer, blockSize, blockData.ptr, GL_DYNAMIC_DRAW);
            auto bindingPoint = nextAvailableBindingPoint++;
            glBindBufferBase(GL_UNIFORM_BUFFER, bindingPoint, buffer);

            uniformBlock.buffer = buffer;
            uniformBlock.bindingPoint = bindingPoint;
            uniformBlock.hasBuffer = true;
        }

        errorService.throwOnErrors!UniformBlockBuildException("building uniform block " ~ uniformBlock.blockName);

        uniformBlock.uniforms.clearUniformsUpdated();
    }
}

class UniformBlockBuildException : Exception {
    mixin basicExceptionCtors;
}

} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict OpenGL3. Please add it as dependency to your project.");    
    }
}
