#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <Engine/InputManager.h>
#include <Engine/Framework/IEventManager.h>
#include <Engine/Event.h>
#include <Engine/MagnitudeEvent.h>
#include <Engine/KeyboardInputBinding.h>
#include <Engine/JoystickDigitalInputBinding.h>

#include <IEventReceiver.h>
#include <ILogger.h>

using ::testing::Return;
using ::testing::Eq;
using ::testing::AtLeast;

namespace RetrogradeTest {
	class MockEventManager
		: public Engine::Framework::IEventManager
	{
	public:
		MOCK_METHOD2(postEvent, void(const Engine::Framework::IEvent& event, void* source));

		virtual void registerObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void unregisterObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool hasObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void clearObservers()
		{
			throw std::exception("The method or operation is not implemented.");
		}
	};

	class MockLogger
		: public irr::ILogger
	{
	public:
		virtual irr::ELOG_LEVEL getLogLevel() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void setLogLevel( irr::ELOG_LEVEL ll )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void log( const irr::c8* text, irr::ELOG_LEVEL ll=irr::ELL_INFORMATION )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void log( const irr::c8* text, const irr::c8* hint, irr::ELOG_LEVEL ll=irr::ELL_INFORMATION )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void log( const irr::c8* text, const wchar_t* hint, irr::ELOG_LEVEL ll=irr::ELL_INFORMATION )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void log( const wchar_t* text, const wchar_t* hint, irr::ELOG_LEVEL ll=irr::ELL_INFORMATION )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		MOCK_METHOD2(log, void(const wchar_t* text, irr::ELOG_LEVEL ll));
	};
}

TEST(InputManagerTest, testHandleKeyboardInput) {
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	Engine::InputManager inputManager(mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_KEY_INPUT_EVENT;
	event.KeyInput.PressedDown = true;
	event.KeyInput.Key = irr::KEY_RETURN;

	std::shared_ptr<Engine::KeyboardInputBinding> keyboardBinding = std::make_shared<Engine::KeyboardInputBinding>();
	Engine::KeyboardInput input(irr::KEY_RETURN);
	keyboardBinding->bind(input, "ev_test_pressed");
	input.PressedDown = false;
	keyboardBinding->bind(input, "ev_test_depressed");
	inputManager.setKeyboardBinding(keyboardBinding);

	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::Event("ev_test_pressed")), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::Event("ev_test_depressed")), &inputManager)).WillOnce(Return());

	EXPECT_FALSE(inputManager.OnEvent(event));
	event.KeyInput.PressedDown = false;
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleKeyboardInputWithNoBinding) {
	RetrogradeTest::MockLogger mockLogger;
	std::shared_ptr<Engine::Framework::IEventManager> nullEventManager;
	Engine::InputManager inputManager(nullEventManager, &mockLogger);

	irr::SEvent event;
	event.EventType = irr::EET_KEY_INPUT_EVENT;
	event.KeyInput.Key = irr::KEY_RETURN;

	//EXPECT_CALL(mockLogger, log(L"Unable to handle keyboard input: No bindings set", irr::ELL_WARNING)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleJoystickDigitalInput) {
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	Engine::InputManager inputManager(mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_JOYSTICK_INPUT_EVENT;
	event.JoystickEvent.ButtonStates = 2;

	std::shared_ptr<Engine::JoystickDigitalInputBinding> joystickBinding = std::make_shared<Engine::JoystickDigitalInputBinding>();
	joystickBinding->bind(Engine::JoystickDigitalInput(1, true), "ev_test_pressed");
	joystickBinding->bind(Engine::JoystickDigitalInput(1, false), "ev_test_depressed");
	inputManager.setJoystickDigitalBinding(joystickBinding);

	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::Event("ev_test_pressed")), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::Event("ev_test_depressed")), &inputManager)).WillOnce(Return());

	EXPECT_FALSE(inputManager.OnEvent(event));
	event.JoystickEvent.ButtonStates = 0;
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleJoystickAnalogInput) {
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	Engine::InputManager inputManager(mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_JOYSTICK_INPUT_EVENT;
	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_X] = 300;

	std::shared_ptr<Engine::JoystickAnalogInputBinding> joystickBinding = std::make_shared<Engine::JoystickAnalogInputBinding>();
	joystickBinding->bind(Engine::JoystickAnalogInput(irr::SEvent::SJoystickEvent::AXIS_X, false), "ev_xaxis_right");
	joystickBinding->bind(Engine::JoystickAnalogInput(irr::SEvent::SJoystickEvent::AXIS_X, true), "ev_xaxis_left");
	inputManager.setJoystickAnalogBinding(joystickBinding);

	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_xaxis_right", 300.f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_xaxis_left", 300.f)), &inputManager)).WillOnce(Return());

	EXPECT_FALSE(inputManager.OnEvent(event));
	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_X] = -300;
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleJoystickInputWithNoBinding) {
	RetrogradeTest::MockLogger mockLogger;
	std::shared_ptr<Engine::Framework::IEventManager> nullEventManager;
	Engine::InputManager inputManager(nullEventManager, &mockLogger);

	irr::SEvent event;
	event.EventType = irr::EET_JOYSTICK_INPUT_EVENT;
	event.JoystickEvent.ButtonStates = 1 << 1;

	//EXPECT_CALL(mockLogger, log(L"Unable to handle joystick/gamepad input: No bindings set", irr::ELL_WARNING)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));
}	