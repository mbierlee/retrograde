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

module retrograde.rendering.opengl;

version (Have_bindbc_opengl) {
    import retrograde.core.rendering : RenderSystem, Shader, ShaderProgram, ShaderType;
    import retrograde.core.entity : Entity;
    import retrograde.core.platform : Platform;

    import std.experimental.logger : Logger;
    import std.string : fromStringz;
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

        private @Value("logging.logComponentInitialization") bool logInit;

        private OpenGlShaderProgram testShaderProgram;

        private GLfloat[] clearColor = [0.576f, 0.439f, 0.859f, 1.0f];

        override public int getContextHintMayor() {
            return 4;
        }

        override public int getContextHintMinor() {
            return 6;
        }

        override public bool acceptsEntity(Entity entity) {
            return false;
        }

        override public void initialize() {
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

            // Temp stuff
            auto vertexShader = new OpenGlShader("vertex",
                    import("standard/vertex.glsl"), ShaderType.vertex);
            auto fragmentShader = new OpenGlShader("fragment",
                    import("standard/fragment.glsl"), ShaderType.fragment);
            testShaderProgram = new OpenGlShaderProgram(vertexShader, fragmentShader);
            testShaderProgram.compileShaders();

            if (!vertexShader.isCompiled()) {
                logger.errorf("Compilation errors for vertext shader: \n%s",
                        vertexShader.getCompilationInfo());
            }

            if (!fragmentShader.isCompiled()) {
                logger.errorf("Compilation errors for fragment shader: \n%s",
                        fragmentShader.getCompilationInfo());
            }

            testShaderProgram.linkProgram();
            if (!testShaderProgram.isLinked()) {
                logger.errorf("Link errors for program: \n%s", testShaderProgram.getLinkInfo());
            }

            glCreateVertexArrays(1, &voa);
            glBindVertexArray(voa);
            // ----
        }

        override public void update() {
            xoffset += 0.001;
            yoffset += 0.001;
        }

        override public void draw() {
            //MORE TEMP STUFF
            glClearBufferfv(GL_COLOR, 0, &clearColor[0]);

            glUseProgram(testShaderProgram.getOpenGlShaderProgram());
            glVertexAttrib4f(0, xoffset, yoffset, 0.0f, 0.0f);
            glVertexAttrib4f(1, 0.0f, 1.0f, 0.0f, 1.0f);
            glDrawArrays(GL_TRIANGLES, 0, 3);
            /////////////////////////////////
        }

        ///// TEMP
        GLuint voa;
        GLfloat xoffset = 0;
        GLfloat yoffset = 0;
        ////

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
}
