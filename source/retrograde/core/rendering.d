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
import retrograde.core.math : scalar, Matrix4D, degreesToRadians;
import retrograde.core.platform : Viewport;
import retrograde.core.versioning : Version;
import retrograde.core.preprocessing : Preprocessor;

import poodinis : Inject, OptionalDependency;

import std.logger : Logger;

/** 
 * Constant used to indicate that a camera or render viewport should calculate the aspect ratio based on the platform's viewport.
 */
static const scalar autoAspectRatio = 0;

/** 
 * Type of projection to be used when rendering an active camera.
 */
enum ProjectionType {
    ortographic,
    perspective
}

/** 
 * Render output modes used by render systems / APIs.
 */
enum RenderOutput {
    /// The regular rendering output that outputs all render passes combined.
    composite,

    /// Only render the depth buffers.
    depthBuffer
}

/** 
 * Types of depth testing methods.
 */
enum DepthTestingMode {
    /*
     * The API's default mode.
     * In OpenGL for example this would be quadratic.
     */
    apiDefault,

    /// Depth is equal from the near plane to the far plane.
    linear,

    /// Objects near the near plane are more percisely tested for depth than those further away.
    quadratic
}

/** 
 * Configuration of as 3D camera
 */
struct CameraConfiguration {
    /// Y FOV in radians
    scalar horizontalFieldOfView = degreesToRadians(55);

    /// Aspect ratio (width over height).
    scalar aspectRatio = autoAspectRatio;

    /**
     * Near clipping plane. 
     * Should be higher than 0 in perspective cameras.
     * Use setOrthographicProjectionDefaults to set sensible defaults for ortho projection.
     */
    scalar nearClippingDistance = 0.1;

    /**
     * Far clipping plane. 
     * If 0, it is considered infinite.
     * Note that infinite clipping planes only work in perspective cameras,
     * not orthographic. Use setOrthographicProjectionDefaults to set sensible defaults.
     * Infinite clipping planes will disable the ability to blend with backgrounds, since
     * that feature needs a finite clipping range.
     */
    scalar farClippingDistance = 0;

    /// Type of project of camera
    ProjectionType projectionType = ProjectionType.perspective;

    /// Scaling applied when the projection type is orthographic.
    scalar orthoScale = 1;

    void setOrthographicProjectionDefaults() {
        nearClippingDistance = 0;
        farClippingDistance = 1000;
        projectionType = ProjectionType.ortographic;
    }
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
     * Preprocess the shader if the API supports it.
     * This step typically includes shader libraries.
     */
    abstract void preprocess(Preprocessor preprocessor, const ShaderLib[] shaderLibs);

    /**
     * Compiles the shader if the API allows for such a thing.
     * When a shader is already compiled it might not be recompiled again.
     */
    abstract void compile();

    /**
     * Returns compilation info, such as errors, when the API implementation supports such a thing.
     */
    string getCompilationInfo() {
        return "";
    }

    /**
     * Whether the shader was previously compiled.
     */
    abstract bool isCompiled();

    /**
     * Clean up the shader, such as dealocating it from memory.
     * A shader typically needs to be compiled again after cleaning it.
     */
    abstract void clean();

    ShaderType getShaderType() {
        return shaderType;
    }
}

/** 
 * A shader library that can be included in other shaders via the
 * shader pre-processor.
 */
abstract class ShaderLib {
    const string name;

    this(const string name) {
        this.name = name;
    }
}

/**
 * A complete multi-stage shader program.
 *
 * TODO: Make entity component so that entities can be rendered with different shaders
 */
class ShaderProgram {
    protected Shader[] shaders;
    protected ShaderLib[] shaderLibs;

    this() {
    }

    this(Shader[] shaders...) {
        this.shaders ~= shaders;
    }

    /**
     * Adds a single shader to this shader program.
     */
    void addShader(Shader shader) {
        this.shaders ~= shader;
    }

    /**
     * Adds multiple shaders to this shader program.
     */
    void addShaders(Shader[] shaders) {
        this.shaders ~= shaders;
    }

    /**
     * Adds multiple shaders to this shader program.
     */
    void addShaders(Shader[] shaders...) {
        this.shaders ~= shaders;
    }

    /** 
     * Adds a single shader lib to this program.
     * The lib can be shared and included in multiple shaders.
     */
    void addShaderLib(ShaderLib shaderLib) {
        this.shaderLibs ~= shaderLib;
    }

    /** 
     * Adds multiple shader libs to this program.
     * The libs can be shared and included in multiple shaders.
     */
    void addShaderLibs(ShaderLib[] shaderLibs...) {
        foreach (ShaderLib shaderLib; shaderLibs) {
            addShaderLib(shaderLib);
        }
    }

    /** 
     * Preprocesses all shaders contained in this shader program
     */
    void preprocessShaders(Preprocessor preprocessor) {
        foreach (Shader shader; shaders) {
            shader.preprocess(preprocessor, shaderLibs);
        }
    }

    /** 
     * Whether all shaders are successfully pre-processed.
     */
    bool isPreProcessed() {
        return false;
    }

    /** 
     * Returns info regarding the pre-processing phase.
     */
    string getPreProcessInfo() {
        return "";
    }

