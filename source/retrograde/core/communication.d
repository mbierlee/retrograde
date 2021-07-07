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

module retrograde.core.communication;

import retrograde.core.stringid : StringId, sid;

import std.algorithm.mutation : remove;

alias MessageProcessor = void delegate(const StringId channel, immutable Message message);

/**
 * Base class for message data.
 */
class Message
{
    @property StringId id;

    this(const StringId id = sid(""))
    {
        this.id = id;
    }

    static immutable(Message) create(const StringId id)
    {
        return cast(immutable(Message)) new Message(id);
    }
}

/**
 * Message handler takes care of queueing and disclosing messages.
 * The handler keeps track of two message queues: an active and stand-by queue.
 * Messages that are sent are put into the stand-by queue and messages that are read come
 * from the active queue. This system makes the message queue immutable for the current update cycle.
 * Using immediate delivery, one can immediately send messages to those who are able to handle immediate messages.
 */
class MessageHandler
{
    private immutable(Message)[][StringId] activeMessageQueue;
    private immutable(Message)[][StringId] standbyMessageQueue;
    private MessageProcessor[][StringId] immediateReceivers;

    /**
     * Send a message to a specific channel.
     * Messages are queued, not immediately delivered. Those interested can
     * receive them at their own leisure. Messages are queued in a stand-by queue
     * and cannot be received until the queue is swapped to the active queue.
     *
     * Params:
     *  channel = ID of the channel to send the message to.
     *  message = Message to send to the channel.
     *
     * See_Also: receiveMessages, shiftStandbyToActiveQueue
     */
    public void sendMessage(const StringId channel, immutable Message message)
    {
        if ((channel in standbyMessageQueue) is null)
        {
            standbyMessageQueue[channel] = [];
        }

        standbyMessageQueue[channel] ~= message;
    }

    /**
     * Receives all messages sent to a specific channel.
     * Messages are read from the active message queue and sent to the specified processor.
     *
     * Params:
     *  channel = ID of the channel to receive messages from.
     *  processor = Processor delegate that takes care of processing received messages.
     *
     * See_Also: sendMessage
     */
    public void receiveMessages(const StringId channel, const MessageProcessor processor)
    {
        if (auto channelMessages = channel in activeMessageQueue)
        {
            foreach (message; *channelMessages)
            {
                processor(channel, message);
            }
        }
    }

    /**
     * Receives all messages sent to a specific channel.
     * Messages are read from the active message queue and sent to the specified processor.
     *
     * Params:
     *  channel = ID of the channel to receive messages from.
     *  processor = Processor delegate that takes care of processing received messages.
     *
     * See_Also: sendMessage
     */
    public void receiveMessages(const StringId channel,
            const(void delegate(immutable Message)) processor)
    {
        if (auto channelMessages = channel in activeMessageQueue)
        {
            foreach (message; *channelMessages)
            {
                processor(message);
            }
        }
    }

    /**
     * Copies all messages sent to the stand-by message queue to the active message queue and
     * clears the stand-by qeueu.
     * This method is typically called at the start of an update cycle.
     */
    public void shiftStandbyToActiveQueue()
    {
        activeMessageQueue = standbyMessageQueue;
        standbyMessageQueue.destroy();
    }

    /**
     * Register a processor for immediate receival of messages.
     *
     * Params:
     *  channel = ID of the channel to receive messages from.
     *  processor = Processor delegate that takes care of processing received messages.
     *
     * See_Also: sendMessageImmediately
     */
    public void registerImmediateReceiver(const StringId channel, const MessageProcessor processor)
    {
        if ((channel in immediateReceivers) is null)
        {
            immediateReceivers[channel] = [];
        }

        immediateReceivers[channel] ~= processor;
    }

    /**
     * Removes an immediate receiver, no longer making them immediately receive messages.
     * 
     * Params:
     *  channel = ID of the channel where messages were sent to.
     *  processor = Processor delegate that has to be removed.
     */
    public void removeImmedateReceiver(const StringId channel, const MessageProcessor processor)
    {
        if (auto receivers = channel in immediateReceivers)
        {
            *receivers = remove!(r => r is processor)(*receivers);
        }
    }

    /**
     * Sends a message for immediate delivery to those willing to accept immediate messages.
     * Messages are not added to the queues.
     *
     * Params:
     *  channel = ID of the channel to send the message to.
     *  message = Message to send to the channel.
     */
    public void sendMessageImmediately(const StringId channel, immutable Message message)
    {
        if (auto receivers = channel in immediateReceivers)
        {
            foreach (receiver; *receivers)
            {
                receiver(channel, message);
            }
        }
    }

}

version (unittest)
{
    mixin template ProcessorMixin()
    {
        auto receivedMessage = false;

        void process(const StringId channel, immutable Message message)
        {
            receivedMessage = true;
        }
    }

    private StringId testChannel = sid("test_channel");
    private StringId testMessageId = sid("test_message");

    @("Send and receive a messages")
    unittest
    {
        mixin ProcessorMixin;

        const auto processor = &process;

        auto handler = new MessageHandler();
        handler.sendMessage(testChannel, Message.create(testMessageId));
        handler.receiveMessages(testChannel, processor);
        assert(!receivedMessage);

        receivedMessage = false;
        handler.shiftStandbyToActiveQueue();
        handler.receiveMessages(testChannel, processor);
        assert(receivedMessage);

        receivedMessage = false;
        handler.receiveMessages(testChannel, (immutable Message message) {
            processor(testChannel, message);
        });
        assert(receivedMessage);

        receivedMessage = false;
        handler.shiftStandbyToActiveQueue();
        handler.receiveMessages(testChannel, processor);
        assert(!receivedMessage);
    }

    @("Send message immediately")
    unittest
    {
        mixin ProcessorMixin;

        const auto processor = &process;

        auto handler = new MessageHandler();
        handler.registerImmediateReceiver(testChannel, processor);
        handler.sendMessageImmediately(testChannel, Message.create(testMessageId));
        assert(receivedMessage);
    }

    @("Remove immediate message receiver")
    unittest
    {
        mixin ProcessorMixin;

        const auto processor = &process;

        auto handler = new MessageHandler();
        handler.registerImmediateReceiver(testChannel, processor);
        handler.removeImmedateReceiver(testChannel, processor);
        handler.sendMessageImmediately(testChannel, Message.create(testMessageId));
        assert(!receivedMessage);
    }

    @("Sent messages are received in the same order they were sent")
    unittest
    {
        StringId[] receivedMessages;
        void process(const StringId channel, immutable Message message)
        {
            receivedMessages ~= message.id;
        }

        auto handler = new MessageHandler();
        handler.sendMessage(testChannel, Message.create(sid("message1")));
        handler.sendMessage(testChannel, Message.create(sid("message2")));
        handler.shiftStandbyToActiveQueue();
        handler.receiveMessages(testChannel, &process);

        assert(receivedMessages.length == 2);
        assert(receivedMessages[0] == sid("message1"));
        assert(receivedMessages[1] == sid("message2"));
    }
}
