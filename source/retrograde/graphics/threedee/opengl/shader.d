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

module retrograde.graphics.threedee.opengl.shader;

version(Have_derelict_gl3) {

import retrograde.graphics.core;
import retrograde.file;
import retrograde.math;
import retrograde.graphics.threedee.opengl.uniform;
import retrograde.graphics.threedee.opengl.rendering;
import retrograde.cache;

import std.string;
import std.typecons;
import std.conv;
import std.typecons;
import std.exception;

import derelict.opengl3.gl3;

import poodinis;

class ShaderValidationException : Exception {
    mixin basicExceptionCtors;
}

class OpenGlShader : Shader {
    private static immutable GLuint[ShaderType] shaderTypeMapping;

    private GLuint shader;

    shared static this() {
        shaderTypeMapping = [
            ShaderType.vertexShader: GL_VERTEX_SHADER,
            ShaderType.fragmentShader: GL_FRAGMENT_SHADER,
            ShaderType.geometryShader: GL_GEOMETRY_SHADER,
            ShaderType.tesselationControlShader: GL_TESS_CONTROL_SHADER,
            ShaderType.tesselationEvaluationShader: GL_TESS_EVALUATION_SHADER,
            ShaderType.computeShader: GL_COMPUTE_SHADER
        ];
    }

    this(File shaderFile, ShaderType type) {
        super(shaderFile, type);
    }

    public override void compile() {
        auto shaderSource = toStringz(shaderFile.readAsText());
        uint shaderType = getShaderType();
        shader = glCreateShader(shaderType);
        glShaderSource(shader, 1, &shaderSource, null);
        glCompileShader(shader);
        verifyCompilationSuccess();
    }

    private void verifyCompilationSuccess() {
        GLint compileStatus;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &compileStatus);
        if (compileStatus == GL_FALSE) {
            GLint logSize;
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logSize);
            GLchar[] infoLog = new GLchar[logSize];
            glGetShaderInfoLog(shader, logSize, null, infoLog.ptr);
            throw new ShaderCompilationException(format("Error while compiling OpenGL %s: %s", type, infoLog));
        }
    }

    private uint getShaderType() {
        auto glType = type in shaderTypeMapping;
        if (!glType) {
            throw new ShaderCompilationException("Error while compiling OpenGL shader", new UnsupportedShaderTypeException(type));
        }
        return *glType;
    }

    public override void destroy() {
        glDeleteShader(shader);
    }
}

class OpenGlShaderProgram : ShaderProgram {
    private GLuint _program;
    private bool[UniformBlock] boundUniformBlocks;

    public UniformContainer uniforms = new UniformContainer();
    public UniformBlock[] uniformBlocks;

    public @property GLuint program() {
        return _program;
    }

    this(OpenGlShader[] shaders) {
        super(cast(Shader[]) shaders);
    }

    public override void compile() {
        _program = glCreateProgram();

        foreachGlShader((shader) {
            shader.compile();
            glAttachShader(_program, shader.shader);
        });

        glLinkProgram(_program);
        verifyLinkSuccess();

        foreachGlShader((shader) {
            shader.destroy();
        });

        _isCompiled = true;
    }

    private void foreachGlShader(void delegate(OpenGlShader) fn) {
        foreach (shader; shaders) {
            auto glShader = cast(OpenGlShader) shader;
            if (glShader) {
                fn(glShader);
            }
        }
    }

    public override void use() {
        glUseProgram(program);
        if (uniforms.uniformsAreUpdated) {
            applyDefaultBlockUniformData();
            uniforms.clearUniformsUpdated();
        }
    }

