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

import retrograde.core.image : Image, ImageLoader;
import retrograde.core.storage : File;

import retrograde.image.png : PngImageLoader;

import retrograde.ai.generative.texttoimage : TextToImageFactory, TextToImageParameters;

import retrograde.http.client.vibe : HttpRequest, post, bearerToken, header, perform, MediaType, HttpResponse,
    HttpStatusCode, toString;

import std.exception : enforce;
import std.conv : to;
import std.json : parseJSON, JSONValue;
import std.base64 : Base64;

import poodinis : Inject;

enum ApiFinishReason : string {
    success = "SUCCESS",
    error = "ERROR",
    contentFiltered = "CONTENT_FILTERED"
}

struct ApiResponse {
    bool isSuccessful;
    ubyte[] data;
    ApiFinishReason finishReason;
    int seed;
}

struct StabilityAiApiConfig {
    /** 
     * The API URL to use for Stability AI API.
     * Default: https://api.stability.ai
     */
    string apiUrl = "https://api.stability.ai";

    /** 
     * The API key to use for Stability AI API.
     * Default: empty string.
     */
    string apiKey;

    /** 
     * The API version to use for Stability AI API.
     * Default: v1
     */
    StabilityAiApiVersion apiVersion = StabilityAiApiVersion.v1;
}

/** 
 * Interface for the Stability AI API to allow for mocking.
 */
interface StabilityAiApi {
    /**
     * Generate an image from a prompt.
     */
    ApiResponse textToImage(string prompt, StabilityTextToImageParameters parameters);

    /** 
     * Set the configuration for the API.
     */
    void apiConfig(StabilityAiApiConfig config);

    /** 
     * Get the configuration for the API.
     */
    StabilityAiApiConfig apiConfig();
}

class StabilityAiApiImpl : StabilityAiApi {
    private StabilityAiApiConfig _config;

    ApiResponse textToImage(string prompt, StabilityTextToImageParameters parameters) {
        validateApiConfig();
        auto url = _config.apiUrl ~ "/" ~ _config.apiVersion ~ "/generation/" ~ parameters.engine ~ "/text-to-image";
        auto requestJson = createRequestJson(prompt, parameters);

        auto response =
            new HttpRequest()
            .post(
                url,
                requestJson,
                MediaType.applicationJson,
            )
            .bearerToken(_config.apiKey)
            .header("Accept", "application/json")
            .perform();

        if (response.statusCode == HttpStatusCode.ok) {
            return createApiResponse(response.bodyContent);
        } else {
            throw new Exception(
                "POST request to " ~ _config.apiUrl ~ " failed with status code " ~
                    response.statusCode.toString ~ ". Response body: " ~ response.bodyContent
            );
        }
    }

    /** 
         * Set the configuration for the API.
         */
    void apiConfig(StabilityAiApiConfig config) {
        _config = config;
    }

    /** 
         * Get the configuration for the API.
         */
    StabilityAiApiConfig apiConfig() {
        return _config;
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

    private ApiResponse createApiResponse(string jsonString) {
        ApiResponse response;
        response.isSuccessful = true;

        auto json = jsonString.parseJSON();
        auto artifact = json["artifacts"][0];
        response.finishReason = parseFinishReason(artifact["finishReason"].get!string);
        response.seed = artifact["seed"].get!uint;
        response.data = Base64.decode(artifact["base64"].get!string);

        return response;
    }

    private ApiFinishReason parseFinishReason(string reason) {
        switch (reason) {
        case "SUCCESS":
            return ApiFinishReason.success;
        case "ERROR":
            return ApiFinishReason.error;
        case "CONTENT_FILTERED":
            return ApiFinishReason.contentFiltered;
        default:
            throw new Exception("Unknown finish reason: " ~ reason);
        }
    }

    private void validateApiConfig() {
        enforce!Exception(_config.apiKey.length > 0, "The Stability AI API key must be set.");
        enforce!Exception(_config.apiUrl.length > 0, "The Stability AI API URL must be set.");
        enforce!Exception(_config.apiVersion.length > 0, "The Stability AI API version must be set.");
    }
}

enum StabilityAiApiVersion : string {
    v1alpha = "v1alpha",
    v1beta = "v1beta",
    v1 = "v1"
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
    private @Inject StabilityAiApi api;
    private @Inject!PngImageLoader ImageLoader imageLoader;

