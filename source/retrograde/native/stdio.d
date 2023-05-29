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

void writelnDouble(double number) {
    printf("%f\n", number);
}

void writelnFloat(float number) {
    printf("%f\n", number);
}
