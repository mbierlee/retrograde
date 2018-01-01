/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2018 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.debugging;

import retrograde.entity;
import retrograde.game;
import retrograde.engine;
import retrograde.messaging;
import retrograde.input;
import retrograde.stringid;
import retrograde.player;

import vibe.core.driver;
import vibe.http.router;
import vibe.http.fileserver;
import vibe.http.server;
import vibe.data.json;

import poodinis;

import std.string;
import std.conv;
import std.experimental.logger;

import core.thread;

class RemoteDebugger : EntityProcessor {

    @Autowire
    private std.experimental.logger.Logger logger;

    @Autowire
    private Game game;

    @Autowire
    @OptionalDependency
    private DebugWidget[] debugWidgets;

    private VibeThread thread;

    public override bool acceptsEntity(Entity entity) {
        return false;
    }

    private class VibeThread : Thread {
        private EventDriver eventDriver;

        this() {
            super(&run);
        }

        private void run() {
            auto router = new URLRouter;

            router.get("/ping", &pong);
            router.get("/widgets/", &createWidgetList);

            foreach(widget; debugWidgets) {
                router.get("/data/" ~ widget.resourceName, &widget.createContentJson);
            }

            router.get("*", serveStaticFiles("remote-debugger/"));

//			router.get("/debug-ws", handleWebSockets(&handleWebSocketConnection));

            auto settings = new HTTPServerSettings;
            settings.serverString = format("%s remote debugger - %s", getEngineName(), getEngineVersionText());
            settings.port = 8080;
            settings.bindAddresses = ["::1", "127.0.0.1"];
            listenHTTP(settings, router);

            eventDriver = getEventDriver();
            eventDriver.runEventLoop();
        }

        private void terminate() {
            eventDriver.exitEventLoop();
        }
    }

    private void pong(HTTPServerRequest req, HTTPServerResponse res) {
        res.writeBody("pong");
    }

    private void createWidgetList(HTTPServerRequest req, HTTPServerResponse res) {
        Json[] widgetList;

        foreach(widget; debugWidgets) {
            widgetList ~= Json([
                "element": Json(widget.elementName),
                "elementParameters": widget.createElementParameters()
            ]);
        }

        res.writeJsonBody(Json(widgetList));
    }

    public override void initialize() {
        logger.info("Remote debugger enabled");
        foreach(widget; debugWidgets) {
            widget.initialize();
        }

        thread = new VibeThread;
        thread.start();
    }

    public override void cleanup() {
        logger.info("Remote debugger disabled");
        thread.terminate();
        thread.join();
    }
}

class RemoteDebuggerContext : ApplicationContext {
    public override void registerDependencies(shared(DependencyContainer) container) {
        container.register!(DebugWidget, GameInfoDebugWidget);
        container.register!(DebugWidget, EntityManagerDebugWidget);
        container.register!(DebugWidget, MessagingDebugWidget);
    }
}

interface DebugWidget {
    @property string resourceName();
    @property string elementName();
    void initialize();
    Json createElementParameters();
    void createContentJson(HTTPServerRequest req, HTTPServerResponse res);
}

abstract class SimpleDebugWidget : DebugWidget {
    public @property string elementName() {
        return "rg-simplewidget";
    }
}

class GameInfoDebugWidget : SimpleDebugWidget {
    @Autowire
    private Game game;

    public @property string resourceName() {
        return "game-info";
    }

    public void initialize() {}

    public Json createElementParameters() {
        return Json([
            "title": Json("Game Info"),
            "resource": Json(resourceName)
        ]);
    }

    public void createContentJson(HTTPServerRequest req, HTTPServerResponse res) {
        res.writeJsonBody(Json([
            "content": Json(format("%s - %s %s - frametime: %sms - lag limit: %s frames", game.name, getEngineName(), getEngineVersionText(), game.msecsPerFrame, game.lagFrameLimit))
        ]));
    }
}

class EntityManagerDebugWidget : DebugWidget {
    @Autowire
    private EntityManager entityManager;

    public @property string resourceName() {
        return "entity-info";
    }

    public @property string elementName() {
        return "rg-entitymanagerwidget";
    }

