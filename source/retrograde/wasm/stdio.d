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

module retrograde.wasm.stdio;

version (WebAssembly)  :  //

export:
extern (C):

void writelnStr(string msg);
void writelnUint(uint number);
void writelnInt(int number);
void writelnUlong(ulong number);
void writelnLong(long number);
void writelnDouble(double number);
void writelnFloat(float number);
void writelnChar(char character);
void writelnWChar(char character);
void writelnDChar(char character);
void writelnUbyte(ubyte number);
void writelnByte(byte number);
void writelnBool(bool value);

void writeErrLnStr(string msg);
void writeErrLnUint(uint number);
void writeErrLnInt(int number);
void writeErrLnULong(ulong number);
void writeErrLnLong(long number);
void writeErrLnDouble(double number);
void writeErrLnFloat(float number);
void writeErrLnChar(char character);
void writeErrLnWChar(char character);
void writeErrLnDChar(char character);
void writeErrLnUbyte(ubyte number);
void writeErrLnByte(byte number);
void writeErrLnBool(bool value);
