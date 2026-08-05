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
import retrograde.std.collections : Queue, Array;
import retrograde.std.dlang : CopyConstructors;

version (DoublePrecision) {
    alias Magnitude = double;
} else {
    alias Magnitude = float;
}

alias EventHandlerFunction = void delegate(ref const Event);

Queue!Event eventQueue;
Array!EventHandlerFunction eventHandlers;

void processEvents() {
    Event event;
    while (eventQueue.tryDequeue(event)) {
        foreach (handler; eventHandlers) {
            handler(event);
        }
    }
}

struct Event {
    StringId name;
    Magnitude magnitude;
    // EventData data1; // TODO: Add back when needed
}

union EventData {
    ubyte ubData;
    byte bData;
    char cData;
    wchar wcData;
    uint uiData;
    int iData;
    float fData;
    dchar dcData;

    version (LargeEventData)  :  //
    ulong ulData;
    long lData;
    double dData;
}
