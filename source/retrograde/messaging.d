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

module retrograde.messaging;

import retrograde.stringid;

import std.format;
import std.signals;
import std.conv;
import std.exception;

interface MessageData {}

struct Message {
    StringId type;
    double magnitude;
    MessageData data;
}

alias Event = Message;
alias Command = Message;

class EventHandler {
    public bool handleJoystickEvents;
    public bool handleMouseEvents;
    public bool handleKeyboardEvents;

    public abstract void handleEvents();
}

abstract class MessageChannel {
    mixin Signal!(const(Message));
}

abstract class EventChannel : MessageChannel {}

abstract class CommandChannel : MessageChannel {}

struct MessageRoute {
    StringId type;
    MessageChannel source;
    MessageChannel target;
}

class MessageRouter {
    private MessageRoute[StringId] routes;
    private bool[MessageChannel] sources;
    private const(Message) function(const(Message))[MessageRoute] adjusters;

    public void addRoute(MessageRoute route, const(Message) function(const(Message)) messageAdjuster = null) {
        enforce(route.source !is null, "Route's source channel cannot be null");
        enforce(route.target !is null, "Route's target channel cannot be null");
        routes[route.type] = route;

        if (messageAdjuster !is null) {
            adjusters[route] = messageAdjuster;
        }

        if ((route.source in sources) is null) {
            route.source.connect(&routeMessage);
            sources[route.source] = true;
        }
    }

    private void routeMessage(const(Message) message) {
        auto route = message.type in routes;
        if (route) {
            auto adjuster = *route in adjusters;
            if (adjuster) {
                auto adjustedMessage = (*adjuster)(message);
                route.target.emit(adjustedMessage);
            } else {
                route.target.emit(message);
            }
        }
    }
}

public const(Event) dropMessageData(const(Message) message) {
    return Message(message.type, message.magnitude);
}

class MessageProcessor {
    private MessageChannel[] sourceChannels;

    this(MessageChannel sourceChannel) {
        this([sourceChannel]);
    }

    this(MessageChannel[] sourceChannels) {
        this.sourceChannels = sourceChannels;
    }

    public void initialize() {
        foreach(channel; sourceChannels) {
            channel.connect(&this.handleMessage);
        }
    }

    protected abstract void handleMessage(const(Message) message);

    public void update() {}
}
