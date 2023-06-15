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
    printf("%s\n", msg.ptr);
}

void writelnUint(uint number) {
    printf("%d\n", number);
}

void writelnInt(int number) {
    printf("%d\n", number);
}

void writelnUlong(ulong number) {
    printf("%d\n", cast(uint) number);
}

void writelnLong(long number) {
    printf("%d\n", cast(int) number);
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
    printf("%c\n", character);
}

void writelnDChar(dchar character) {
    printf("%c\n", character);
}

void writelnUbyte(ubyte number) {
    printf("%d\n", number);
}

void writelnByte(byte number) {
    printf("%d\n", number);
}

void writelnBool(bool value) {
    printf("%s\n", value ? "true".ptr : "false".ptr);
}

void writeErrLnStr(string msg) {
    printf("ERROR: %s\n", msg.ptr);
}

void writeErrLnUint(uint number) {
    printf("ERROR: %d\n", number);
}

void writeErrLnInt(int number) {
    printf("ERROR: %d\n", number);
}

void writeErrLnULong(ulong number) {
    printf("ERROR: %d\n", cast(uint) number);
}

void writeErrLnLong(long number) {
    printf("ERROR: %d\n", cast(int) number);
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
    printf("ERROR: %c\n", character);
}

void writeErrlnDChar(dchar character) {
    printf("ERROR: %c\n", character);
}

void writeErrLnUbyte(ubyte number) {
    printf("ERROR: %d\n", number);
}

void writeErrLnByte(byte number) {
    printf("ERROR: %d\n", number);
}

void writeErrLnBool(bool value) {
    printf("ERROR: %s\n", value ? "true".ptr : "false".ptr);
}
