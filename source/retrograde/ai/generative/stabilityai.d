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

module retrograde.ai.generative.stabilityai;

import retrograde.core.image : Image;

import retrograde.ai.generative.texttoimage : TextToImageFactory, TextToImageParameters;

import std.exception : enforce;

import poodinis : Inject;

enum ApiFinishReason : string {
    success = "SUCCESS",
    error = "ERROR",
    contentFiltered = "CONTENT_FILTERED"
}

struct ApiResponse {
    uint contentLength;
    string contentType;
    ApiFinishReason finishReason;
    ubyte[] data;
}

interface StabilityAiApi {
    ApiResponse textToImage(string prompt, StabilityTextToImageParameters parameters);
}

version (Have_vibe_d_http) {
    import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse, HTTPMethod;
    import std.conv : to;
    import std.json : JSONValue;
    import std.string : representation;

    class VibeStabilityAiApi : StabilityAiApi {
        ApiResponse textToImage(string prompt, StabilityTextToImageParameters parameters) {
            import std.stdio : writeln; //TEMP
            auto requestJson = createRequestJson(prompt, parameters);

            scope void requester(scope HTTPClientRequest req) {
                req.method = HTTPMethod.POST;
                req.headers["Accept"] = "application/json";
                req.headers["Content-Type"] = "application/json";
                req.headers["Authorization"] = "Bearer " ~ parameters.apiKey;
                req.writeBody(requestJson.representation, "application/json");
            }

            scope void responder(scope HTTPClientResponse res) {
                if (res.statusCode == 200) {
                    //TODO: handle response
                } else {
                    throw new Exception(
                        "POST request to " ~ parameters.apiUrl ~ " failed with status code " ~ res.statusCode
                            .to!string ~ ". Response body: " ~ res.readJson().toString()
                    );

                }
            }

            auto url = parameters.apiUrl ~ "/" ~ parameters.apiVersion ~ "/generation/" ~ parameters.engine ~ "/text-to-image";
            requestHTTP(
                url,
                &requester,
                &responder
            );

            throw new Exception("Not implemented");
        }

        private string createRequestJson(string prompt, StabilityTextToImageParameters parameters) {
            JSONValue json;

            JSONValue[] textPrompts;
            JSONValue promptObj;
            promptObj["text"] = prompt;
            promptObj["weight"] = 1.0;
            textPrompts ~= promptObj;

            json["text_prompts"] = textPrompts;
            json["cfg_scale"] = parameters.cfgScale;
            json["clip_guidance_preset"] = parameters.clipGuidancePreset;
            json["height"] = parameters.height;
            json["width"] = parameters.width;
            json["samples"] = 1;
            json["seed"] = parameters.seed;
            json["steps"] = parameters.steps;

            if (parameters.sampler !is null) {
                json["sampler"] = parameters.sampler;
            }

            return json.toString();
        }
    }
} else {
    class VibeStabilityAiApi : StabilityAiApi {
        private enum requiresLibraryExceptionMessage = "The StabilityAiApi requires the requests library. Please install it with 'dub add requests'. See https://code.dlang.org/packages/requests for more information.";

        this() {
            throw new Exception(requiresLibraryExceptionMessage);
        }

        ApiResponse textToImage(string prompt, StabilityTextToImageParameters parameters) {
            throw new Exception(requiresLibraryExceptionMessage);
        }
    }
}

enum StabilityAiApiVersion : string {
    v1alpha = "v1alpha",
    v1beta = "v1beta"
}

enum StabilityAiApiEngine : string {
    esrganV1X2plus = "esrgan-v1-x2plus",
    stableDiffusionV1 = "stable-diffusion-v1",
    stableDiffusionV15 = "stable-diffusion-v1-5",
    stableDiffusion512V20 = "stable-diffusion-512-v2-0",
    stableDiffusion768V20 = "stable-diffusion-768-v2-0",
    stableDiffusion512V21 = "stable-diffusion-512-v2-1",
    stableDiffusion768V21 = "stable-diffusion-768-v2-1",
    stableInpaintingV10 = "stable-inpainting-v1-0",
    stableInpainting512V20 = "stable-inpainting-512-v2-0"
}

enum ClipGuidancePreset : string {
    fastBlue = "FAST_BLUE",
    fastGreen = "FAST_GREEN",
    none = "NONE",
    simple = "SIMPLE",
    slow = "SLOW",
    slower = "SLOWER",
    slowest = "SLOWEST"
}

enum Sampler : string {
    ddim = "DDIM",
    ddpm = "DDPM",
    kDdpm2m = "K_DDPM_2M",
    kDdpm2sAncestral = "K_DDPM_2S_ANCESTRAL",
    kDpm2 = "K_DPM_2",
    kDpm2Ancestral = "K_DPM_2_ANCESTRAL",
    kEuler = "K_EULER",
    kEulerAncestral = "K_EULER_ANCESTRAL",
    kHeun = "K_HEUN",
    kLms = "K_LMS"
}

/** 
 * Parameters for the stability AI image factory.
 */
class StabilityTextToImageParameters : TextToImageParameters {
    /** 
     * The API URL to use for Stability AI API.
     * Default: https://api.stability.ai
     */
    string apiUrl = "https://api.stability.ai";

