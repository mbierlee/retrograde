/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.std.dlang;

/**
 * Swaps every field of two values of the same struct type.
 *
 * This is the move-assignment primitive for the hand-rolled containers: instead of
 * releasing our own state and then stealing the source's, the two trade places. The
 * moved-from value is left holding a fully valid container rather than a hollowed-out
 * one, so it stays destructible by construction and its destructor is what releases
 * the state we just replaced.
 *
 * Only meant for structs whose fields are pointers and integers; a field that is
 * itself a value type with a copy constructor would be copied, not swapped.
 *
 * Params:
 *  left = one of the two values to swap.
 *  right = the other value to swap.
 */
void swapFields(T)(ref T left, ref T right) {
    static foreach (i, FieldType; typeof(T.tupleof)) {
        {
            FieldType temp = left.tupleof[i];
            left.tupleof[i] = right.tupleof[i];
            right.tupleof[i] = temp;
        }
    }
}

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
                        static if (__traits(compiles, mixin("this." ~ member ~ " = other." ~ member))) {
                            mixin("this." ~ member ~ " = other." ~ member ~ ";");
                        } else {
                            // Member has mutable indirections (e.g. a pointer), so inout doesn't
                            // implicitly convert. The copy is a shallow one by design.
                            mixin("this." ~ member ~ " = cast(typeof(this." ~ member ~ ")) other." ~ member ~ ";");
                        }
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
                        static if (__traits(compiles, mixin("this." ~ member ~ " = other." ~ member))) {
                            mixin("this." ~ member ~ " = other." ~ member ~ ";");
                        } else {
                            // Member has mutable indirections (e.g. a pointer), so inout doesn't
                            // implicitly convert. The copy is a shallow one by design.
                            mixin("this." ~ member ~ " = cast(typeof(this." ~ member ~ ")) other." ~ member ~ ";");
                        }
                    }
                }
            }

        }
    }
}
