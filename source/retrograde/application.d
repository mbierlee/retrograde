/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2017 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.application;

import poodinis;

import retrograde.logging;
import retrograde.messaging;
import retrograde.engine;
import retrograde.input;
import retrograde.entity;

import std.experimental.logger;

enum WindowPosition {
	centered,
	custom
}

struct WindowCreationContext {
	uint x = 0;
	uint y = 0;
	uint width = 640;
	uint height = 480;
	WindowPosition xWindowPosition = WindowPosition.centered;
	WindowPosition yWindowPosition = WindowPosition.centered;
}

class RetrogradeDefaultApplicationContext : ApplicationContext {

	public override void registerDependencies(shared(DependencyContainer) container) {
		container.register!(CommandChannel, CoreEngineCommandChannel);
		container.register!(CommandChannel, MappedInputCommandChannel);

		container.register!(EventChannel, RawInputEventChannel);

		container.register!InputHandler;
		container.register!EntityManager;
	}

	@Component
	public Logger logger() {
		auto logger = new MultiLogger();

		auto stdoutLogger = new StdoutLogger();
		if (stdoutLogger.stdoutIsAvailable()) {
			logger.insertLogger("stdoutLogger", stdoutLogger);
		}

		sharedLog = logger;
		return logger;
	}

}
