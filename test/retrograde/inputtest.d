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

import retrograde.input;
import retrograde.messaging;
import retrograde.stringid;

import dunit;

import poodinis;

class EventMappingKeyTest {
	mixin UnitTest;

	@Test
	public void testKeyEquality() {
		auto keyOne = EventMappingKey(sid("bla"), 1);
		auto keyTwo = EventMappingKey(sid("bla"), 1);

		assertEquals(keyOne, keyTwo);
	}

	@Test
	void testKeyInMap() {
		string[EventMappingKey] mapping;
		mapping[EventMappingKey(sid("a"), 1)] = "yes";

		auto map = EventMappingKey(sid("a"), 1) in mapping;

		assertNotNull(map);
		assertTrue(*map == "yes");
	}
}

class InputHandlerTest {
	mixin UnitTest;

	private shared(DependencyContainer) container;
	private MappedInputCommandChannel mappedInputCommandChannel;
	private RawInputEventChannel rawInputEventChannel;

	class TestCommandConsumer {
		public StringId lastHandledCommand, beforeLastHandledCommand;
		public double magnitudeOfLastHandledCommand, magnitudeOfBeforeLastHandledCommand;
		public MappedInputCommandData dataOfLastHandledCommand;

		this(MappedInputCommandChannel mappedInputCommandChannel) {
			mappedInputCommandChannel.connect(&handleCommand);
		}

		private void handleCommand(const(Command) command) {
			beforeLastHandledCommand = lastHandledCommand;
			magnitudeOfBeforeLastHandledCommand = magnitudeOfLastHandledCommand;

			lastHandledCommand = command.type;
			magnitudeOfLastHandledCommand = command.magnitude;
			dataOfLastHandledCommand = cast(MappedInputCommandData) command.data;
		}
	}

	@BeforeEach
	public void setup() {
		mappedInputCommandChannel = new MappedInputCommandChannel;
		rawInputEventChannel = new RawInputEventChannel;

		container = new DependencyContainer();
		container.register!MappedInputCommandChannel.existingInstance(mappedInputCommandChannel);
		container.register!RawInputEventChannel.existingInstance(rawInputEventChannel);
		container.register!InputHandler;
	}

	@Test
	void testMappedEvent() {
		auto sourceEvent = InputEvent.JOYSTICK_AXIS_MOVEMENT;
		auto expectedTargetEvent = sid("ev_shoot_that_guy");
		double expectedMagnitude = 1;
		auto inputHandler = container.resolve!InputHandler;
		auto consumer = new TestCommandConsumer(mappedInputCommandChannel);

		auto data = new JoystickAxisEventData();
		data.axis = 3;

		inputHandler.initialize();
		inputHandler.setEventMapping(EventMappingKey(sourceEvent, data.axis), expectedTargetEvent);
		rawInputEventChannel.emit(Event(sourceEvent, expectedMagnitude, data));
		inputHandler.handleEvents();

		assertEquals(expectedTargetEvent, consumer.lastHandledCommand);
		assertEquals(expectedMagnitude, consumer.magnitudeOfLastHandledCommand);
	}

	@Test
	void testMultiMappedEvent() {
		auto sourceEvent = InputEvent.JOYSTICK_AXIS_MOVEMENT;
		auto expectedTargetEvent1 = sid("ev_shoot_that_guy");
		auto expectedTargetEvent2 = sid("ev_lay_low_brothas");
		double expectedMagnitude = 1;
		auto inputHandler = container.resolve!InputHandler;
		auto consumer = new TestCommandConsumer(mappedInputCommandChannel);

		auto data = new JoystickAxisEventData();
		data.axis = 3;

		inputHandler.initialize();
		inputHandler.setEventMapping(EventMappingKey(sourceEvent, data.axis), [expectedTargetEvent1, expectedTargetEvent2]);
		rawInputEventChannel.emit(Event(sourceEvent, expectedMagnitude, data));
		inputHandler.handleEvents();

		assertEquals(expectedTargetEvent2, consumer.lastHandledCommand);
		assertEquals(expectedTargetEvent1, consumer.beforeLastHandledCommand);
		assertEquals(expectedMagnitude, consumer.magnitudeOfLastHandledCommand);
		assertEquals(expectedMagnitude, consumer.magnitudeOfBeforeLastHandledCommand);
	}

	@Test
	void testDeadzoneEvent() {
		auto sourceEvent = InputEvent.JOYSTICK_AXIS_MOVEMENT;
		auto targetEvent = sid("ev_shoot_that_guy");
		auto inputHandler = container.resolve!InputHandler;
		auto consumer = new TestCommandConsumer(mappedInputCommandChannel);

		auto data = new JoystickAxisEventData();
		data.axis = 3;

		inputHandler.initialize();
		inputHandler.setEventMapping(EventMappingKey(sourceEvent, data.axis), targetEvent);
		inputHandler.setJoystickAxisDeadzone(3, 0.2);

		rawInputEventChannel.emit(Event(sourceEvent, 0.1, data));
		inputHandler.handleEvents();

		assertEquals(0, consumer.magnitudeOfLastHandledCommand);

		rawInputEventChannel.emit(Event(sourceEvent, 0.3, data));
		inputHandler.handleEvents();

		assertEquals(0.3, consumer.magnitudeOfLastHandledCommand);
	}

	@Test
	void testInvertedMagnitude() {
		auto sourceEvent = InputEvent.KEYBOARD_KEY;
		auto expectedTargetEvent = sid("ev_shoot_that_guy");
		double expectedMagnitude = -1;
		auto inputHandler = container.resolve!InputHandler;
		auto consumer = new TestCommandConsumer(mappedInputCommandChannel);

		auto data = new KeyboardKeyEventData();
		data.scanCode = KeyboardKeyCode.A;

		inputHandler.initialize();
		inputHandler.setEventMapping(EventMappingKey(sourceEvent, data.scanCode), expectedTargetEvent, InvertMagnitude.yes);
		rawInputEventChannel.emit(Event(sourceEvent, 1, data));
		inputHandler.handleEvents();

		assertEquals(expectedMagnitude, consumer.magnitudeOfLastHandledCommand);
	}

	@Test
	void testPassedDevice() {
		auto event = InputEvent.JOYSTICK_AXIS_MOVEMENT;

		auto inputHandler = container.resolve!InputHandler;
		auto consumer = new TestCommandConsumer(mappedInputCommandChannel);

		auto data = new JoystickAxisEventData();
		data.device = Device(DeviceType.joystick, 3);

		inputHandler.initialize();
		inputHandler.setEventMapping(EventMappingKey(event, data.axis), sid("ev_wahtevs!"));
		rawInputEventChannel.emit(Event(event, 1, data));
		inputHandler.handleEvents();

		assertTrue(consumer.dataOfLastHandledCommand !is null);
		assertEquals(DeviceType.joystick, consumer.dataOfLastHandledCommand.device.type);
		assertEquals(3, consumer.dataOfLastHandledCommand.device.id);
	}
}
