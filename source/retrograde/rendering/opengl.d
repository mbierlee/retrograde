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
    import retrograde.core.rendering : Renderer, Shader, ShaderProgram, ShaderType;
    import retrograde.core.entity : Entity;

    import std.experimental.logger : Logger;

    import poodinis;

    import bindbc.opengl;

    class OpenGlRenderer : Renderer {
        private @Autowire Logger logger;

        private @Value("logging.logComponentInitialization") bool logInit;

        private OpenGlShaderProgram testShaderProgram;

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
            GLSupport support = loadOpenGL();
            if (support == GLSupport.badLibrary || support == GLSupport.noLibrary) {
                logger.error("Failed to load OpenGL Library.");
                return;
            }

            if (support == GLSupport.noContext) {
                logger.error("No window context was created by the platform. Create it first.");
                return;
            }

            if (logInit && support.gl46) {
                logger.info("OpenGL 4.6 renderer initialized.");
            }

            // Temp static creation of shaders
            auto vertexShader = new OpenGlShader(import("standard/vertex.glsl"), ShaderType.vertex);
            auto fragmentShader = new OpenGlShader(import("standard/fragment.glsl"),
                    ShaderType.fragment);
            testShaderProgram = new OpenGlShaderProgram(vertexShader, fragmentShader);
            testShaderProgram.compileShaders();
            testShaderProgram.linkProgram();
            // ----
        }

        override public void draw() {
        }
    }

    class OpenGlShader : Shader {
        private static const GLenum[ShaderType] shaderTypeMapping;

        private immutable string shaderSource;
        private const ShaderType shaderType;
        private GLuint shader;

        this(immutable string shaderSource, const ShaderType shaderType) {
            this.shaderSource = shaderSource;
            this.shaderType = shaderType;
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
                shader = glCreateShader(getOpenGlShaderType());

                const GLint[1] lengths = [cast(GLint) shaderSource.length];
                const(char)*[1] sources = [shaderSource.ptr];

                glShaderSource(shader, 1, sources.ptr, lengths.ptr);
                glCompileShader(shader);
            }
        }

        override public bool isCompiled() {
            return shader != 0;
        }

        public GLuint getOpenGlShader() {
            return shader;
        }

        public GLenum getOpenGlShaderType() {
            return shaderTypeMapping[shaderType];
        }
    }

    class OpenGlShaderProgram : ShaderProgram {
        private GLuint program;

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
        }
    }
}
