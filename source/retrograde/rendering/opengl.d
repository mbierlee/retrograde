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

module retrograde.rendering.opengl;

version (Have_bindbc_opengl) {
    import retrograde.core.rendering : RenderSystem, Shader, ShaderProgram, ShaderType;
    import retrograde.core.entity : Entity, EntityComponent, EntityComponentIdentity;
    import retrograde.core.platform : Platform;
    import retrograde.core.model : Vertex, Mesh;

    import retrograde.components.rendering : RenderableComponent, DefaultShaderProgramComponent;
    import retrograde.components.geometry : ModelComponent;

    import std.experimental.logger : Logger;
    import std.string : fromStringz, format;
    import std.conv : to;

    import poodinis;

    import bindbc.opengl;

    /**
     * An OpenGL implementation of the render system.
     *
     * This implementation is compatible up to OpenGL 4.6
     */
    class OpenGlRenderSystem : RenderSystem {
        private @Autowire Logger logger;
        private @Autowire Platform platform;
        private @Autowire @OptionalDependency ShaderProgram defaultShaderProgram;
        private @Autowire GLErrorService errorService;

        private @Value("logging.logComponentInitialization") bool logInit;

        private GLfloat[] clearColor = [0.576f, 0.439f, 0.859f, 1.0f];
        private OpenGlShaderProgram defaultOpenGlShaderProgram;

        override public int getContextHintMayor() {
            return 4;
        }

        override public int getContextHintMinor() {
            return 6;
        }

        override public bool acceptsEntity(Entity entity) {
            return entity.hasComponent!RenderableComponent;
        }

        override protected void processAcceptedEntity(Entity entity) {
            entity.maybeWithComponent!ModelComponent((ModelComponent c) {
                GlModelInfo modelInfo;
                foreach (size_t index, const Mesh mesh; c.model.meshes) {
                    Vertex[] vertices;
                    mesh.forEachFace((size_t index, Vertex vertA, Vertex vertB, Vertex vertC) {
                        vertices ~= vertA;
                        vertices ~= vertB;
                        vertices ~= vertC;
                    });

                    GLuint vertexArrayObject;
                    GLuint vertexBufferObject;
                    glCreateVertexArrays(1, &vertexArrayObject);
                    glCreateBuffers(1, &vertexBufferObject);

                    ulong verticesByteSize = Vertex.sizeof * vertices.length;
                    glNamedBufferStorage(vertexBufferObject, verticesByteSize, vertices.ptr, 0);

                    glVertexArrayAttribBinding(vertexArrayObject, 0, 0);
                    glVertexArrayAttribFormat(vertexArrayObject, 0, 4, GL_DOUBLE, GL_FALSE, Vertex
                        .x.offsetof);
                    glEnableVertexArrayAttrib(vertexArrayObject, 0);

                    glVertexArrayVertexBuffer(vertexArrayObject, 0, vertexBufferObject, 0, Vertex
                        .sizeof);

                    GlMeshInfo meshInfo;
                    meshInfo.vertexArrayObject = vertexArrayObject;
                    meshInfo.vertexBufferObject = vertexBufferObject;
                    meshInfo.vertexCount = to!int(vertices.length);
                    modelInfo.meshes ~= meshInfo;

                    errorService.logErrorsIfAny();
                }

                entity.addComponent(new GlModelInfoComponent(modelInfo));
            });
        }

        override protected void processRemovedEntity(Entity entity) {
            entity.maybeWithComponent!GlModelInfoComponent((GlModelInfoComponent c) {
                foreach (GlMeshInfo mesh; c.info.meshes) {
                    glDeleteVertexArrays(1, &mesh.vertexArrayObject);
                    glDeleteBuffers(1, &mesh.vertexBufferObject);
                }

                entity.removeComponent!GlModelInfoComponent;
            });
        }

        override public void initialize() {
            static bool isCalled = false;
            if (isCalled) {
                return;
            }

            isCalled = true;

            const GLSupport support = loadOpenGL();
            if (support == GLSupport.badLibrary || support == GLSupport.noLibrary) {
                logger.error("Failed to load OpenGL Library.");
                return;
            }

            if (support == GLSupport.noContext) {
                logger.error("No window context was created by the platform. Create it first.");
                return;
            }

            if (logInit && support.gl46) {
                logger.info("OpenGL 4.6 render system initialized.");
            }

            auto viewport = platform.getViewport();
            glViewport(viewport.x, viewport.y, viewport.width, viewport.height);
            glCullFace(GL_BACK);
            glEnable(GL_CULL_FACE);

            initializeDefaultShaderProgram();
        }

        override public void update() {
        }

        override public void draw() {
            glClearBufferfv(GL_COLOR, 0, &clearColor[0]);

            foreach (Entity entity; _entities) {
                if (defaultOpenGlShaderProgram &&
                    entity.hasComponent!DefaultShaderProgramComponent) {
                    glUseProgram(defaultOpenGlShaderProgram.getOpenGlShaderProgram());
                } //TODO: Else use custom shader program

                entity.maybeWithComponent!GlModelInfoComponent((GlModelInfoComponent c) {
                    foreach (GlMeshInfo mesh; c.info.meshes) {
                        glBindVertexArray(mesh.vertexArrayObject);
                        glDrawArrays(GL_TRIANGLES, 0, mesh.vertexCount);
                        glBindVertexArray(0);
                    }
                });
            }
        }

        private void initializeDefaultShaderProgram() {
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
    }

    private struct GlMeshInfo {
        GLuint vertexArrayObject;
        GLuint vertexBufferObject;
        int vertexCount;
    }

    private struct GlModelInfo {
        GlMeshInfo[] meshes;
    }

    private class GlModelInfoComponent : EntityComponent {
        mixin EntityComponentIdentity!"GlModelInfo";

        public GlModelInfo info;

        this() {
        }

        this(GlModelInfo info) {
            this.info = info;
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
        auto vertexShader = new OpenGlShader("vertex",
            import("standard/vertex.glsl"), ShaderType.vertex);
        auto fragmentShader = new OpenGlShader("fragment",
            import("standard/fragment.glsl"), ShaderType.fragment);
        return new OpenGlShaderProgram(vertexShader, fragmentShader);
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