    private void applyDefaultBlockUniformData() {
        foreach (uniform; uniforms.getAll()) {
            if (!uniform.isUpdated) {
                continue;
            }

            GLint location = glGetUniformLocation(program, uniform.name.toStringz);
            if (location == -1) {
                continue;
            }

            if (uniform.type == UniformType.glFloat) {
                glUniform1f(location, cast(GLfloat) uniform.values[0]);
                continue;
            }

            if (uniform.type == UniformType.glDouble) {
                glUniform1d(location, cast(GLdouble) uniform.values[0]);
                continue;
            }

            if (uniform.type == UniformType.glInt) {
                glUniform1i(location, cast(GLint) uniform.values[0]);
                continue;
            }

            if (uniform.type == UniformType.glVec4) {
                auto castedValueArray = to!(GLfloat[])(uniform.values);
                glUniform4fv(location, 1, castedValueArray.ptr);
                continue;
            }

            if (uniform.type == UniformType.glMat4) {
                auto castedValueArray = to!(GLdouble[])(uniform.values);
                glUniformMatrix4dv(location, 1, cast(GLboolean) false, castedValueArray.ptr);
                continue;
            }
        }
    }

    public void validateUniforms() {
        foreach (uniform; uniforms.getAll()) {
            GLint location = glGetUniformLocation(program, uniform.name.toStringz);
            if (location == -1) {
                throw new ShaderValidationException("Uniform '" ~ uniform.name ~ "' is not defined or used in shader program.");
            }
        }
    }

    public void bindUniformBlock(UniformBlock uniformBlock) {
        auto bound = uniformBlock in boundUniformBlocks;
        if (bound is null || *bound != true) {
            auto blockIndex = glGetUniformBlockIndex(program, uniformBlock.blockName.toStringz);
            glUniformBlockBinding(program, blockIndex, uniformBlock.bindingPoint);
            boundUniformBlocks[uniformBlock] = true;
        }
    }

    private void verifyLinkSuccess() {
        GLint linkStatus;
        glGetProgramiv(_program, GL_LINK_STATUS, &linkStatus);
        if (linkStatus == GL_FALSE) {
            GLint logSize;
            glGetProgramiv(_program, GL_INFO_LOG_LENGTH, &logSize);
            GLchar[] infoLog = new GLchar[logSize];
            glGetProgramInfoLog(_program, logSize, null, infoLog.ptr);
            throw new ShaderCompilationException(format("Error while linking OpenGL shader program: %s", infoLog));
        }
    }

    public override void destroy() {
        glDeleteProgram(_program);
    }
}

private alias ShaderSpecTuple = Tuple!(string, "name", ShaderType, "type");

enum DefaultShader : ShaderSpecTuple {
    vertexShader = ShaderSpecTuple("retrograde-vertex-shader.glsl", ShaderType.vertexShader),
    fragmentShader = ShaderSpecTuple("retrograde-fragment-shader.glsl", ShaderType.fragmentShader)
}

alias DefaultShaderCache = Cache!(DefaultShader, OpenGlShader);

class DefaultShaderFactory {

    private string[DefaultShader] shaderSources;
    private DefaultShaderCache shaderCache = new DefaultShaderCache();

    public this() {
        shaderSources[DefaultShader.vertexShader] = import(DefaultShader.vertexShader.name);
        shaderSources[DefaultShader.fragmentShader] = import(DefaultShader.fragmentShader.name);
    }

    public OpenGlShader createShader(DefaultShader shader) {
        return shaderCache.getOrAdd(shader, {
            auto shaderSource = shaderSources[shader];
            return new OpenGlShader(new VirtualTextFile(shaderSource), shader.type);
        });
    }
}

class DefaultShaderProgramFactory : CachedShaderProgramFactory
{

    @Autowire 
    private OpenGlRenderSystem renderer;

    @Autowire 
    private DefaultShaderFactory defaultShaderFactory;

    protected override ShaderProgram create()
    {
        auto vertexShader = defaultShaderFactory.createShader(DefaultShader.vertexShader);
        auto fragmentShader = defaultShaderFactory.createShader(DefaultShader.fragmentShader);
        auto shaderProgram = new OpenGlShaderProgram([vertexShader, fragmentShader]);
        shaderProgram.uniformBlocks = [renderer.retrogradeModelstateBlock];
        return shaderProgram;
    }
}

} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict OpenGL3. Please add it as dependency to your project.");    
    }
}
