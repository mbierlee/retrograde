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

module retrograde.viewport;

import retrograde.math;

interface Viewport {
    public @property RectangleI dimensions();
    public void swapBuffers();
    public void cleanup();
}

interface ViewportFactory {
    public Viewport create();
}