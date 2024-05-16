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

module retrograde.std.dlang;

mixin template CopyConstructors(T) {
    this(ref return scope inout typeof(this) other) {
        static foreach (member; __traits(allMembers, T)) {
            static if (__traits(compiles, mixin("this." ~ member)) &&
                __traits(compiles, mixin("other." ~ member)) &&
                !__traits(isStaticArray, mixin("this." ~ member))) {
                {
                    alias MemberType = __traits(getMember, T, member);
                    static if (!__traits(isVirtualMethod, MemberType) &&
                        !__traits(isAbstractFunction, MemberType) &&
                        !__traits(isStaticFunction, MemberType) &&
                        !__traits(isTemplate, MemberType) &&
                        !is(typeof(MemberType) == function)
                        ) {
                        mixin("this." ~ member ~ " = other." ~ member ~ ";");
                    }
                }
            }

        }
    }

    void opAssign(ref return scope inout typeof(this) other) {
        static foreach (member; __traits(allMembers, T)) {
            static if (__traits(compiles, mixin("this." ~ member)) &&
                __traits(compiles, mixin("other." ~ member)) &&
                !__traits(isStaticArray, mixin("this." ~ member))) {
                {
                    alias MemberType = __traits(getMember, T, member);
                    static if (!__traits(isVirtualMethod, MemberType) &&
                        !__traits(isAbstractFunction, MemberType) &&
                        !__traits(isStaticFunction, MemberType) &&
                        !__traits(isTemplate, MemberType) &&
                        !is(typeof(MemberType) == function)
                        ) {
                        mixin("this." ~ member ~ " = other." ~ member ~ ";");
                    }
                }
            }

        }
    }
}