    public void initialize() {}

    public Json createElementParameters() {
        return Json();
    }

    public void createContentJson(HTTPServerRequest req, HTTPServerResponse res) {
        Json[string] info = [
            "entities": createEntitiesJson(),
            "processors": createProcessorsJson()
        ];

        res.writeJsonBody(info);
    }

    private Json createEntitiesJson() {
        Json[] entityJsons;
        foreach(entity; entityManager.entities) {
            entityJsons ~= Json([
                "name": Json(entity.name),
                "id": Json(entity.id),
                "components": createComponentsJson(entity)
            ]);
        }

        return Json(entityJsons);
    }

    private Json createComponentsJson(Entity entity) {
        Json[] componentJsons;
        foreach(component; entity.components) {
            componentJsons ~= Json([
                "componentType": Json(component.getComponentTypeString()),
                "componentTypeSid": Json(component.getComponentType()),
                "data": Json(createSnapshotJson(component))
            ]);
        }

        return Json(componentJsons);
    }

    private Json createProcessorsJson() {
        Json[] processorJsons;
        foreach(processor; entityManager.processors) {
            processorJsons ~= Json([
                "type": Json(typeid(processor).name),
                "entities": createProcessorEntitiesJson(processor)
            ]);
        }

        return Json(processorJsons);
    }

    private Json createProcessorEntitiesJson(EntityProcessor processor) {
        Json[] entityJsons;
        foreach(entity; processor.entities) {
            entityJsons ~= Json([
                "name": Json(entity.name),
                "id": Json(entity.id)
            ]);
        }

        return Json(entityJsons);
    }

    private Json[string] createSnapshotJson(EntityComponent component) {
        Json[string] data;
        auto snapshot = cast(Snapshotable) component;
        if (snapshot !is null) {
            auto snapshotData = snapshot.getSnapshotData();
            foreach(snapshotTuple; snapshotData.byKeyValue()) {
                data[snapshotTuple.key] = Json(snapshotTuple.value);
            }
        }

        return data;
    }
}

class MessageLogger {
    private MessageChannel _channel;
    private const(Message)[] _log;
    private static const int maxLogs = 10;

    public @property channel() {
        return _channel;
    }

    public @property log() {
        return _log;
    }

    this(MessageChannel channel) {
        this._channel = channel;
    }

    public void connect() {
        _channel.connect(&logMessage);
    }

    private void logMessage(const(Message) message) {
        if (_log.length >= maxLogs) {
            _log = _log[1 .. $];
        }

        _log ~= message;
    }
}

class MessagingDebugWidget : DebugWidget {

    @Autowire
    @OptionalDependency
    private EventChannel[] eventChannels;

    @Autowire
    @OptionalDependency
    private CommandChannel[] commandChannels;

    @Autowire
    @OptionalDependency
    private MessageProcessor[] messageProcessors;

    @Autowire
    private SidMap sidMap;

    private MessageLogger[] eventLoggers;
    private MessageLogger[] commandLoggers;

    public @property string resourceName() {
        return "messaging-info";
    }

    public @property string elementName() {
        return "rg-messagingwidget";
    }

    public void initialize() {
        foreach(channel; eventChannels) {
            addChannelAsLogger(channel, eventLoggers);
        }

        foreach(channel; commandChannels) {
            addChannelAsLogger(channel, commandLoggers);
        }
    }

    private void addChannelAsLogger(MessageChannel channel, ref MessageLogger[] loggerDestination) {
        auto logger = new MessageLogger(channel);
        logger.connect();
        loggerDestination ~= logger;
    }

    public Json createElementParameters() {
        return Json();
    }

