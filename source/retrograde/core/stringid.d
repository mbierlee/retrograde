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

module retrograde.core.stringid;

debug (readableStringId) {
    alias StringId = string;
} else {
    alias StringId = uint;
}

/**
 * Create a StringId from the given string.
 * In debug mode stringids are just regular strings,
 * but in release mode they are actually integer hashes.
 */
public pure StringId sid(string idString) {
    debug (readableStringId) {
        return idString;
    } else {
        StringId stringId = 7;
        foreach (char strChar; idString) {
            stringId = (stringId * 31) + cast(StringId) strChar;
        }

        return stringId;
    }
}