    /**
     * Compiles all shaders contained in this shader program.
     */
    void compileShaders() {
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
    void linkProgram() {
    }

    /**
     * Whether the program was successfully linked.
     */
    bool isLinked() {
        return false;
    }

    /**
     * Returns link info, such as errors, when the API implementation supports such a thing.
     */
    string getLinkInfo() {
        return "";
    }

    /**
     * Clean up the program.
     * As a result attached shaders might be cleaned up as well.
     *
     * This does nothing in the generic shader program implementation.
     */
    void clean() {
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
    void initialize();

    /**
     * Returns the API's specific version.
     * It could change after initialization.
     */
    Version getVersion();

    /** 
     * Update the viewport to the given position and dimensions.
     */
    void updateViewport(const ref Viewport viewport);

    /**
     * Sets the default clear color for the color buffer.
     */
    void setClearColor(const Color clearColor);

    /**
     * Sets the default texture filtering modes.
     * If TextureFilteringMode.globalDefault is set it is up to the graphics API to 
     * decide what is considered as default.
     *
     * Params: 
     *  minificationMode = Mode used when textures are shown smaller than they are.
     *  magnificationMode = Mode used when textures are shown bigger than they are.
     */
    void setDefaultTextureFilteringModes(const TextureFilteringMode minificationMode, const TextureFilteringMode magnificationMode);

    /**
     * Prepare for a new frame to be rendered.
     */
    void startFrame();

    /** 
     * Loads an entity's model and texture data into memory.
     */
    void loadIntoMemory(Entity entity);

    /** 
     * Unloads an entity's model and texture data from memory.
     */
    void unloadFromVideoMemory(Entity entity);

    /**
     * Switches stateful rendering APIs over to use the default model shader in next draw calls.
     */
    void useDefaultModelShader();

    /**
     * Switches stateful rendering APIs over to use the default background shader in next draw calls.
     */
    void useDefaultBackgroundShader();

    /**
     * Switches stateful rendering APIs over to use the default foreground shader in next draw calls.
     */
    void useDefaultForegroundShader();

    /** 
     * Draw an entity's model.
     */
    void drawModel(Entity entity, const ref Matrix4D modelViewProjectionMatrix, const ref CameraConfiguration cameraConfiguration);

    /** 
     * Draw an entity as an orthographic background.
     */
    void drawOrthoBackground(Entity entity);

    /** 
     * Draw an entity as an orthographic foreground.
     */
    void drawOrthoForeground(Entity entity);

    /** 
     * Sets the API's render output mode.
     */
    void setRenderOutput(RenderOutput renderOutput);

    /** 
     * Set the depth testing mode used in the API.
     * In some APIs this might be done in shaders and determined while compiling
     * them, so changing this may cause shaders to recompile.
     */
    void setDepthTestingMode(DepthTestingMode depthTestingMode);

    /** 
     * Clears the depth and stencil buffers.
     */
    void clearDepthStencilBuffers();
}

/** 
 * A graphics API that doesn't actually do anything.
 * Used as fall-back for when there is no suitable default API
 * available on the target platform.
 */
class NullGraphicsApi : GraphicsApi {
    private @Inject @OptionalDependency Logger logger;

    void initialize() {
        if (logger) {
            logger.warning("Null Graphics API initialized. Nothing will actually be rendered.");
        }
    }

    Version getVersion() {
        return Version(0, 0, 0, "NULLAPI");
    }

    void updateViewport(const ref Viewport viewport) {
    }

    void setClearColor(const Color clearColor) {
    }

    void setDefaultTextureFilteringModes(const TextureFilteringMode minificationMode, const TextureFilteringMode magnificationMode) {
    }

    void startFrame() {
    }

    void loadIntoMemory(Entity entity) {
    }

    void unloadFromVideoMemory(Entity entity) {
    }

    void useDefaultModelShader() {
    }

    void useDefaultBackgroundShader() {
    }

    void useDefaultForegroundShader() {
    }

    void drawModel(Entity entity, const ref Matrix4D modelViewProjectionMatrix, const ref CameraConfiguration cameraConfiguration) {
    }

    void drawOrthoBackground(Entity entity) {
    }

    void drawOrthoForeground(Entity entity) {
    }

    void setRenderOutput(RenderOutput renderOutput) {
    }

    void setDepthTestingMode(DepthTestingMode depthTestingMode) {
    }

    void clearDepthStencilBuffers() {
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
        bool _isCompiled = false;
        bool _isPreProcessed = false;
        bool _hasTestShaderLib = false;

        this() {
            super("testshader", ShaderType.unknown);
        }

        override void preprocess(Preprocessor preprocessor, const ShaderLib[] shaderLibs) {
            _isPreProcessed = true;
            foreach (const ShaderLib lib; shaderLibs) {
                _hasTestShaderLib = _hasTestShaderLib || lib.name == "testshaderlib";
            }
        }

        override void compile() {
            _isCompiled = true;
        }

        override bool isCompiled() {
            return _isCompiled;
        }

        override void clean() {
        }
    }

    class TestShaderLib : ShaderLib {
        this() {
            super("testshaderlib");
        }
    }

    class TestPreprocessor : Preprocessor {
        string preprocess(const string source, const string[string] libraries) {
            return "hi!";
        }
    }

    @("ShaderProgram compiles shaders")
    unittest {
        auto shader = new TestShader();
        auto program = new ShaderProgram(shader);
        program.compileShaders();

        assert(program.shaders.length == 1);
        assert(shader.isCompiled);
    }

    @("ShaderProgram pre-processes shaders")
    unittest {
        auto shader = new TestShader();
        auto shaderLib = new TestShaderLib();
        auto program = new ShaderProgram(shader);
        program.addShaderLib(shaderLib);
        program.preprocessShaders(new TestPreprocessor());

        assert(shader._isPreProcessed);
        assert(shader._hasTestShaderLib);
    }
}
