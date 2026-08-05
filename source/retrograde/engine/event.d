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

module retrograde.engine.event;

import retrograde.std.memory : SharedPtr;
import retrograde.std.stringid : StringId;
import retrograde.std.collections : Queue;
import retrograde.std.dlang : CopyConstructors;

alias Magnitude = float;
Queue!Event eventQueue;

struct Event {
    StringId name;
    Magnitude magnitude;
    void* eventData;

    mixin CopyConstructors!Event;
}
