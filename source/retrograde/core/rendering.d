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

module retrograde.core.rendering;

import retrograde.core.entity : EntityProcessor, Entity;
import retrograde.core.math : scalar, Matrix4D;
import retrograde.core.platform : Viewport;
import retrograde.core.concept : Version;

import poodinis : Autowire, OptionalDependency;

import std.logger : Logger;

/** 
 * Constant used to indicate that a camera or render viewport should calculate the aspect ratio based on the platform's viewport.
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
 * Filtering mode assigned to textures.
 */
enum TextureFilteringMode {
    /**
     * Selects exact texel color on the texture coordinate.
     * Also known as point filtering.
     */
    nearestNeighbour,

    /** 
     * Interpolates between neighboring texels to select a blended color.
     * Also known as bilinear filtering.
     */
    linear,

    /** 
     * When assigned to a texture, the renderer's default will be used.
     */
    globalDefault
}

/**
 * An abstraction of a renderer that processes entities and
 * draws them on the screen.
 */
abstract class RenderSystem : EntityProcessor {
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

/** 
 * A graphics API used by render systems.
 * These APIs can be platform dependent.
 * Typically they use third-party APIs such as OpenGL,
 * Vulkan, DirectX etc.
 */
interface GraphicsApi {
    public void initialize();

    /**
     * Returns the API's specific version.
     * It could change after initialization.
     */
    public Version getVersion();

    /** 
     * Update the viewport to the given position and dimensions.
     */
    public void updateViewport(const ref Viewport viewport);

    /**
     * Sets the default clear color for the color buffer.
     */
    public void setClearColor(const Color clearColor);

    /**
     * Sets the default texture filtering modes.
     * If TextureFilteringMode.globalDefault is set it is up to the graphics API to 
     * decide what is considered as default.
     *
     * Params: 
     * minificationMode = Mode used when textures are shown smaller than they are.
     * magnificationMode = Mode used when textures are shown bigger than they are.
     */
    public void setDefaultTextureFilteringModes(const TextureFilteringMode minificationMode, const TextureFilteringMode magnificationMode);

    /** 
     * If the API has any buffers, such as color, depth or stencil
     * buffer, clear them to their default state.
     */
    public void clearAllBuffers();

    /**
     * Clears the depth and stencil buffers, if the API supports them.
     */
    public void clearDepthStencilBuffers();

    /** 
     * Loads an entity's model and texture data into memory.
     */
    public void loadIntoMemory(Entity entity);

    /** 
     * Unloads an entity's model and texture data from memory.
     */
    public void unloadFromVideoMemory(Entity entity);

    /**
     * Switches stateful rendering APIs over to use the default model shader in next draw calls.
     */
    public void useDefaultModelShader();

    /**
     * Switches stateful rendering APIs over to use the default background shader in next draw calls.
     */
    public void useDefaultBackgroundShader();

    /** 
     * Draw an entity's model.
     */
    public void drawModel(Entity entity, Matrix4D modelViewProjectionMatrix);

    /** 
     * Draw an entity as an orthographic background.
     */
    public void drawOrthoBackground(Entity entity);
}

/** 
 * A graphics API that doesn't actually do anything.
 * Used as fall-back for when there is no suitable default API
 * available on the target platform.
 */
class NullGraphicsApi : GraphicsApi {
    @Autowire @OptionalDependency Logger logger;

    public void initialize() {
        if (logger) {
            logger.warning("Null Graphics API initialized. Nothing will actually be rendered.");
        }
    }

    public Version getVersion() {
        return Version(0, 0, 0, "NULLAPI");
    }

    public void updateViewport(const ref Viewport viewport) {
    }

    public void setClearColor(const Color clearColor) {
    }

    public void setDefaultTextureFilteringModes(const TextureFilteringMode minificationMode, const TextureFilteringMode magnificationMode) {
    }

    public void clearAllBuffers() {
    }

    public void clearDepthStencilBuffers() {
    }

    public void loadIntoMemory(Entity entity) {
    }

    public void unloadFromVideoMemory(Entity entity) {
    }

    public void useDefaultModelShader() {
    }

    public void useDefaultBackgroundShader() {
    }

    public void drawModel(Entity entity, Matrix4D modelViewProjectionMatrix) {
    }

    public void drawOrthoBackground(Entity entity) {
    }
}

alias Channel = double;

struct Color {
    /// Red
    Channel r;

    /// Green
    Channel g;

    /// Blue
    Channel b;

    /// Alpha
    Channel a;
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
