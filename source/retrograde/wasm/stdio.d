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

export extern (C) void writelnStr(string msg);

export extern (C) void writelnUint(uint number);

export extern (C) void writelnInt(int number);

export extern (C) void writelnDouble(double number);

export extern (C) void writelnFloat(float number);
