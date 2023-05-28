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

void writeln(string msg) {
    printf("%s\n", msg.ptr);
}
