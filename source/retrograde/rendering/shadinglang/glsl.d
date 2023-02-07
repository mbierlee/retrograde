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

module retrograde.rendering.shadinglang.glsl;

import retrograde.core.rendering : ShaderLib, PreProcessor, BuildContext;

import std.string : indexOf, replaceInPlace;

/** 
 * A GLSL shader library.
 */
class GlslShaderLib : ShaderLib {
    private string shaderSource;

    this(const string name, const string shaderSource) {
        super(name);
        this.shaderSource = shaderSource;
    }
}

/** 
 * GLSL shading language pre-processor that adds additional language features.
 * Acts a lot like a C-preprocessor.
 */
class GlslPreProcessor : PreProcessor {
    /** 
     * Pre-process a given shader.
     * Params:
     *   shaderSource = GLSL shader source code to pre-process.
     *   buildContext = Context from the shader build process.
     * Returns: A possibly modified GLSL shader.
     */
    public string preProcess(const string shaderSource, const ref BuildContext buildContext) {
        return replaceIncludes(shaderSource, buildContext);
    }

    private string replaceIncludes(const string shaderSource, const ref BuildContext buildContext) {
        string modifiedShaderSource = shaderSource;

        bool foundIncludes = false;
        long includeStart = -1;
        while (true) {
            includeStart = modifiedShaderSource.indexOf("#include", includeStart + 1);
            if (includeStart == -1) {
                break;
            }

            long quoteStart = modifiedShaderSource.indexOf('"', includeStart);
            if (quoteStart == -1) {
                break;
            }

            long quoteEnd = modifiedShaderSource.indexOf('"', quoteStart + 1);
            if (quoteStart == -1) {
                break;
            }

            string includeName = modifiedShaderSource[quoteStart + 1 .. quoteEnd];
            auto shaderLib = includeName in buildContext.shaderLibs;
            if (shaderLib is null) {
                throw new Exception(
                    "Failed to include shader '" ~ includeName ~ "'. The shader was not pre-loaded as shader library.");
            }

            GlslShaderLib glslShaderLib = cast(GlslShaderLib)*shaderLib;
            if (glslShaderLib is null) {
                throw new Exception(
                    "Shaderlib '" ~ includeName ~ "' is not an OpenGL GLSL shader.");
            }

            foundIncludes = true;
            modifiedShaderSource.replaceInPlace(includeStart, quoteEnd + 1, glslShaderLib.shaderSource ~ "\n");
        }

        if (foundIncludes) {
            return replaceIncludes(modifiedShaderSource, buildContext);
        } else {
            return modifiedShaderSource;
        }
    }
}

version (unittest) {
    import std.string : strip;

    @("Include shader libs in shader source")
    unittest {
        auto preProcessor = new GlslPreProcessor();
        auto shaderSource = "
            #version 460 core
            #include \"actual_shader.glsl\"
        ";

        auto libs = [
            "actual_shader.glsl": cast(ShaderLib) new GlslShaderLib("actual_shader.glsl", "in vec3 stuff;")
        ];

        auto context = BuildContext(libs);
        auto expectedShaderSource = "
            #version 460 core
            in vec3 stuff;
        ".strip;

        auto actualShaderSource = preProcessor.preProcess(shaderSource, context).strip;
        assert(actualShaderSource == expectedShaderSource);
    }

    @("Include includes in includes")
    unittest {
        auto preProcessor = new GlslPreProcessor();
        auto shaderSource = "#include \"one.glsl\"";

        auto libs = [
            "one.glsl": cast(ShaderLib) new GlslShaderLib("one.glsl", "#include \"two.glsl\""),
            "two.glsl": cast(ShaderLib) new GlslShaderLib("one.glsl", "hi!")
        ];

        auto context = BuildContext(libs);
        auto expectedShaderSource = "hi!";

        auto actualShaderSource = preProcessor.preProcess(shaderSource, context).strip;
        assert(actualShaderSource == expectedShaderSource);
    }
}
