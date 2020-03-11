/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2020 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

import retrograde.messaging;
import dunit;

import retrograde.stringid;

class TestMessageData : MessageData {
    public uint number;

    this(uint number) {
        this.number = number;
    }
}

class MessageRouterTest {
    mixin UnitTest;

    class SourceChannel : EventChannel {}
    class TargetChannel : EventChannel {}

    class TestEventConsumer {
        private EventChannel channel;

        public Event lastEvent;
        public uint events;

        this(EventChannel channel) {
            this.channel = channel;
        }

        public void initialize() {
            channel.connect(&handleEvent);
        }

        private void handleEvent(const(Event) event) {
            this.lastEvent = cast(Event) event;
            events += 1;
        }
    }

    @Test
    public void testRoute() {
        auto source = new SourceChannel();
        auto target = new TargetChannel();
        auto router = new MessageRouter();
        auto consumer = new TestEventConsumer(target);
        consumer.initialize();
        auto type = sid("ev_test");

        router.addRoute(MessageRoute(type, source, target));
        router.addRoute(MessageRoute(type, source, target));

        auto event = Event(type, 1);
        source.emit(event);

        assertEquals(event, consumer.lastEvent);
        assertEquals(1, consumer.events);
    }

    @Test
    public void testAdjustEvent() {
        auto source = new SourceChannel();
        auto target = new TargetChannel();
        auto router = new MessageRouter();
        auto consumer = new TestEventConsumer(target);
        consumer.initialize();
        auto type = sid("ev_test");

        router.addRoute(MessageRoute(type, source, target), (e) {
            return Event(e.type, e.magnitude, new TestMessageData(3));
        });

        auto originalEventData = new TestMessageData(8);
        auto event = Event(type, 1, originalEventData);
        source.emit(event);

        auto actualEventData = cast(TestMessageData) consumer.lastEvent.data;
        assertNotNull(actualEventData);
        assertEquals(3, actualEventData.number);
    }
}

class MessageProcessorTest {
    mixin UnitTest;

    class TestChannel : MessageChannel {}

    class TestMessageProcessor : MessageProcessor {
        public Message lastHandledMessage;

        this(MessageChannel sourceChannel) {
            super(sourceChannel);
        }

        protected override void handleMessage(const(Message) message) {
            this.lastHandledMessage = cast(Message) message;
        }

        public override void update() {}
    }

    class TestMultiMessageProcessor : MessageProcessor {
        public Message lastHandledMessageFromChannel1;
        public Message lastHandledMessageFromChannel2;

        this(MessageChannel sourceChannel, MessageChannel sourceChannel2) {
            super([sourceChannel, sourceChannel2]);
        }

        protected override void handleMessage(const(Message) message) {
            if (message.type == sid("message1")) {
                this.lastHandledMessageFromChannel1 = cast(Message) message;
            } else if (message.type == sid("message2")) {
                this.lastHandledMessageFromChannel2 = cast(Message) message;
            }
        }

        public override void update() {}
    }

    @Test
    public void testHandlesMessagesFromSourceChannel() {
        auto testChannel = new TestChannel();
        auto processor = new TestMessageProcessor(testChannel);
        processor.initialize();
        testChannel.emit(Message(sid("testmsg"), 0));

        assertEquals(sid("testmsg"), processor.lastHandledMessage.type);
    }

    @Test
    public void testHandlesMessagesFromMultipleSourceChannel() {
        auto testChannel1 = new TestChannel();
        auto testChannel2 = new TestChannel();
        auto processor = new TestMultiMessageProcessor(testChannel1, testChannel2);
        processor.initialize();
        testChannel1.emit(Message(sid("message1"), 0));
        testChannel2.emit(Message(sid("message2"), 0));

        assertEquals(sid("message1"), processor.lastHandledMessageFromChannel1.type);
        assertEquals(sid("message2"), processor.lastHandledMessageFromChannel2.type);
    }
}