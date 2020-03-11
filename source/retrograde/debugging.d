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

module retrograde.debugging;

import retrograde.entity;
import retrograde.game;
import retrograde.engine;
import retrograde.messaging;
import retrograde.input;
import retrograde.stringid;
import retrograde.player;

import poodinis;

import collie.net;
import collie.codec.http;
import collie.codec.http.server;

import std.string;
import std.conv;
import std.experimental.logger;
//import std.typecons;
import std.json;
import std.exception;

import core.thread;

class RemoteDebugger : EntityProcessor {

    @Autowire
    private std.experimental.logger.Logger logger;

    @Autowire
    private Game game;

    @Autowire
    @OptionalDependency
    private DebugWidget[] debugWidgets;

    private ServerThread thread;

    public override bool acceptsEntity(Entity entity) {
        return false;
    }

    private class ServerThread : Thread {
        this() {
            super(&run);
        }

        private HttpServer server;

        private void run() {
            HTTPServerOptions options = new HTTPServerOptions();
            options.handlerFactories ~= &createRequestHandler;
            options.threads = 1;
            HTTPServerOptions.IPConfig ipConfig;
            ipConfig.address = new InternetAddress("0.0.0.0", 8080);

            server = new HttpServer(options);
            server.addBind(ipConfig);
            logger.info("The remote debugger is listening on ", ipConfig.address.toString());
            server.start();
        }

        private RequestHandler createRequestHandler(RequestHandler, HTTPMessage) {
            DebuggerRequestHandler.RouteMap routes;

            routes["/ping"] = &pong;
            routes["/widgets/"] = &createWidgetList;

            foreach(widget; debugWidgets) {
                routes["/data/" ~ widget.resourceName] = &widget.createContentJson;
            }

            return new DebuggerRequestHandler(routes);
        }

        private void terminate() {
            server.stop();
        }
    }

    class DebuggerRequestHandler : RequestHandler {
        alias RouteFunc = void delegate(HttpMessage message, ref ResponseBuilder response);
        alias RouteMap = RouteFunc[string];

        private HttpMessage message;
        private RouteMap routes;
        private RouteFunc* route;

        this(RouteMap routes) {
            this.routes = routes;
        }

        protected override void onRequest(HttpMessage message) nothrow
        {
            collectException({
                this.message = message;
                this.route = message.url in routes;
            }());
        }

        protected override void onBody(const ubyte[] data) nothrow {}

        protected override void onEOM() nothrow {
            auto exception = collectException({
                auto response = new ResponseBuilder(_downstream);
                response.header("Server", format("%s remote debugger - %s", getEngineName(), getEngineVersionText()));

                if (route !is null) {
                    response.status(cast(ushort) 200, HTTPMessage.statusText(200));
                    (*route)(this.message, response);
                } else {
                    response.status(cast(ushort) 404, HTTPMessage.statusText(404));
                }

                response.sendWithEOM();
            }());

            if (exception !is null) {
                collectException({
                    logger.error(exception.message ~ "\n" ~ exception.info.toString);

                    auto response = new ResponseBuilder(_downstream);
                    response.status(cast(ushort) 500, HTTPMessage.statusText(500));
                    response.sendWithEOM();
                }());
            }
        }

        protected override void onError(HTTPErrorCode code) nothrow {}

        protected override void requestComplete() nothrow {}
    }

    private void pong(HttpMessage message, ref ResponseBuilder response) {
        response
            .setCorsHeaders()
            .header("Content-Type", "text/plain")
            .setBody(cast(ubyte[]) "pong");
    }

    private void createWidgetList(HttpMessage message, ref ResponseBuilder response) {
        JSONValue[] widgetList;

        foreach(widget; debugWidgets) {
            JSONValue widgetJson = [
                "element": widget.elementName
            ];

            widgetJson.object["elementParameters"] = widget.createElementParameters();
            widgetList ~= widgetJson;
        }

        JSONValue widgetListJson;
        widgetListJson.array = widgetList;
        response.setJsonBody(widgetListJson);
    }

    public override void initialize() {
        logger.info("Remote debugger enabled");
        foreach(widget; debugWidgets) {
            widget.initialize();
        }

        thread = new ServerThread;
        thread.start();
    }

    public override void cleanup() {
        logger.info("Remote debugger disabled");
        thread.terminate();
        thread.join();
    }
}

private ResponseBuilder setCorsHeaders(ref ResponseBuilder response) {
    return response
        .header("Access-Control-Allow-Origin", "*")
        .header("Access-Control-Allow-Methods", "GET");
}

