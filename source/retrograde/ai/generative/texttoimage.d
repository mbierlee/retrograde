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

module retrograde.ai.generative.texttoimage;

import retrograde.core.image : Image;

/** 
 * Parameters for generating images using AI.
 */
interface TextToImageParameters {
}

/** 
 * A factory for creating images using AI.
 */
interface TextToImageFactory {
    /**
     * Create an image using AI.
     *
     * Params:
     *  prompt = The prompt to use for generating the image.
     *  parameters = The parameters to use for generating the image.
     *
     * Returns:
     *  The generated image.
     */
    Image create(string prompt, TextToImageParameters parameters);

    /**
     * Create an image using AI.
     * Uses the default parameters.
     *
     * Params:
     *  prompt = The prompt to use for generating the image.
     *
     * Returns:
     *  The generated image.
     */
    Image create(string prompt);

    /** 
     * Get the default generator parameters.
     */
    TextToImageParameters defaultParameters();

    /** 
     * Set the default generator parameters.
     */
    void defaultParameters(TextToImageParameters parameters);
}
