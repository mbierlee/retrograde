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

module retrograde.rendering.api.opengl;

version (Have_bindbc_opengl) {
    import retrograde.core.rendering : GraphicsApi, Shader, ShaderProgram, ShaderType, Color;
    import retrograde.core.platform : Viewport;
    import retrograde.core.entity : Entity, EntityComponent, EntityComponentIdentity;
    import retrograde.core.model : Vertex, Mesh, Face;
    import retrograde.core.stringid : sid;
    import retrograde.core.math : Matrix4D;
    import retrograde.core.concept : Version;

    import retrograde.components.rendering : RandomFaceColorsComponent, ModelComponent, DefaultShaderProgramComponent,
        OrthoBackgroundComponent;

    import poodinis : Autowire, Value, OptionalDependency;

    import std.logger : Logger;
    import std.conv : to;
    import std.string : fromStringz, format;
    import std.random : Random, uniform01;

    import bindbc.opengl;

    class OpenGlGraphicsApi : GraphicsApi {
        private @Autowire Logger logger;
        private @Autowire GLErrorService errorService;

        private @Autowire @OptionalDependency ShaderProgram defaultShaderProgram;

        private @Value("logging.logComponentInitialization") bool logInit;

        private OpenGlShaderProgram defaultOpenGlShaderProgram;
        private GLfloat[] clearColor = [0.0f, 0.0f, 0.0f, 1.0f];
        private Version glVersion = Version(4, 6, 0);

        private static const uint standardPositionAttribLocation = 0;
        private static const uint standardColorAttribLocation = 1;
        private static const uint standardMvpUniformLocation = 2;

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

        public void clearAllBuffers() {
            glClearBufferfv(GL_COLOR, 0, &clearColor[0]);
            clearDepthStencilBuffers();
        }

        public void clearDepthStencilBuffers() {
            glClearBufferfi(GL_DEPTH_STENCIL, 0, 1, 0);
        }

        public void loadIntoMemory(Entity entity) {
            entity.maybeWithComponent!OrthoBackgroundComponent((c) {
                GlModelInfo modelInfo;
                Vertex[] vertices = createVertexPlane();
                modelInfo.meshes ~= createMeshInfo(vertices);
                entity.addComponent(new GlModelInfoComponent(modelInfo));
            });

            entity.maybeWithComponent!ModelComponent((c) {
                auto assignRandomFaceColors = entity.hasComponent!RandomFaceColorsComponent;
                Random* random = assignRandomFaceColors ? new Random(sid(entity.name)) : null;

                GlModelInfo modelInfo;
                foreach (size_t index, const Mesh mesh; c.model.meshes) {
                    Vertex[] vertices;
                    GLuint[] indices;

                    if (assignRandomFaceColors) {
                        mesh.forEachFaceVertices((size_t index, Vertex vertA, Vertex vertB, Vertex vertC) {
                            auto randomR = uniform01(random);
                            auto randomG = uniform01(random);
                            auto randomB = uniform01(random);

                            vertA.r = vertB.r = vertC.r = randomR;
                            vertA.g = vertB.g = vertC.g = randomG;
                            vertA.b = vertB.b = vertC.b = randomB;

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

                entity.addComponent(new GlModelInfoComponent(modelInfo));

                if (random) {
                    random.destroy();
                }
            });
        }

        public void unloadFromVideoMemory(Entity entity) {
            entity.maybeWithComponent!GlModelInfoComponent((c) {
                foreach (GlMeshInfo mesh; c.info.meshes) {
                    glDeleteBuffers(1, &mesh.vertexBufferObject);
                    glDeleteBuffers(1, &mesh.elementBufferObject);
                    glDeleteVertexArrays(1, &mesh.vertexArrayObject);
                }

                entity.removeComponent!GlModelInfoComponent;
            });
        }

        public void drawModel(Entity entity, Matrix4D modelViewProjectionMatrix) {
            entity.maybeWithComponent!GlModelInfoComponent((modelInfo) {
                if (defaultOpenGlShaderProgram
                && entity.hasComponent!DefaultShaderProgramComponent) {
                    glUseProgram(defaultOpenGlShaderProgram.getOpenGlShaderProgram());
                }

                //TODO: Else use custom shader program

                auto modelViewProjectionMatrixData = modelViewProjectionMatrix.getDataArray!float;

                glUniformMatrix4fv(standardMvpUniformLocation, 1, GL_TRUE,
                    modelViewProjectionMatrixData.ptr);

                foreach (GlMeshInfo mesh; modelInfo.info.meshes) {
                    glBindVertexArray(mesh.vertexArrayObject);
                    if (mesh.elementCount > 0) {
                        glDrawElements(GL_TRIANGLES, mesh.elementCount, GL_UNSIGNED_INT, null);
                    } else {
                        glDrawArrays(GL_TRIANGLES, 0, mesh.vertexCount);
                    }

                    glBindVertexArray(0);
                }
            });
        }

        private void initializeDefaultShaders() {
            if (defaultShaderProgram is null) {
                logger.warning("No default shader program is injected into the dependency system. Entities using the default shader program will not be rendered.");
            } else {
                defaultOpenGlShaderProgram = cast(OpenGlShaderProgram) defaultShaderProgram;
                if (!defaultOpenGlShaderProgram) {
                    logger.warning("Default shader program is not an OpenGL shader program. Entities using the default shader program will not be rendered.");
                } else {
                    compileAndLinkShaderProgram(defaultOpenGlShaderProgram);
                }
            }
        }

        private void compileAndLinkShaderProgram(OpenGlShaderProgram shaderProgram) {
            shaderProgram.compileShaders();
            shaderProgram.linkProgram();
            if (!shaderProgram.isLinked()) {
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

        private Vertex[] createVertexPlane() {
            auto upperLeft = Vertex(
                -1.0, 1.0, 0.0, 1.0,
                clearColor[0], clearColor[1], clearColor[2], clearColor[3],
                0, 1, 0
            );
            auto lowerLeft = Vertex(
                -1.0, -1.0, 0.0, 1.0,
                clearColor[0], clearColor[1], clearColor[2], clearColor[3],
                0, 0, 0
            );
            auto lowerRight = Vertex(
                1.0, -1.0, 0.0, 1.0,
                clearColor[0], clearColor[1], clearColor[2], clearColor[3],
                1, 0, 0
            );
            auto upperRight = Vertex(
                1.0, 1.0, 0.0, 1.0,
                clearColor[0], clearColor[1], clearColor[2], clearColor[3],
                1, 1, 0
            );

            return [
                upperLeft, lowerLeft, upperRight,
                lowerLeft, lowerRight, upperRight,
            ];
        }
    }

    /**
     * OpenGL shader.
     *
     * The shader source should be GLSL code.
     */
    class OpenGlShader : Shader {
        private static const GLenum[ShaderType] shaderTypeMapping;

        private const string shaderSource;
        private GLuint shader;
        private bool _isCompiled;

        this(immutable string name, immutable string shaderSource, const ShaderType shaderType) {
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

    /**
     * OpenGL shader program.
     */
    class OpenGlShaderProgram : ShaderProgram {
        private GLuint program;
        private bool _isLinked;

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

    /**
     * Creates a default OpenGL shader program.
     *
     * The default shader program can be reused in a great amount of cases and should support
     * generally all sorts of models.
     */
    public ShaderProgram createDefaultOpenGlShaderProgram() {
        auto vertexShader = new OpenGlShader("vertex", import("standard/vertex.glsl"),
            ShaderType.vertex);
        auto fragmentShader = new OpenGlShader("fragment", import("standard/fragment.glsl"),
            ShaderType.fragment);
        return new OpenGlShaderProgram(vertexShader, fragmentShader);
    }

    private struct GlMeshInfo {
        GLuint vertexArrayObject;
        GLuint vertexBufferObject;
        GLuint elementBufferObject;
        int vertexCount;
        int elementCount;
    }

    private struct GlModelInfo {
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