    /** 
     * The API key to use for Stability AI API.
     */
    string apiKey;

    /** 
     * The API version to use for Stability AI API.
     * Default: v1beta
     */
    StabilityAiApiVersion apiVersion = StabilityAiApiVersion.v1beta;

    /** 
     * The engine to use for the image generation.
     * Not all engines might be available to all users.
     * Default: stableDiffusion512V21
     */
    StabilityAiApiEngine engine = StabilityAiApiEngine.stableDiffusion512V21;

    /** 
     * How strictly the diffusion process adheres to the prompt text (higher values keep your image closer to your prompt).
     * Default: 7
     */
    uint cfgScale = 7;

    /** 
     * Default: none
     */
    ClipGuidancePreset clipGuidancePreset = ClipGuidancePreset.none;

    /**
     * The width of the generated image.
     * Default: 512
     */
    uint width = 512;

    /**
     * The height of the generated image.
     * Default: 512
     */
    uint height = 512;

    /** 
     * Which sampler to use for the diffusion process. If this value is null the API will automatically select an appropriate sampler.
     * Default: null
     */
    Sampler sampler = null;

    /** 
     * Random noise seed (use 0 for a random seed)
     * Default: 0
     */
    uint seed = 0;

    /** 
     * Number of diffusion steps to run
     * Default: 50
     */
    uint steps = 50;
}

/**
 * Creates images using the Stability AI API.
 */
class StabilityAiTextToImageFactory : TextToImageFactory {
    @Inject
    private StabilityAiApi api;

    private TextToImageParameters _defaultParameters;

    /** 
     * Generate an image using the Stability AI API.
     *
     * Params:
     *   prompt = The prompt text to use for the image generation.
     *   parameters = The parameters to use for the image generation.
     * Throws: Exception if the parameters are of an invalid type.
     * Returns: The generated image.
     */
    Image create(string prompt, TextToImageParameters parameters) {
        StabilityTextToImageParameters stabilityParameters =
            cast(StabilityTextToImageParameters) parameters;

        enforce(stabilityParameters !is null, "Invalid parameters passed to StabilityAiTextToImageFactory, expected type StabilityTextToImageParameters.");
        enforce(stabilityParameters.apiKey !is null, "No API key provided for Stability AI API.");

        auto response = api.textToImage(prompt, stabilityParameters);
        enforce(response.finishReason != ApiFinishReason.error, "Stability AI API returned an error.");

        throw new Exception("Not implemented");
    }

    /** 
     * Generate an image using the Stability AI API.
     * Uses the default parameters.
     *
     * Params:
     *   prompt = The prompt text to use for the image generation.
     * Throws: Exception if the parameters are of an invalid type.
     * Returns: The generated image.
     */
    Image create(string prompt) {
        return create(prompt, _defaultParameters);
    }

    /** 
     * The default parameters to use for the image generation.
     */
    TextToImageParameters defaultParameters() {
        return _defaultParameters;
    }

    /** 
     * Set the default parameters to use for the image generation.
     */
    void defaultParameters(TextToImageParameters parameters) {
        _defaultParameters = parameters;
    }
}

version (unittest) {
    import retrograde.test.util : assertThrownMsg;

    class BogusStabilityTextToImageParameters : TextToImageParameters {
    }

    class StabilityAiApiMock : StabilityAiApi {
        ApiResponse mockResponse;
        string expectedPrompt;
        StabilityTextToImageParameters expectedParameters;

        ApiResponse textToImage(string prompt, StabilityTextToImageParameters parameters) {
            assert(prompt == expectedPrompt);
            assert(parameters is expectedParameters);

            return mockResponse;
        }
    }

    private class TestFixture {
        StabilityAiTextToImageFactory generator;
        StabilityAiApiMock api;

        this() {
            api = new StabilityAiApiMock();
            generator = new StabilityAiTextToImageFactory();
            generator.api = api;
        }
    }

    @("Test stability AI image factory with invalid parameters")
    unittest {
        StabilityAiTextToImageFactory generator = new StabilityAiTextToImageFactory();
        assertThrownMsg("Invalid parameters passed to StabilityAiTextToImageFactory, expected type StabilityTextToImageParameters.", generator
                .create("test", new BogusStabilityTextToImageParameters()));
    }

    @("Test stability AI image factory with missing API key")
    unittest {
        StabilityAiTextToImageFactory generator = new StabilityAiTextToImageFactory();
        auto parameters = new StabilityTextToImageParameters();
        parameters.apiKey = null;
        assertThrownMsg("No API key provided for Stability AI API.", generator.create("test", parameters));
    }

    @("Test stability AI image factory with error as api finish reason")
    unittest {
        TestFixture f = new TestFixture();

        auto parameters = new StabilityTextToImageParameters();
        parameters.apiKey = "test";

        ApiResponse response = ApiResponse();
        response.finishReason = ApiFinishReason.error;
        f.api.mockResponse = response;
        f.api.expectedPrompt = "test";
        f.api.expectedParameters = parameters;

        assertThrownMsg("Stability AI API returned an error.", f.generator.create("test", parameters));
    }
}
