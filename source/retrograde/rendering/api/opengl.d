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

module retrograde.rendering.api.opengl;

version (Have_bindbc_opengl) {
    import retrograde.core.rendering : GraphicsApi, Shader, ShaderLib, ShaderProgram, ShaderType, Color,
        TextureFilteringMode, RenderOutput, CameraConfiguration, PreProcessor, BuildContext;
    import retrograde.core.platform : Viewport;
    import retrograde.core.entity : Entity, EntityComponent, EntityComponentIdentity;
    import retrograde.core.model : Vertex, Mesh, Face, VertexIndex, TextureCoordinateIndex;
    import retrograde.core.stringid : sid;
    import retrograde.core.math : Matrix4D;
    import retrograde.core.concept : Version;
    import retrograde.core.image : Image, ColorDepth;

    import retrograde.components.rendering : RandomFaceColorsComponent, ModelComponent, OrthoBackgroundComponent,
        TextureComponent, DepthMapComponent;

    import retrograde.geometryfactory : GeometryFactory;

    import retrograde.rendering.shadinglang.glsl : GlslShaderLib, GlslPreProcessor;

    import poodinis : Autowire, Value, OptionalDependency;

    import std.logger : Logger;
    import std.conv : to;
    import std.string : fromStringz, format;
    import std.random : Random, uniform01;

    import bindbc.opengl;

    class OpenGlGraphicsApi : GraphicsApi {
        private @Autowire Logger logger;
        private @Autowire GLErrorService errorService;
        private @Autowire GeometryFactory geometryFactory;
        private @Autowire GlslPreProcessor glslPreProcessor;

        private OpenGlShaderProgram defaultBackgroundShaderProgram;
        private OpenGlShaderProgram defaultModelShaderProgram;

        private @Value("logging.logComponentInitialization") bool logInit;

        private GLfloat[] clearColor = [0.0f, 0.0f, 0.0f, 1.0f];
        private GLenum defaultMinTextureFilteringMode = GL_LINEAR;
        private GLenum defaultMagTextureFilteringMode = GL_LINEAR;
        private Version glVersion = Version(4, 6, 0);
        private RenderOutput renderOutput;

        //TODO: reorder these. It's a mess. Also find a more refined way.
        private static const uint standardPositionAttribLocation = 0;
        private static const uint standardColorAttribLocation = 1;
        private static const uint standardMvpUniformLocation = 2;
        private static const uint standardHasTextureUniformLocation = 3;
        private static const uint standardAlbedoSamplerUniformLocation = 4;
        private static const uint standardTextureCoordsAttribLocation = 5;
        private static const uint standardRenderDepthBufferAttribLocation = 6;
        private static const uint standardHasDepthMapUniformLocation = 7;
        private static const uint standardDepthMapSamplerUniformLocation = 8;
        private static const uint standardNearClippingUniformLocation = 9;
        private static const uint standardFarClippingUniformLocation = 10;

        private static const uint standardAlbedoTextureUnit = 0;
        private static const uint standardDepthMapTextureUnit = 1;

        public void initialize() {
            const GLSupport support = loadOpenGL();
            if (support == GLSupport.badLibrary || support == GLSupport.noLibrary) {
                logger.error("Failed to load OpenGL Library.");
                return;
            }

            if (support == GLSupport.noContext) {
                logger.error("No window context was created by the platform. It must be created before the OpenGL API is initialized.");
                return;
            }

            GLint major, minor;
            glGetIntegerv(GL_MAJOR_VERSION, &major);
            glGetIntegerv(GL_MINOR_VERSION, &minor);
            glVersion = Version(major, minor);

            if (logInit) {
                auto glVersionString = glGetString(GL_VERSION).fromStringz;
                logger.info("OpenGL graphics API initialized (" ~ glVersionString ~ ")");
            }

            glCullFace(GL_BACK);
            glEnable(GL_CULL_FACE);

            glDepthFunc(GL_LEQUAL);
            glEnable(GL_DEPTH_TEST);

            initializeDefaultShaders();
            clearAllBuffers();
        }

        public Version getVersion() {
            return glVersion;
        }

        public void updateViewport(const ref Viewport viewport) {
            glViewport(viewport.x, viewport.y, viewport.width, viewport.height);
        }

        public void setClearColor(const Color clearColor) {
            this.clearColor = [
                clearColor.r, clearColor.g, clearColor.b, clearColor.a
            ];
        }

        public void setDefaultTextureFilteringModes(const TextureFilteringMode minificationMode, const TextureFilteringMode magnificationMode) {
            defaultMinTextureFilteringMode = getGlMinTextureFilteringMode(minificationMode);
            defaultMagTextureFilteringMode = getGlMagTextureFilteringMode(magnificationMode);
        }

        public void startFrame() {
            clearAllBuffers();
        }

        public void loadIntoMemory(Entity entity) {
            if (entity.hasComponent!GlModelInfoComponent) {
                return;
            }

            GlModelInfo modelInfo;

            entity.maybeWithComponent!TextureComponent((c) {
                GLuint texture;
                glCreateTextures(GL_TEXTURE_2D, 1, &texture);
                createTextureStorage(texture, c.texture);
                modelInfo.texture = texture;

                modelInfo.minFiltering = c.minificationFilteringMode == TextureFilteringMode.globalDefault ? defaultMinTextureFilteringMode : getGlMinTextureFilteringMode(
                    c.minificationFilteringMode);
                modelInfo.magFiltering = c.magnificationFilteringMode == TextureFilteringMode.globalDefault ? defaultMagTextureFilteringMode : getGlMagTextureFilteringMode(
                    c.magnificationFilteringMode);

                if (c.generateMipMaps) {
                    glGenerateTextureMipmap(texture);
                }
            });

            entity.maybeWithComponent!DepthMapComponent((c) {
                GLuint depthMap;
                glCreateTextures(GL_TEXTURE_2D, 1, &depthMap);
                createTextureStorage(depthMap, c.depthMap);
                modelInfo.depthMap = depthMap;
            });

            entity.maybeWithComponent!OrthoBackgroundComponent((c) {
                Vertex[] vertices = geometryFactory.createPlaneVertices(2, 2, Color(1.0, 1.0, 1.0, 1.0));
                modelInfo.meshes ~= createMeshInfo(vertices);
            });

            entity.maybeWithComponent!ModelComponent((c) {
                auto assignRandomFaceColors = entity.hasComponent!RandomFaceColorsComponent;
                Random* random = assignRandomFaceColors ? new Random(sid(entity.name)) : null;

                foreach (const Mesh mesh; c.model.meshes) {
                    Vertex[] vertices;
                    GLuint[] indices;

                    if (assignRandomFaceColors || mesh.textureCoordinates.length > 0) {
                        mesh.forEachFaceVertices((size_t index, Vertex vertA, Vertex vertB, Vertex vertC) {
                            if (assignRandomFaceColors) {
                                auto randomR = uniform01(random);
                                auto randomG = uniform01(random);
                                auto randomB = uniform01(random);

                                vertA.r = vertB.r = vertC.r = randomR;
                                vertA.g = vertB.g = vertC.g = randomG;
                                vertA.b = vertB.b = vertC.b = randomB;
                            }

                            vertices ~= vertA;
                            vertices ~= vertB;
                            vertices ~= vertC;
                        });
                    } else {
                        vertices = cast(Vertex[]) mesh.vertices;
                        foreach (Face face; mesh.faces) {
                            indices ~= face.vA.to!GLuint;
                            indices ~= face.vB.to!GLuint;
                            indices ~= face.vC.to!GLuint;
                        }
                    }

                    modelInfo.meshes ~= createMeshInfo(vertices, indices);
                    errorService.logErrorsIfAny();
                }

                if (random) {
                    random.destroy();
                }
            });

            entity.addComponent(new GlModelInfoComponent(modelInfo));
        }

        public void unloadFromVideoMemory(Entity entity) {
            entity.maybeWithComponent!GlModelInfoComponent((c) {
                foreach (GlMeshInfo mesh; c.info.meshes) {
                    glDeleteBuffers(1, &mesh.vertexBufferObject);
                    glDeleteBuffers(1, &mesh.elementBufferObject);
                    glDeleteVertexArrays(1, &mesh.vertexArrayObject);
                }

                glDeleteTextures(1, &c.info.texture);
                glDeleteTextures(1, &c.info.depthMap);

                entity.removeComponent!GlModelInfoComponent;
            });
        }

        public void useDefaultModelShader() {
            if (defaultModelShaderProgram) {
                glUseProgram(defaultModelShaderProgram.getOpenGlShaderProgram());
            }
        }

        public void useDefaultBackgroundShader() {
            if (defaultBackgroundShaderProgram) {
                glUseProgram(defaultBackgroundShaderProgram.getOpenGlShaderProgram());
            }
        }

        public void drawModel(
            Entity entity,
            const ref Matrix4D modelViewProjectionMatrix,
            const ref CameraConfiguration cameraConfiguration
        ) {
            entity.maybeWithComponent!GlModelInfoComponent((modelInfo) {
                auto modelViewProjectionMatrixData = modelViewProjectionMatrix.getDataArray!float;
                glUniformMatrix4fv(standardMvpUniformLocation, 1, GL_TRUE,
                    modelViewProjectionMatrixData.ptr);

                //TODO: Set at frame start only (needs uniform blocks).
                glUniform1i(standardRenderDepthBufferAttribLocation,
                    renderOutput == RenderOutput.depthBuffer);
                glUniform1f(standardNearClippingUniformLocation,
                    cameraConfiguration.nearClippingDistance);
                glUniform1f(standardFarClippingUniformLocation,
                    cameraConfiguration.farClippingDistance);
                ////

                bindTextureData(modelInfo.info);
                drawMeshes(modelInfo);
            });
        }

        public void drawOrthoBackground(Entity entity) {
            entity.maybeWithComponent!GlModelInfoComponent((modelInfo) {
                glUniform1i(standardRenderDepthBufferAttribLocation,
                    renderOutput == RenderOutput.depthBuffer); //TODO: Set at frame start only (needs uniform blocks).
                bindTextureData(modelInfo.info);
                bindDepthMapData(modelInfo.info);
                drawMeshes(modelInfo);
            });
        }

        public void setRenderOutput(RenderOutput renderOutput) {
            this.renderOutput = renderOutput;
        }

        private void createTextureStorage(const ref GLuint textureName, const ref Image texture) {
            GLenum delegate(uint) internalFormatFunc;
            GLenum pixelFormat;

            if (texture.colorDepth == ColorDepth.bit8) {
                internalFormatFunc = &get8bitGlInternalFormat;
                pixelFormat = GL_UNSIGNED_BYTE;
            } else if (texture.colorDepth == ColorDepth.bit16) {
                internalFormatFunc = &get16bitGlInternalFormat;
                pixelFormat = GL_UNSIGNED_SHORT;
            } else {
                throw new Exception(
                    "Unsupported color depth for texture: " ~ texture.colorDepth.to!string);
            }

            glTextureStorage2D(textureName, 1, internalFormatFunc(texture.channels), texture.width,
                texture.height);
            glTextureSubImage2D(textureName, 0, 0, 0, texture.width, texture.height,
                getGlTextureFormat(texture.channels), pixelFormat, texture.data.ptr);
        }

        private void clearAllBuffers() {
            glClearBufferfv(GL_COLOR, 0, &clearColor[0]);
            glClearBufferfi(GL_DEPTH_STENCIL, 0, 1, 0);
        }

        private void bindTextureData(const ref GlModelInfo modelInfo) {
            bool hasTexture = modelInfo.texture != 0;
            glUniform1i(standardHasTextureUniformLocation, hasTexture);
            glUniform1i(standardAlbedoSamplerUniformLocation, standardAlbedoTextureUnit);
            glBindTextureUnit(standardAlbedoTextureUnit, modelInfo.texture);
            glTextureParameteri(modelInfo.texture, GL_TEXTURE_MIN_FILTER, modelInfo.minFiltering);
            glTextureParameteri(modelInfo.texture, GL_TEXTURE_MAG_FILTER, modelInfo.magFiltering);
        }

        private void bindDepthMapData(const ref GlModelInfo modelInfo) {
            bool hasDepthMap = modelInfo.depthMap != 0;
            glUniform1i(standardHasDepthMapUniformLocation, hasDepthMap);
            glUniform1i(standardDepthMapSamplerUniformLocation, standardDepthMapTextureUnit);
            glBindTextureUnit(standardDepthMapTextureUnit, modelInfo.depthMap);
        }

        private void drawMeshes(GlModelInfoComponent modelInfo) {
            foreach (GlMeshInfo mesh; modelInfo.info.meshes) {
                glBindVertexArray(mesh.vertexArrayObject);
                if (mesh.elementCount > 0) {
                    glDrawElements(GL_TRIANGLES, mesh.elementCount, GL_UNSIGNED_INT, null);
                } else {
                    glDrawArrays(GL_TRIANGLES, 0, mesh.vertexCount);
                }

                glBindVertexArray(0);
            }
        }

        private void initializeDefaultShaders() {
            auto shaderLibs = [
                createShaderLib!"common_fragment"
            ];

            defaultModelShaderProgram = createShaderProgram!"model";
            defaultModelShaderProgram.addShaderLibs(shaderLibs);
            buildShaderProgram(defaultModelShaderProgram);

            defaultBackgroundShaderProgram = createShaderProgram!"background";
            defaultBackgroundShaderProgram.addShaderLibs(shaderLibs);
            buildShaderProgram(defaultBackgroundShaderProgram);
        }

        private ShaderLib createShaderLib(string shaderLibName)() {
            return new GlslShaderLib(shaderLibName ~ ".glsl", import(
                    "standard/lib/" ~ shaderLibName ~ ".glsl"));
        }

        private OpenGlShaderProgram createShaderProgram(string shaderName)() {
            auto vertexShader = new OpenGlShader(shaderName ~ "_vertex", import(
                    "standard/" ~ shaderName ~ "_vertex.glsl"), ShaderType.vertex);
            auto fragmentShader = new OpenGlShader(shaderName ~ "_fragment", import(
                    "standard/" ~ shaderName ~ "_fragment.glsl"), ShaderType.fragment);
            return new OpenGlShaderProgram(vertexShader, fragmentShader);
        }

        private void buildShaderProgram(OpenGlShaderProgram shaderProgram) {
            shaderProgram.preProcessShaders(glslPreProcessor);
            if (!shaderProgram.isPreProcessed) {
                logger.errorf("Failed to pre-process shader program: \n%s", shaderProgram.getPreProcessInfo());
                return;
            }

            shaderProgram.compileShaders();
            shaderProgram.linkProgram();
            if (!shaderProgram.isLinked) {
                logger.errorf("Link errors for shader program: \n%s", shaderProgram.getLinkInfo());
            }
        }

        private GlMeshInfo createMeshInfo(
            const Vertex[] vertices,
            const GLuint[] indices = []
        ) {
            GlMeshInfo meshInfo;
            if (vertices.length == 0) {
                return meshInfo;
            }

            GLuint vertexArrayObject;
            glCreateVertexArrays(1, &vertexArrayObject);

            // Position attrib
            glVertexArrayAttribBinding(vertexArrayObject, standardPositionAttribLocation, 0);
            glVertexArrayAttribFormat(vertexArrayObject, standardPositionAttribLocation, 4, GL_DOUBLE, GL_FALSE, Vertex
                    .x.offsetof);
            glEnableVertexArrayAttrib(vertexArrayObject, standardPositionAttribLocation);

            // Color attrib
            glVertexArrayAttribBinding(vertexArrayObject, standardColorAttribLocation, 0);
            glVertexArrayAttribFormat(vertexArrayObject, standardColorAttribLocation, 4, GL_DOUBLE, GL_FALSE, Vertex
                    .r.offsetof);
            glEnableVertexArrayAttrib(vertexArrayObject, standardColorAttribLocation);

            // Texture coordinates attrib
            glVertexArrayAttribBinding(vertexArrayObject, standardTextureCoordsAttribLocation, 0);
            glVertexArrayAttribFormat(vertexArrayObject, standardTextureCoordsAttribLocation, 3, GL_DOUBLE, GL_FALSE,
                Vertex.u.offsetof);
            glEnableVertexArrayAttrib(vertexArrayObject, standardTextureCoordsAttribLocation);

            // Vertex Buffer Object
            GLuint vertexBufferObject;
            glCreateBuffers(1, &vertexBufferObject);
            ulong verticesByteSize = Vertex.sizeof * vertices.length;
            glNamedBufferStorage(vertexBufferObject, verticesByteSize, vertices.ptr, 0);
            glVertexArrayVertexBuffer(vertexArrayObject, 0, vertexBufferObject, 0, Vertex.sizeof);

            meshInfo.vertexArrayObject = vertexArrayObject;
            meshInfo.vertexBufferObject = vertexBufferObject;
            meshInfo.vertexCount = vertices.length.to!int;

            // Element Buffer Object
            if (indices.length > 0) {
                GLuint elementBufferObject;
                glCreateBuffers(1, &elementBufferObject);
                auto indicesByteSize = GLuint.sizeof * indices.length;
                glNamedBufferStorage(elementBufferObject, indicesByteSize, indices.ptr, 0);
                glVertexArrayElementBuffer(vertexArrayObject, elementBufferObject);
                meshInfo.elementBufferObject = elementBufferObject;
                meshInfo.elementCount = indices.length.to!int;
            }

            return meshInfo;
        }

        private GLenum get8bitGlInternalFormat(uint channels) {
            switch (channels) {
            case 1:
                return GL_R8;
            case 2:
                return GL_RG8;
            case 3:
                return GL_RGB8;
            default:
                return GL_RGBA8;
            }
        }

        private GLenum get16bitGlInternalFormat(uint channels) {
            switch (channels) {
            case 1:
                return GL_R16;
            case 2:
                return GL_RG16;
            case 3:
                return GL_RGB16;
            default:
                return GL_RGBA16;
            }
        }

        private GLenum getGlTextureFormat(uint channels) {
            switch (channels) {
            case 1:
                return GL_RED;
            case 2:
                return GL_RG;
            case 3:
                return GL_RGB;
            default:
                return GL_RGBA;
            }
        }

        private GLenum getGlMinTextureFilteringMode(TextureFilteringMode textureFilteringMode) {
            switch (textureFilteringMode) {
            case TextureFilteringMode.nearestNeighbour:
                return GL_NEAREST_MIPMAP_NEAREST;
            case TextureFilteringMode.linear:
                return GL_LINEAR_MIPMAP_LINEAR;
            default:
                return GL_NEAREST_MIPMAP_NEAREST;
            }
        }

        private GLenum getGlMagTextureFilteringMode(TextureFilteringMode textureFilteringMode) {
            switch (textureFilteringMode) {
            case TextureFilteringMode.nearestNeighbour:
                return GL_NEAREST;
            case TextureFilteringMode.linear:
                return GL_LINEAR;
            default:
                return GL_NEAREST;
            }
        }

    }

    /**
     * OpenGL GLSL shader.
     */
    class OpenGlShader : Shader {
        private static const GLenum[ShaderType] shaderTypeMapping;

        private string shaderSource;
        private GLuint shader;
        private bool _isCompiled;

        this(const string name, const string shaderSource, const ShaderType shaderType) {
            super(name, shaderType);
            this.shaderSource = shaderSource;
        }

        ~this() {
            if (shader) {
                glDeleteShader(shader);
            }
        }

        static this() {
            // dfmt off
            auto shaderTypeMapping = [
                ShaderType.vertex: GL_VERTEX_SHADER,
                ShaderType.fragment: GL_FRAGMENT_SHADER
            ];
            // dfmt on

            static if (useARBComputeShader) {
                shaderTypeMapping[ShaderType.compute] = GL_COMPUTE_SHADER;
            }

            static if (useARBTesselationShader) {
                shaderTypeMapping[ShaderType.tesselationControl] = GL_TESS_CONTROL_SHADER;
                shaderTypeMapping[ShaderType.tesselationEvaluation] = GL_TESS_EVALUATION_SHADER;
            }

            static if (glSupport >= GLSupport.gl32) {
                shaderTypeMapping[ShaderType.geometry] = GL_GEOMETRY_SHADER;
            }

            this.shaderTypeMapping = shaderTypeMapping;
        }

        override public void preProcess(const PreProcessor preProcessor, const ref BuildContext buildContext) {
            GlslPreProcessor glslPreProcessor = cast(GlslPreProcessor) preProcessor;
            if (glslPreProcessor is null) {
                throw new Exception("Given pre-processor is not a GLSL pre-processor.");
            }

            shaderSource = glslPreProcessor.preProcess(shaderSource, buildContext);
        }

        override public void compile() {
            if (!shader) {
                _isCompiled = false;
                shader = glCreateShader(getOpenGlShaderType());

                const GLint[1] lengths = [cast(GLint) shaderSource.length];
                const(char)*[1] sources = [shaderSource.ptr];

                glShaderSource(shader, 1, sources.ptr, lengths.ptr);
                glCompileShader(shader);

                GLint compilationStatus;
                glGetShaderiv(shader, GL_COMPILE_STATUS, &compilationStatus);
                _isCompiled = compilationStatus == 1;
            }
        }

        override public string getCompilationInfo() {
            if (!shader) {
                return "";
            }

            GLint logLength;
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
            if (logLength == 0) {
                return "";
            }

            GLchar[] infoLog;
            infoLog.length = logLength;
            glGetShaderInfoLog(shader, logLength, null, &infoLog[0]);

            return to!string(fromStringz(&infoLog[0]));
        }

        override public bool isCompiled() {
            return _isCompiled;
        }

        override public void clean() {
            if (shader) {
                glDeleteShader(shader);
            }
        }

        public GLuint getOpenGlShader() {
            return shader;
        }

        public GLenum getOpenGlShaderType() {
            return shaderTypeMapping[shaderType];
        }
    }

    class OpenGlShaderLib : ShaderLib {
        private string shaderSource;

        this(const string name, const string shaderSource) {
            super(name);
            this.shaderSource = shaderSource;
        }
    }

    /**
     * OpenGL shader program.
     */
    class OpenGlShaderProgram : ShaderProgram {
        private GLuint program;
        private bool _isPreProcessed;
        private bool _isLinked;
        private string preProcessInfo = "";

        this() {
        }

        this(Shader[] shaders...) {
            super(shaders);
        }

        ~this() {
            if (program) {
                glDeleteProgram(program);
            }
        }

        override public void preProcessShaders(PreProcessor preProcessor) {
            try {
                super.preProcessShaders(preProcessor);
                _isPreProcessed = true;
            } catch (Exception e) {
                preProcessInfo = e.msg;
                _isPreProcessed = false;
            }
        }

        override public bool isPreProcessed() {
            return _isPreProcessed;
        }

        override public string getPreProcessInfo() {
            return preProcessInfo;
        }

        override public void linkProgram() {
            if (program) {
                glDeleteProgram(program);
            }

            program = glCreateProgram();
            foreach (shader; shaders) {
                auto glShader = cast(OpenGlShader) shader;
                if (glShader) {
                    glAttachShader(program, glShader.getOpenGlShader());
                }
            }

            glLinkProgram(program);

            GLint linkStatus;
            glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
            _isLinked = linkStatus == 1;
        }

        override public string getLinkInfo() {
            if (!program) {
                return "";
            }

            GLint logLength;
            glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
            if (logLength == 0) {
                return "";
            }

            GLchar[] infoLog;
            infoLog.length = logLength;
            glGetProgramInfoLog(program, logLength, null, &infoLog[0]);

            return to!string(fromStringz(&infoLog[0]));
        }

        override public bool isLinked() {
            return _isLinked;
        }

        override public void clean() {
            if (program) {
                foreach (shader; shaders) {
                    auto glShader = cast(OpenGlShader) shader;
                    if (glShader) {
                        glDetachShader(program, glShader.getOpenGlShader());
                    }
                }

                glDeleteProgram(program);
            }
        }

        public GLuint getOpenGlShaderProgram() {
            return program;
        }
    }

    private struct GlMeshInfo {
        GLuint vertexArrayObject;
        GLuint vertexBufferObject;
        GLuint elementBufferObject;
        int vertexCount;
        int elementCount;
    }

    private struct GlModelInfo {
        GLuint texture;
        GLuint depthMap;
        GLenum minFiltering;
        GLenum magFiltering;
        GlMeshInfo[] meshes;
    }

    private class GlModelInfoComponent : EntityComponent {
        mixin EntityComponentIdentity!"GlModelInfoComponent";

        public GlModelInfo info;

        this() {
        }

        this(GlModelInfo info) {
            this.info = info;
        }
    }

    class GLErrorService {
        private @Autowire Logger logger;

        public GLenum[] getAllErrors() {
            GLenum[] errors;
            while (true) {
                GLenum error = glGetError();
                if (error == GL_NO_ERROR) {
                    break;
                }

                errors ~= error;
            }
            return errors;
        }

        public void throwOnErrors(ExceptionType : Exception)(string action = "") {
            auto errors = getAllErrors();
            auto actionSpecifier = !action.empty ? " while " ~ action : "";
            if (errors.length > 0) {
                throw new ExceptionType(format("OpenGL errors were flagged%s: %s", actionSpecifier, errors));
            }
        }

        public void logErrorsIfAny() {
            auto errors = getAllErrors();
            if (errors.length > 0) {
                logger.error(format("OpenGL errors were flagged: %s", errors));
            }
        }
    }
}