    private TextToImageParameters _defaultParameters = new StabilityTextToImageParameters();

    /**
     * Generate an image using the Stability AI API.
     *
     * Params:
     *   prompt = The prompt text to use for the image generation. It must not be empty.
     *   parameters = The parameters to use for the image generation.
     * Throws: Exception if the parameters are invalid or the prompt is empty.
     * Returns: The generated image.
     */
    Image create(string prompt, TextToImageParameters parameters) {
        enforce(prompt.length > 0, "The prompt must not be empty.");

        StabilityTextToImageParameters stabilityParameters = cast(StabilityTextToImageParameters) parameters;
        checkParams(stabilityParameters);
        auto response = api.textToImage(prompt, stabilityParameters);
        enforce(response.finishReason != ApiFinishReason.error, "Stability AI API returned an error.");
        enforce(response.isSuccessful, "Stability AI API returned an unsuccessful response.");
        return imageLoader.load(response.data);
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

    private void checkParams(const StabilityTextToImageParameters params) const {
        enforce(params !is null, "Invalid parameters passed to StabilityAiTextToImageFactory. Must not be null and of type StabilityTextToImageParameters.");
        enforce(params.width >= 128 && params.height >= 128, "Width and height must be equal or higher than 128");

        const uint area = params.width * params.height;
        if (params.engine == StabilityAiApiEngine.stableDiffusion768V20 ||
            params.engine == StabilityAiApiEngine.stableDiffusion768V21) {
            enforce(area >= 589_824 && area <= 1_048_576,
                "Area must be between 589,824 and 1,048,576 for engine " ~ params.engine);
        } else {
            enforce(area >= 262_144 && area <= 1_048_576,
                "Area must be between 262,144 and 1,048,576 for engine " ~ params.engine);
        }

        enforce(params.width % 64 == 0 && params.height % 64 == 0, "Height and width must be increments of 64");
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
        StabilityAiApiConfig config;

        ApiResponse textToImage(string prompt, StabilityTextToImageParameters parameters) {
            assert(prompt == expectedPrompt);
            assert(parameters is expectedParameters);

            return mockResponse;
        }

        StabilityAiApiConfig apiConfig() {
            return config;
        }

        void apiConfig(StabilityAiApiConfig config) {
            this.config = config;
        }
    }

    class ImageLoaderMock : ImageLoader {
        Image mockImage;

        Image load(File file) {
            return mockImage;
        }

        Image load(const ubyte[] data) {
            return mockImage;
        }
    }

    private class TestFixture {
        StabilityAiTextToImageFactory factory;
        StabilityAiApiMock api;
        ImageLoaderMock imageLoader;

        this() {
            api = new StabilityAiApiMock();
            factory = new StabilityAiTextToImageFactory();
            imageLoader = new ImageLoaderMock();
            factory.api = api;
            factory.imageLoader = imageLoader;
        }
    }

    @("Test stability AI image factory with empty prompt")
    unittest {
        TestFixture f = new TestFixture();
        assertThrownMsg("The prompt must not be empty.", f.factory.create(""));
    }

    @("Test stability AI image factory with invalid parameters")
    unittest {
        TestFixture f = new TestFixture();
        assertThrownMsg("Invalid parameters passed to StabilityAiTextToImageFactory. Must not be null and of type StabilityTextToImageParameters.",
            f.factory.create("test", new BogusStabilityTextToImageParameters()));
    }

    @("Test stability AI image factory with invalid area")
    unittest {
        TestFixture f = new TestFixture();
        StabilityTextToImageParameters parameters = new StabilityTextToImageParameters();
        parameters.width = 128;
        parameters.height = 128;
        assertThrownMsg("Area must be between 262,144 and 1,048,576 for engine stable-diffusion-512-v2-1",
            f.factory.create("test", parameters));
    }

    @("Test stability AI image factory with invalid area with a 768 engine")
    unittest {
        TestFixture f = new TestFixture();
        StabilityTextToImageParameters parameters = new StabilityTextToImageParameters();
        parameters.width = 512;
        parameters.height = 512;
        parameters.engine = StabilityAiApiEngine.stableDiffusion768V20;
        assertThrownMsg("Area must be between 589,824 and 1,048,576 for engine stable-diffusion-768-v2-0",
            f.factory.create("test", parameters));
    }

    @("Test stability AI image factory with height that is not a multiple of 64")
    unittest {
        TestFixture f = new TestFixture();
        StabilityTextToImageParameters parameters = new StabilityTextToImageParameters();
        parameters.width = 512;
        parameters.height = 520;
        assertThrownMsg("Height and width must be increments of 64", f.factory.create("test", parameters));
    }

    @("Test stability AI image factory with width that is not a multiple of 64")
    unittest {
        TestFixture f = new TestFixture();
        StabilityTextToImageParameters parameters = new StabilityTextToImageParameters();
        parameters.width = 520;
        parameters.height = 512;
        assertThrownMsg("Height and width must be increments of 64", f.factory.create("test", parameters));
    }

    @("Test stability AI image factory with height that is too small")
    unittest {
        TestFixture f = new TestFixture();
        StabilityTextToImageParameters parameters = new StabilityTextToImageParameters();
        parameters.width = 9216;
        parameters.height = 64;
        assertThrownMsg("Width and height must be equal or higher than 128", f.factory.create("test", parameters));
    }

    @("Test stability AI image factory with width that is too small")
    unittest {
        TestFixture f = new TestFixture();
        StabilityTextToImageParameters parameters = new StabilityTextToImageParameters();
        parameters.width = 64;
        parameters.height = 9216;
        assertThrownMsg("Width and height must be equal or higher than 128", f.factory.create("test", parameters));
    }

    @("Test stability AI image factory with error as api finish reason")
    unittest {
        TestFixture f = new TestFixture();
        auto parameters = new StabilityTextToImageParameters();

        ApiResponse response = ApiResponse();
        response.finishReason = ApiFinishReason.error;
        f.api.mockResponse = response;
        f.api.expectedPrompt = "test";
        f.api.expectedParameters = parameters;
        assertThrownMsg("Stability AI API returned an error.", f.factory.create("test", parameters));
    }

    @("Test stability AI image factory with unsuccessful response")
    unittest {
        TestFixture f = new TestFixture();
        auto parameters = new StabilityTextToImageParameters();

        ApiResponse response = ApiResponse();
        response.isSuccessful = false;
        f.api.mockResponse = response;
        f.api.expectedPrompt = "test";
        f.api.expectedParameters = parameters;

        assertThrownMsg("Stability AI API returned an unsuccessful response.", f.factory.create("test", parameters));
    }

    @("Test stability AI image factory with successful response")
    unittest {
        TestFixture f = new TestFixture();

        ubyte[] imageData = [1, 2, 3, 4];
        auto expectedImage = new Image();
        expectedImage.data = imageData;
        f.imageLoader.mockImage = expectedImage;
        auto parameters = new StabilityTextToImageParameters();

        ApiResponse response = ApiResponse();
        response.isSuccessful = true;
        response.data = imageData;
        response.finishReason = ApiFinishReason.success;
        response.seed = 1234;

        f.api.mockResponse = response;
        f.api.expectedPrompt = "test";
        f.api.expectedParameters = parameters;

        auto actualImage = f.factory.create("test", parameters);
        assert(actualImage !is null);
        assert(actualImage.data == response.data);
    }
}