private ResponseBuilder setJsonBody(ref ResponseBuilder response, ref JSONValue responseJson) {
    return response
        .setCorsHeaders()
        .header("Content-Type", "application/json")
        .setBody(cast(ubyte[]) responseJson.toString);
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
    JSONValue createElementParameters();
    void createContentJson(HttpMessage message, ref ResponseBuilder response);
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

    public JSONValue createElementParameters() {
        return JSONValue([
            "title": "Game Info",
            "resource": resourceName
        ]);
    }

    public void createContentJson(HttpMessage message, ref ResponseBuilder response) {
        JSONValue json = [
            "content": format("%s - %s %s - frametime: %sms - lag limit: %s frames", game.name, getEngineName(), getEngineVersionText(), game.msecsPerFrame, game.lagFrameLimit)
        ];

        response.setJsonBody(json);
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

    public JSONValue createElementParameters() {
        return JSONValue([
            "title": "Entity Manager",
            "resource": resourceName
        ]);
    }

    public void createContentJson(HttpMessage message, ref ResponseBuilder response) {
        JSONValue info = [
            "entities": createEntitiesJson(),
            "processors": createProcessorsJson()
        ];

        response.setJsonBody(info);
    }

    private JSONValue createEntitiesJson() {
        JSONValue[] entityJsons;
        foreach(entity; entityManager.entities) {
            JSONValue entityJson = [
                "name": entity.name
            ];

            entityJson.object["id"] = JSONValue(entity.id);
            entityJson.object["components"] = createComponentsJson(entity);
            entityJsons ~= entityJson;
        }

        JSONValue entityJsonsList;
        entityJsonsList.array = entityJsons;
        return entityJsonsList;
    }

    private JSONValue createComponentsJson(Entity entity) {
        JSONValue[] componentJsons;
        foreach(component; entity.components) {
            JSONValue componentJson = [
                "componentType": component.getComponentTypeString()
            ];

            componentJson.object["componentTypeSid"] = JSONValue(component.getComponentType());
            componentJson.object["data"] = createSnapshotJson(component);
            componentJsons ~= componentJson;
        }

        JSONValue componentJsonsList;
        componentJsonsList.array = componentJsons;
        return componentJsonsList;
    }

    private JSONValue createProcessorsJson() {
        JSONValue[] processorJsons;
        foreach(processor; entityManager.processors) {
            JSONValue processorJson = [
                "type": typeid(processor).name
            ];

            processorJson.object["entities"] = createProcessorEntitiesJson(processor);
            processorJsons ~= processorJson;
        }

        JSONValue processorJsonsList;
        processorJsonsList.array = processorJsons;
        return processorJsonsList;
    }

    private JSONValue createProcessorEntitiesJson(EntityProcessor processor) {
        JSONValue[] entityJsons;
        foreach(entity; processor.entities) {
            JSONValue entityJson = [
                "name": entity.name
            ];

            entityJson.object["id"] = JSONValue(entity.id);

            entityJsons ~= entityJson;
        }

        JSONValue entityJsonsList;
        entityJsonsList.array = entityJsons;
        return entityJsonsList;
    }

    private JSONValue createSnapshotJson(EntityComponent component) {
        JSONValue data = parseJSON("{}");
        auto snapshot = cast(Snapshotable) component;
        if (snapshot !is null) {
            auto snapshotData = snapshot.getSnapshotData();
            foreach(snapshotTuple; snapshotData.byKeyValue()) {
                data.object[snapshotTuple.key] = JSONValue(snapshotTuple.value);
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
    private retrograde.messaging.EventChannel[] eventChannels;

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

    public JSONValue createElementParameters() {
        return JSONValue([
            "title": "Messaging",
            "resource": resourceName
        ]);
    }

    public void createContentJson(HttpMessage message, ref ResponseBuilder response) {
        JSONValue[] eventChannelsJsons;
        JSONValue[] commandChannelsJsons;
        JSONValue[] messageProcessorsJsons;

        foreach(logger; eventLoggers) {
            JSONValue eventChannelJson = [
                "name": typeid(logger.channel).name
            ];

            eventChannelJson.object["messageHistory"] = createMessageHistoryJson(logger);
            eventChannelsJsons ~= eventChannelJson;
        }

        foreach(logger; commandLoggers) {
            JSONValue commandChannelJson = [
                "name": typeid(logger.channel).name
            ];

            commandChannelJson.object["messageHistory"] = createMessageHistoryJson(logger);
            commandChannelsJsons ~= commandChannelJson;
        }

        foreach(processor; messageProcessors) {
            messageProcessorsJsons ~= JSONValue([
                "name": typeid(processor).name
            ]);
        }

        JSONValue info = [
            "eventChannels": eventChannelsJsons,
            "commandChannels": commandChannelsJsons,
            "messageProcessors": messageProcessorsJsons
        ];

        response.setJsonBody(info);
    }

    private JSONValue createMessageHistoryJson(MessageLogger logger) {
        JSONValue[] messageJsons;

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

            JSONValue messageJson = [
                "type": type,
                "data": createDataString(message.data)
            ];

            messageJson.object["magnitude"] = JSONValue(message.magnitude);
            messageJsons ~= messageJson;
        }

        JSONValue messsageJsonsList;
        messsageJsonsList.array = messageJsons;
        return messsageJsonsList;
    }

    private string createDataString(const(MessageData) data) {
        if (data is null) {
            return "";
        }

        return to!string(data);
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