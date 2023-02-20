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

public import preprocessor : SourceMap;

import preprocessor : _preprocess = preprocess, BuildContext, ProcessingResult;

/** 
 * Super-type for implementing language preprocessors.
 * Typically used in shader languages.
 */
interface Preprocessor {
    string preprocess(const string source, const SourceMap libraries);
}

/**
 * A C-like preprocessor.
 */
class CPreprocessor : Preprocessor {
    string preprocess(const string source, const SourceMap libraries) {
        BuildContext ctx;
        ctx.sources = cast(SourceMap) libraries;
        ctx.mainSources = [
            "main": source
        ];

        ProcessingResult result = _preprocess(ctx);
        return result.sources["main"];
    }
}
