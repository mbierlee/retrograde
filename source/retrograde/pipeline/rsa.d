/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2018 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.pipeline.rsa;

import retrograde.graphics;
import retrograde.file;

import std.json;

class RetrogradeSpritesheetAnimationReader {
    private static const initialAnimationKey = "initialAnimation";

    public SpritesheetAnimation readSpritesheetAnimation(File file) {
        auto jsonText = file.readAsText();
        auto spritesheetAnimationJson = parseJSON(jsonText);
        return composeSpritesheetAnimation(spritesheetAnimationJson);
    }

    private SpritesheetAnimation composeSpritesheetAnimation(JSONValue spritesheetAnimationJson) {
        auto spritesheetAnimation = new SpritesheetAnimation();
        spritesheetAnimation.framesPerSecond = spritesheetAnimationJson["framesPerSecond"].integer;
        spritesheetAnimation.spritesheets = composeSpritesheets(spritesheetAnimationJson["spritesheets"].array);
        spritesheetAnimation.animations = composeAnimations(spritesheetAnimationJson["animations"].array, spritesheetAnimation.spritesheets);
        spritesheetAnimation.initialAnimation = spritesheetAnimation.animations.values[0];
        if (initialAnimationKey in spritesheetAnimationJson) {
            auto initialAnimationName = spritesheetAnimationJson[initialAnimationKey].str;
            spritesheetAnimation.initialAnimation = spritesheetAnimation.animations[initialAnimationName];
        }

        return spritesheetAnimation;
    }

    private Spritesheet[ulong] composeSpritesheets(JSONValue[] spritesheetJsons) {
        Spritesheet[ulong] spriteSheets;
        foreach (spritesheetJson; spritesheetJsons) {
            auto spritesheet = new Spritesheet();
            spritesheet.id = spritesheetJson["id"].integer;
            spritesheet.rows = spritesheetJson["rows"].integer;
            spritesheet.columns = spritesheetJson["columns"].integer;
            spritesheet.fileName = spritesheetJson["fileName"].str;
            spriteSheets[spritesheet.id] = spritesheet;
        }
        return spriteSheets;
    }

    public Animation[string] composeAnimations(JSONValue[] animationJsons, ref const Spritesheet[ulong] spritesheets) {
        Animation[string] animations;
        foreach (animationJson; animationJsons) {
            auto animation = new Animation();
            animation.name = animationJson["name"].str;
            animation.beginFrame = animationJson["begin"].integer;
            animation.endFrame = animationJson["end"].integer;
            animation.spritesheet = cast(Spritesheet) spritesheets[animationJson["spritesheet"].integer];
            animations[animation.name] = animation;
        }
        return animations;
    }
}
