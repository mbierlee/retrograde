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

module retrograde.core.rendering;

import retrograde.core.entity : EntityProcessor, Entity;
import retrograde.core.math : scalar;

/** 
 * Constant used to indicate that a camera should calculate the aspect ratio based on the viewport.
 */
public static const scalar autoAspectRatio = 0;

/** 
 * Type of projection to be used when rendering an active camera.
 */
enum ProjectionType {
    ortographic,
    perspective
}

/** 
 * Configuration of as 3D camera
 */
struct CameraConfiguration {
    scalar horizontalFieldOfView = 45;
    scalar aspectRatio = autoAspectRatio;
    scalar nearClippingDistance = 0.1;
    scalar farClippingDistance = 1000;
    ProjectionType projectionType = ProjectionType.perspective;
    scalar orthoScale = 1;
}

/**
 * An abstraction of a render API that processes entities and
 * draws them on the screen.
 */
abstract class RenderSystem : EntityProcessor {
    /**
     * Desired mayor version of the rendering API to be used.
     *
     * Typically used by the platform to initialize the render system.
     * E.g. "4" for OpenGL 4.6
     */
    abstract public int getContextHintMayor();

    /**
     * Desired minor version of the rendering API to be used.
     *
     * Typically used by the platform to initialize the render system.
     * E.g. "6" for OpenGL 4.6
     */
    abstract public int getContextHintMinor();
}

/**
 * A fall-back render system that doesn't actually render anything.
 */
class NullRenderSystem : RenderSystem {
    override public bool acceptsEntity(Entity entity) {
        return false;
    }

    override public int getContextHintMayor() {
        return 0;
    }

    override public int getContextHintMinor() {
        return 0;
    }
}

/**
 * A generic single stage of a shader program.
 */
abstract class Shader {
    protected const string name;
    protected const ShaderType shaderType;

    this(const string name, const ShaderType shaderType = ShaderType.unknown) {
        this.name = name;
        this.shaderType = shaderType;
    }

    /**
     * Compiles the shader if the API allows for such a thing.
     * When a shader is already compiled it might not be recompiled again.
     */
    abstract public void compile();

    /**
     * Returns compilation info, such as errors, when the API implementation supports such a thing.
     */
    public string getCompilationInfo() {
        return "";
    }

    /**
     * Whether the shader was previously compiled.
     */
    abstract public bool isCompiled();

    /**
     * Clean up the shader, such as dealocating it from memory.
     * A shader typically needs to be compiled again after cleaning it.
     */
    abstract public void clean();

    public ShaderType getShaderType() {
        return shaderType;
    }
}

/**
 * A complete multi-stage shader program.
 *
 * TODO: Make entity component so that entities can be rendered with different shaders
 */
class ShaderProgram {
    protected Shader[] shaders;

    this() {
    }

    this(Shader[] shaders...) {
        addShaders(shaders);
    }

    /**
     * Adds a single shader to this shader program.
     */
    public void addShader(Shader shader) {
        this.shaders ~= shader;
    }

    /**
     * Adds multiple shaders to this shader program.
     */
    public void addShaders(Shader[] shaders) {
        this.shaders ~= shaders;
    }

    /**
     * Adds multiple shaders to this shader program.
     */
    public void addShaders(Shader[] shaders...) {
        this.shaders ~= shaders;
    }

    /**
     * Compiles all shaders contained in this shader program.
     */
    public void compileShaders() {
        foreach (Shader shader; shaders) {
            shader.compile();
        }
    }

    /**
     * Links all compiled shaders into a single program.
     *
     * The generic shader program implementation does nothing, but specific
     * implementations might actually link.
     */
    public void linkProgram() {
    }

    /**
     * Whether the program was successfully linked.
     */
    public bool isLinked() {
        return false;
    }

    /**
     * Returns link info, such as errors, when the API implementation supports such a thing.
     */
    public string getLinkInfo() {
        return "";
    }

    /**
     * Clean up the program.
     * As a result attached shaders might be cleaned up as well.
     *
     * This does nothing in the generic shader program implementation.
     */
    public void clean() {
    }
}

/**
 * Enum used to indicate which type of shader a certain shader is.
 *
 * Availability of types may vary across rendering APIs and versions.
 */
enum ShaderType {
    unknown,
    compute,
    vertex,
    tesselationControl,
    tesselationEvaluation,
    geometry,
    fragment
}

version (unittest) {
    class TestShader : Shader {
        public bool _isCompiled = false;

        this() {
            super("testshader", ShaderType.unknown);
        }

        override public void compile() {
            _isCompiled = true;
        }

        override public bool isCompiled() {
            return _isCompiled;
        }

        override public void clean() {
        }
    }

    @("ShaderProgram compiles shaders")
    unittest {
        auto shader = new TestShader();
        auto program = new ShaderProgram(shader);
        program.compileShaders();

        assert(program.shaders.length == 1);
        assert(shader.isCompiled());
    }
}
