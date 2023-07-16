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

module retrograde.native.stdio;

version (Native)  :  //

import core.stdc.stdio : printf;

void writelnStr(string msg) {
    printf("%.*s\n", cast(int) msg.length, msg.ptr);
}

void writelnUint(uint number) {
    printf("%u\n", number);
}

void writelnInt(int number) {
    printf("%d\n", number);
}

void writelnUlong(ulong number) {
    printf("%llu\n", number);
}

void writelnLong(long number) {
    printf("%lld\n", number);
}

void writelnDouble(double number) {
    printf("%f\n", number);
}

void writelnFloat(float number) {
    printf("%f\n", number);
}

void writelnChar(char character) {
    printf("%c\n", character);
}

void writelnWChar(wchar character) {
    printf("%lc\n", character);
}

void writelnDChar(dchar character) {
    printf("%lc\n", character);
}

void writelnUbyte(ubyte number) {
    printf("%hhu\n", number);
}

void writelnByte(byte number) {
    printf("%hhd\n", number);
}

void writelnBool(bool value) {
    printf("%s\n", value ? "true".ptr : "false".ptr);
}

void writeErrLnStr(string msg) {
    printf("ERROR: %.*s\n", cast(int) msg.length, msg.ptr);
}

void writeErrLnUint(uint number) {
    printf("ERROR: %u\n", number);
}

void writeErrLnInt(int number) {
    printf("ERROR: %d\n", number);
}

void writeErrLnULong(ulong number) {
    printf("ERROR: %llu\n", number);
}

void writeErrLnLong(long number) {
    printf("ERROR: %lld\n", number);
}

void writeErrLnDouble(double number) {
    printf("ERROR: %f\n", number);
}

void writeErrLnFloat(float number) {
    printf("ERROR: %f\n", number);
}

void writeErrLnChar(char character) {
    printf("ERROR: %c\n", character);
}

void writeErrlnWChar(wchar character) {
    printf("ERROR: %lc\n", character);
}

void writeErrlnDChar(dchar character) {
    printf("ERROR: %lc\n", character);
}

void writeErrLnUbyte(ubyte number) {
    printf("ERROR: %hhu\n", number);
}

void writeErrLnByte(byte number) {
    printf("ERROR: %hhd\n", number);
}

void writeErrLnBool(bool value) {
    printf("ERROR: %s\n", value ? "true".ptr : "false".ptr);
}