    public void createContentJson(HTTPServerRequest req, HTTPServerResponse res) {
        Json[] eventChannelsJsons;
        Json[] commandChannelsJsons;
        Json[] messageProcessorsJsons;

        foreach(logger; eventLoggers) {
            eventChannelsJsons ~= Json([
                "name": Json(typeid(logger.channel).name),
                "messageHistory": createMessageHistoryJson(logger)
            ]);
        }

        foreach(logger; commandLoggers) {
            commandChannelsJsons ~= Json([
                "name": Json(typeid(logger.channel).name),
                "messageHistory": createMessageHistoryJson(logger)
            ]);
        }

        foreach(processor; messageProcessors) {
            messageProcessorsJsons ~= Json([
                "name": Json(typeid(processor).name)
            ]);
        }

        res.writeJsonBody(Json([
            "eventChannels": Json(eventChannelsJsons),
            "commandChannels": Json(commandChannelsJsons),
            "messageProcessors": Json(messageProcessorsJsons)
        ]));
    }

    private Json createMessageHistoryJson(MessageLogger logger) {
        Json[] messageJsons;

        foreach(message; logger.log) {
            debug(readableStringId) {
                string type = message.type;
            } else {
                string type;
                if (sidMap.contains(message.type)) {
                    type = sidMap[message.type];
                } else {
                    type = format("<sid:%s>", message.type);
                }
            }

            messageJsons ~= Json([
                "type": Json(type),
                "magnitude": Json(message.magnitude),
                "data": createDataJson(message.data)
            ]);
        }

        return Json(messageJsons);
    }

    private Json createDataJson(const(MessageData) data) {
        if (data is null) {
            return Json();
        }

        return Json(to!string(data));
    }
}

class DebugEventPrinter {

    @Autowire
    private CoreEngineCommandChannel coreEventChannel;

    @Autowire
    private RawInputEventChannel rawInputEventChannel;

    @Autowire
    private MappedInputCommandChannel mappedInputCommandChannel;

    @Autowire
    private std.experimental.logger.core.Logger logger;

    public void initialize() {
        coreEventChannel.connect(&printEvent);
        rawInputEventChannel.connect(&printEvent);
        mappedInputCommandChannel.connect(&printEvent);
    }

    private void printEvent(const(Event) event) {
        string extraData = "";

        switch (event.type) {
            case InputEvent.JOYSTICK_AXIS_MOVEMENT:
                auto data = cast(JoystickAxisEventData) event.data;
                extraData = format("Axis: %s", data.axis);
                break;

            case InputEvent.JOYSTICK_BALL_MOVEMENT:
                auto data = cast(JoystickBallEventData) event.data;
                extraData = format("Ball: %s", data.ball);
                break;

            case InputEvent.JOYSTICK_HAT:
                auto data = cast(JoystickHatEventData) event.data;
                extraData = format("Hat: %s", data.hat);
                break;

            case InputEvent.JOYSTICK_BUTTON:
                auto data = cast(JoystickButtonEventData) event.data;
                extraData = format("Button: %s", data.button);
                break;

            case InputEvent.JOYSTICK_ADDED:
            case InputEvent.JOYSTICK_REMOVED:
                auto data = cast(InputMessageData) event.data;
                extraData = format("Device: %s", data.device);
                break;

            case InputEvent.KEYBOARD_KEY:
                auto data = cast(KeyboardKeyEventData) event.data;
                extraData = format("Key: %s - Modifiers: %s", to!string(data.scanCode), data.modifiers);
                break;

            case InputEvent.MOUSE_MOTION:
                auto data = cast(MouseMotionEventData) event.data;
                extraData = format("Axis: %s", data.axis);
                break;

            case InputEvent.MOUSE_BUTTON:
                auto data = cast(MouseButtonEventData) event.data;
                extraData = format("Button: %s", data.button);
                break;

            default:
                break;
        }

        debug(readableStringId) {
            string type = event.type;
        } else {
            string type = format("<sid:%s>", event.type);
        }

        logger.infof("%s: Received %s event with magnitude %s %s", typeid(this), type, event.magnitude, encloseIfNotEmpty(extraData));
    }

    private string encloseIfNotEmpty(string text) {
        string result = text;
        if (text.length > 0) {
            result = "(" ~ text ~ ")";
        }
        return result;
    }
}

public void registerRetrogradeDebugSids(SidMap sidMap) {
    registerLifecycleDebugSids(sidMap);
    registerEngineDebugSids(sidMap);
    registerPlayerLifecycleDebugSids(sidMap);
    registerInputEventDebugSids(sidMap);
}