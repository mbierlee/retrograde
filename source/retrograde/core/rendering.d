/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.rendering;

import retrograde.core.entity : EntityProcessor, Entity;

abstract class Renderer : EntityProcessor {
    /**
     * Desired mayor version of the rendering API to be used.
     *
     * Typically used by the platform to initialize the renderer.
     * E.g. "4" for OpenGL 4.6
     */
    abstract public int getContextHintMayor();

    /**
     * Desired minor version of the rendering API to be used.
     *
     * Typically used by the platform to initialize the renderer.
     * E.g. "6" for OpenGL 4.6
     */
    abstract public int getContextHintMinor();
}

class NullRenderer : Renderer {
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
    abstract public void compile();
    abstract public bool isCompiled();
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
}

version (unittest) {
    class TestShader : Shader {
        public bool _isCompiled = false;

        override public void compile() {
            _isCompiled = true;
        }

        override public bool isCompiled() {
            return _isCompiled;
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
