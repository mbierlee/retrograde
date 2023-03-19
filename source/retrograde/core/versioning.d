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

module retrograde.core.versioning;

import std.regex : regex, matchFirst;
import std.conv : to;
import std.string : empty;
import std.format : format;

/** 
 * A semantic versioning structure.
 */
struct Version {
    int major;
    int minor;
    int patch;
    string preRelease;
    string buildMetadata;

    string toString() const {
        auto versionString = format("%d.%d.%d", major, minor, patch);

        if (preRelease !is null) {
            versionString ~= "-" ~ preRelease;
        }

        if (buildMetadata !is null) {
            versionString ~= "+" ~ buildMetadata;
        }

        return versionString;
    }
}

/** 
 * Parse a semantic version string.
 *
 * @param versionString The version string to parse.
 * @throws Exception if the version string is invalid.
 * @return The parsed version.
 */
Version parseVersion(string versionString) {
    auto pattern = regex(r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)(?:-(?P<preRelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+(?P<buildMetadata>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$");
    auto match = matchFirst(versionString, pattern);

    if (match.empty) {
        throw new Exception("Invalid version string: " ~ versionString);
    }

    return Version(
        match["major"].to!int,
        match["minor"].to!int,
        match["patch"].to!int,
        match["preRelease"].empty ? null : match["preRelease"],
        match["buildMetadata"].empty ? null : match["buildMetadata"]
    );
}

version (unittest) {
    @("Test version parsing")
    unittest {
        auto semVersion = parseVersion("1.2.3");
        assert(semVersion.major == 1);
        assert(semVersion.minor == 2);
        assert(semVersion.patch == 3);
        assert(semVersion.preRelease is null);
        assert(semVersion.buildMetadata is null);

        semVersion = parseVersion("1.2.3-alpha");
        assert(semVersion.major == 1);
        assert(semVersion.minor == 2);
        assert(semVersion.patch == 3);
        assert(semVersion.preRelease == "alpha");
        assert(semVersion.buildMetadata is null);

        semVersion = parseVersion("1.2.3-alpha+build");
        assert(semVersion.major == 1);
        assert(semVersion.minor == 2);
        assert(semVersion.patch == 3);
        assert(semVersion.preRelease == "alpha");
        assert(semVersion.buildMetadata == "build");

        semVersion = parseVersion("1.2.3+build");
        assert(semVersion.major == 1);
        assert(semVersion.minor == 2);
        assert(semVersion.patch == 3);
        assert(semVersion.preRelease is null);
        assert(semVersion.buildMetadata == "build");
    }

    @("Test version string conversion")
    unittest {
        auto semVersion = Version(1, 2, 3);
        assert(semVersion.toString() == "1.2.3");

        semVersion = Version(1, 2, 3, "alpha");
        assert(semVersion.toString() == "1.2.3-alpha");

        semVersion = Version(1, 2, 3, "alpha", "build");
        assert(semVersion.toString() == "1.2.3-alpha+build");

        semVersion = Version(1, 2, 3, null, "build");
        assert(semVersion.toString() == "1.2.3+build");
    }
}
