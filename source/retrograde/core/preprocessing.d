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

module retrograde.core.preprocessing;

/** 
 * Super-type for implementing language preprocessors.
 * Typically used in shader languages.
 */
interface Preprocessor {
    string preprocess(const string source, const string[string] libraries);
}

version (Have_preprocessor) {
    public import preprocessor : SourceMap, BuildContext;

    import preprocessor : _preprocess = preprocess, ProcessingResult;

    /**
 * A C-like preprocessor.
 */
    class CPreprocessor : Preprocessor {
        string preprocess(const string source, BuildContext buildCtx) {
            buildCtx.mainSources = [
                "main": source
            ];
            ProcessingResult result = _preprocess(buildCtx);
            return result.sources["main"];
        }

        string preprocess(const string source, const SourceMap libraries) {
            BuildContext buildCtx;
            buildCtx.sources = cast(SourceMap) libraries;
            return preprocess(source, buildCtx);
        }
    }
}
