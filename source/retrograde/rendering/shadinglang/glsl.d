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
import std.typecons : Tuple, tuple;
import std.range : repeat;
import std.array : join;

private enum Include = "#include";
private enum Define = "#define";
private enum IfDef = "#ifdef";
private enum IfNDef = "#ifndef";
private enum EndIf = "#endif";

private alias DefinitionTuple = Tuple!(long, "startPos", long, "endPos", string, "value");
private alias DefinitionMap = DefinitionTuple[string];

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
        string modifiedShaderSource = shaderSource;
        replaceIncludes(modifiedShaderSource, buildContext);
        auto definitions = findDefines(modifiedShaderSource);
        evaluateIfDefs(modifiedShaderSource, definitions);
        evaluateIfNDefs(modifiedShaderSource, definitions);
        return modifiedShaderSource;
    }

    private void replaceIncludes(ref string shaderSource, const ref BuildContext buildContext) {
        //TODO: support pragma once

        bool foundIncludes = false;
        long includeStart = -1;
        while (true) {
            includeStart = shaderSource.indexOf(Include, includeStart + 1);
            if (includeStart == -1) {
                break;
            }

            long quoteStart = shaderSource.indexOf('"', includeStart);
            if (quoteStart == -1) {
                break;
            }

            long quoteEnd = shaderSource.indexOf('"', quoteStart + 1);
            if (quoteStart == -1) {
                break;
            }

            string includeName = shaderSource[quoteStart + 1 .. quoteEnd];
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
            shaderSource.replaceInPlace(includeStart, quoteEnd + 1, glslShaderLib.shaderSource ~ "\n");
        }

        if (foundIncludes) {
            return replaceIncludes(shaderSource, buildContext);
        }
    }

    private DefinitionMap findDefines(ref string shaderSource) {
        DefinitionMap definitions;
        long defineStart = -1;
        while (true) {
            defineStart = shaderSource.indexOf(Define, defineStart + 1);
            if (defineStart == -1) {
                break;
            }

            long codePos = defineStart + Define.length;
            bool hitNewLine = false;
            string name = parseToken(shaderSource, codePos, hitNewLine);
            string value = hitNewLine ? "" : parseToken(shaderSource, codePos);
            definitions[name] = DefinitionTuple(defineStart, codePos, value);
            long definitionLength = codePos - defineStart;
            shaderSource.replaceInPlace(defineStart, codePos, " ".repeat(definitionLength).join);
        }

        return definitions;
    }

    private void evaluateIfDefs(
        ref string shaderSource,
        const ref DefinitionMap definitions,
        const bool negate = false
    ) {
        string defCheckToken = negate ? IfNDef : IfDef;
        long checkStart = -1;
        while (true) {
            checkStart = shaderSource.indexOf(defCheckToken, checkStart + 1);
            if (checkStart == -1) {
                break;
            }

            long codePos = checkStart + defCheckToken.length;
            string name = parseToken(shaderSource, codePos);

            long endIfStart = shaderSource.indexOf(EndIf, checkStart + 1);
            if (endIfStart == -1) {
                throw new Exception("Unclosed #ifdef block for token'" ~ name ~ "'");
            }

            auto conditionalBody = shaderSource[codePos .. endIfStart];

            //TODO: support else

            //TODO: get from constants in build context

            auto definition = name in definitions;
            bool conditionIsTrue = definition !is null && (*definition).startPos < checkStart;
            if (negate) {
                conditionIsTrue = !conditionIsTrue;
            }

            string replacedBody = conditionIsTrue ? conditionalBody : "";
            shaderSource.replaceInPlace(checkStart, (endIfStart + EndIf.length), replacedBody);
        }
    }

    private void evaluateIfNDefs(
        ref string shaderSource,
        const ref DefinitionMap definitions
    ) {
        evaluateIfDefs(shaderSource, definitions, true);
    }

    private string parseToken(const string shaderSource, ref long codePos) {
        bool dontCare;
        return parseToken(shaderSource, codePos, dontCare);
    }

    private string parseToken(const string shaderSource, ref long codePos, out bool hitNewLine) {
        string token = "";
        while (codePos < shaderSource.length) {
            char chr = shaderSource[codePos++];
            bool isSpace = chr == ' ';
            bool isNewLine = chr == '\n' || chr == '\r';
            if (isSpace || isNewLine) {
                hitNewLine = hitNewLine || isNewLine;
                if (token.length > 0) {
                    break;
                } else {
                    continue;
                }
            }

            token ~= chr;
        }

        return token;
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

    //TODO: add test for when lib does not exist

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

    @("Conditional compilation with ifdef")
    unittest {
        auto preProcessor = new GlslPreProcessor();
        auto shaderSource = "
            #define OH_HI
            #ifdef OH_HI
            hi!
            #endif
            #ifdef BYE
            bye!
            #endif
        ";

        auto context = BuildContext();
        auto expectedShaderSource = "hi!";
        auto actualShaderSource = preProcessor.preProcess(shaderSource, context).strip;
        assert(actualShaderSource == expectedShaderSource);
    }

    // TODO: Add test with unclosed ifdef

    @("Conditional compilation with ifndef")
    unittest {
        auto preProcessor = new GlslPreProcessor();
        auto shaderSource = "
            #define OH_HI
            #ifndef OH_HI
            hi!
            #endif
            #ifndef BYE
            bye!
            #endif
        ";

        auto context = BuildContext();
        auto expectedShaderSource = "bye!";
        auto actualShaderSource = preProcessor.preProcess(shaderSource, context).strip;
        assert(actualShaderSource == expectedShaderSource);
    }
}
