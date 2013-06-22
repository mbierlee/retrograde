#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <Engine/InputManager.h>
#include <Engine/Framework/IEventManager.h>
#include <Engine/Event.h>
#include <Engine/MagnitudeEvent.h>
#include <Engine/KeyboardInputBinding.h>
#include <Engine/JoystickDigitalInputBinding.h>
#include <Engine/MouseEventInputBinding.h>
#include <Engine/MouseAnalogInputBinding.h>

#include <IEventReceiver.h>
#include <ILogger.h>
#include <IrrlichtDevice.h>
#include <ICursorControl.h>

using ::testing::Return;
using ::testing::Eq;
using ::testing::AtLeast;
using ::testing::_;

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

	class MockDevice
		: public irr::IrrlichtDevice
	{
	public:

		virtual bool run()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void yield()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void sleep( irr::u32 timeMs, bool pauseTimer=false )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::video::IVideoDriver* getVideoDriver()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::io::IFileSystem* getFileSystem()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::gui::IGUIEnvironment* getGUIEnvironment()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::scene::ISceneManager* getSceneManager()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		MOCK_METHOD0(getCursorControl, irr::gui::ICursorControl*());

		virtual irr::ILogger* getLogger()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::video::IVideoModeList* getVideoModeList()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::IOSOperator* getOSOperator()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::ITimer* getTimer()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::IRandomizer* getRandomizer() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void setRandomizer( irr::IRandomizer* r )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::IRandomizer* createDefaultRandomizer() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void setWindowCaption( const wchar_t* text )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool isWindowActive() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool isWindowFocused() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool isWindowMinimized() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool isFullscreen() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::video::ECOLOR_FORMAT getColorFormat() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void closeDevice()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual const irr::c8* getVersion() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void setEventReceiver( irr::IEventReceiver* receiver )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::IEventReceiver* getEventReceiver()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool postEventFromUser( const irr::SEvent& event )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void setInputReceivingSceneManager( irr::scene::ISceneManager* sceneManager )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void setResizable( bool resize=false )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void minimizeWindow()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void maximizeWindow()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void restoreWindow()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::core::position2di getWindowPosition()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool activateJoysticks( irr::core::array<irr::SJoystickInfo>& joystickInfo )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool setGammaRamp( irr::f32 red, irr::f32 green, irr::f32 blue, irr::f32 relativebrightness, irr::f32 relativecontrast )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool getGammaRamp( irr::f32 &red, irr::f32 &green, irr::f32 &blue, irr::f32 &brightness, irr::f32 &contrast )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void clearSystemMessages()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual irr::E_DEVICE_TYPE getType() const
		{
			throw std::exception("The method or operation is not implemented.");
		}
	};

	class MockCursorControl
		: public irr::gui::ICursorControl
	{
	public:

		virtual void setVisible( bool visible )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual bool isVisible() const
		{
			throw std::exception("The method or operation is not implemented.");
		}

		MOCK_METHOD1(setPosition, void(const irr::core::position2d<irr::f32>& position));

		virtual void setPosition( irr::f32 x, irr::f32 y )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void setPosition( const irr::core::position2d<irr::s32> &pos )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual void setPosition( irr::s32 x, irr::s32 y )
		{
			throw std::exception("The method or operation is not implemented.");
		}

		virtual const irr::core::position2d<irr::s32>& getPosition()
		{
			throw std::exception("The method or operation is not implemented.");
		}

		MOCK_METHOD0(getRelativePosition, irr::core::position2d<irr::f32>());

		virtual void setReferenceRect( irr::core::rect<irr::s32>* rect=0 )
		{
			throw std::exception("The method or operation is not implemented.");
		}
	};
}

TEST(InputManagerTest, testHandleKeyboardInput) {
	std::shared_ptr<irr::IrrlichtDevice> nullDevice;
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	Engine::InputManager inputManager(nullDevice, mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_KEY_INPUT_EVENT;
	event.KeyInput.PressedDown = true;
	event.KeyInput.Key = irr::KEY_RETURN;

	std::shared_ptr<Engine::KeyboardInputBinding> keyboardBinding = std::make_shared<Engine::KeyboardInputBinding>();
	keyboardBinding->bind(irr::KEY_RETURN, "ev_test_pressed");
	inputManager.setKeyboardBinding(keyboardBinding);

	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_test_pressed", 1.0f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_test_pressed", 0)), &inputManager)).WillOnce(Return());

	EXPECT_FALSE(inputManager.OnEvent(event));
	event.KeyInput.PressedDown = false;
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleKeyboardInputWithNoBinding) {
	std::shared_ptr<irr::IrrlichtDevice> nullDevice;
	RetrogradeTest::MockLogger mockLogger;
	std::shared_ptr<Engine::Framework::IEventManager> nullEventManager;
	Engine::InputManager inputManager(nullDevice, nullEventManager, &mockLogger);

	irr::SEvent event;
	event.EventType = irr::EET_KEY_INPUT_EVENT;
	event.KeyInput.Key = irr::KEY_RETURN;

	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleJoystickDigitalInput) {
	std::shared_ptr<irr::IrrlichtDevice> nullDevice;
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	Engine::InputManager inputManager(nullDevice, mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_JOYSTICK_INPUT_EVENT;
	event.JoystickEvent.ButtonStates = 2;

	std::shared_ptr<Engine::JoystickDigitalInputBinding> joystickBinding = std::make_shared<Engine::JoystickDigitalInputBinding>();
	joystickBinding->bind(1, "ev_test_pressed");
	inputManager.setJoystickDigitalBinding(joystickBinding);

	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_test_pressed", 1.f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_test_pressed", 0)), &inputManager)).WillOnce(Return());

	EXPECT_FALSE(inputManager.OnEvent(event));
	event.JoystickEvent.ButtonStates = 0;
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleJoystickAnalogInput) {
	std::shared_ptr<irr::IrrlichtDevice> nullDevice;
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	Engine::InputManager inputManager(nullDevice, mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_JOYSTICK_INPUT_EVENT;
	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_X] = 300;

	std::shared_ptr<Engine::JoystickAnalogInputBinding> joystickBinding = std::make_shared<Engine::JoystickAnalogInputBinding>();
	joystickBinding->bind(Engine::JoystickAnalogInput(irr::SEvent::SJoystickEvent::AXIS_X, true), "ev_xaxis_right");
	joystickBinding->bind(Engine::JoystickAnalogInput(irr::SEvent::SJoystickEvent::AXIS_X, false), "ev_xaxis_left");
	inputManager.setJoystickAnalogBinding(joystickBinding);

	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_xaxis_right", 300 / 32768.f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_xaxis_left", 300 / 32768.f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_xaxis_right", 0.f)), &inputManager)).WillOnce(Return());

	EXPECT_FALSE(inputManager.OnEvent(event));
	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_X] = -300;
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleJoystickInputWithNoBinding) {
	std::shared_ptr<irr::IrrlichtDevice> nullDevice;
	RetrogradeTest::MockLogger mockLogger;
	std::shared_ptr<Engine::Framework::IEventManager> nullEventManager;
	Engine::InputManager inputManager(nullDevice, nullEventManager, &mockLogger);

	irr::SEvent event;
	event.EventType = irr::EET_JOYSTICK_INPUT_EVENT;
	event.JoystickEvent.ButtonStates = 1 << 1;

	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleMouseEventBinding) {
	std::shared_ptr<irr::IrrlichtDevice> nullDevice;
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	Engine::InputManager inputManager(nullDevice, mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_MOUSE_INPUT_EVENT;
	event.MouseInput.Event = irr::EMIE_LMOUSE_PRESSED_DOWN;

	std::shared_ptr<Engine::MouseEventInputBinding> mouseBinding = std::make_shared<Engine::MouseEventInputBinding>();
	mouseBinding->bind(irr::EMIE_LMOUSE_PRESSED_DOWN, "ev_clickyclicky");
	mouseBinding->bind(irr::EMIE_LMOUSE_LEFT_UP, "ev_clickyclicky", true);
	inputManager.setMouseEventBinding(mouseBinding);

	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_clickyclicky", 1.f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_clickyclicky", 0)), &inputManager)).WillOnce(Return());

	EXPECT_FALSE(inputManager.OnEvent(event));
	event.MouseInput.Event = irr::EMIE_LMOUSE_LEFT_UP;
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleMouseEventBindingWithNoBinding) {
	std::shared_ptr<irr::IrrlichtDevice> nullDevice;
	RetrogradeTest::MockLogger mockLogger;
	std::shared_ptr<Engine::Framework::IEventManager> nullEventManager;
	Engine::InputManager inputManager(nullDevice, nullEventManager, &mockLogger);

	irr::SEvent event;
	event.EventType = irr::EET_MOUSE_INPUT_EVENT;
	event.MouseInput.ButtonStates = irr::EMBSM_LEFT;

	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleMouseAnalogBinding) {
	std::shared_ptr<RetrogradeTest::MockDevice> mockDevice = std::make_shared<RetrogradeTest::MockDevice>();
	std::shared_ptr<RetrogradeTest::MockCursorControl> mockCursorControl = std::make_shared<RetrogradeTest::MockCursorControl>();
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	EXPECT_CALL(*mockDevice, getCursorControl()).WillOnce(Return(mockCursorControl.get()));
	EXPECT_CALL(*mockCursorControl, getRelativePosition()).WillOnce(Return(irr::core::position2df(0.5f, 0.5f)));
	Engine::InputManager inputManager(mockDevice, mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_MOUSE_INPUT_EVENT;
	event.MouseInput.Event = irr::EMIE_MOUSE_MOVED;

	std::shared_ptr<Engine::MouseAnalogInputBinding> mouseBinding = std::make_shared<Engine::MouseAnalogInputBinding>();
	mouseBinding->bind(Engine::EMAI_MOUSE_LEFT, "ev_left");
	mouseBinding->bind(Engine::EMAI_MOUSE_RIGHT, "ev_right");
	mouseBinding->bind(Engine::EMAI_MOUSE_UP, "ev_up");
	mouseBinding->bind(Engine::EMAI_MOUSE_DOWN, "ev_down");
	mouseBinding->bind(Engine::EMAI_WHEEL_UP, "ev_wheel_up");
	mouseBinding->bind(Engine::EMAI_WHEEL_DOWN, "ev_wheel_down");
	inputManager.setMouseAnalogBinding(mouseBinding);

	EXPECT_CALL(*mockCursorControl, getRelativePosition()).WillOnce(Return(irr::core::position2df(0.f, 0.5f)));
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_left", 0.5f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_right", 0)), &inputManager)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));

	EXPECT_CALL(*mockCursorControl, getRelativePosition()).WillOnce(Return(irr::core::position2df(1.f, 0.5f)));
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_right", 1.f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_left", 0)), &inputManager)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));

	EXPECT_CALL(*mockCursorControl, getRelativePosition()).WillOnce(Return(irr::core::position2df(1.f, 0)));
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_up", 0.5f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_down", 0)), &inputManager)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));

	EXPECT_CALL(*mockCursorControl, getRelativePosition()).WillOnce(Return(irr::core::position2df(1.f, 1.f)));
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_down", 1.f)), &inputManager)).WillOnce(Return());
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_up", 0)), &inputManager)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.EventType = irr::EET_MOUSE_INPUT_EVENT;
	event.MouseInput.Event = irr::EMIE_MOUSE_WHEEL;
	event.MouseInput.Wheel = 1.f;
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_wheel_up", 1.f)), &inputManager)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.MouseInput.Wheel = -1.f;
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_wheel_down", 1.f)), &inputManager)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testHandleJoystickDeadzones) {
	std::shared_ptr<irr::IrrlichtDevice> nullDevice;
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	Engine::InputManager inputManager(nullDevice, mockEventManager);

	irr::SEvent event;
	event.EventType = irr::EET_JOYSTICK_INPUT_EVENT;

	std::shared_ptr<Engine::JoystickAnalogInputBinding> joystickBinding = std::make_shared<Engine::JoystickAnalogInputBinding>();
	joystickBinding->bind(Engine::JoystickAnalogInput(irr::SEvent::SJoystickEvent::AXIS_X, true), "ev_xaxis_right");
	joystickBinding->bind(Engine::JoystickAnalogInput(irr::SEvent::SJoystickEvent::AXIS_X, false), "ev_xaxis_left");
	joystickBinding->bind(Engine::JoystickAnalogInput(irr::SEvent::SJoystickEvent::AXIS_Y, false), "ev_yaxis_up");
	joystickBinding->bind(Engine::JoystickAnalogInput(irr::SEvent::SJoystickEvent::AXIS_Y, true), "ev_yaxis_down");
	inputManager.setJoystickAnalogBinding(joystickBinding);

	irr::f32 deadzone = 200.f / 32768;
	inputManager.setJoystickDeadzones(deadzone);

	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_X] = 100;
	EXPECT_CALL(*mockEventManager, postEvent(_, _)).Times(1);
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_X] = 300;
	EXPECT_CALL(*mockEventManager, postEvent(_, _)).Times(1);
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_X] = -100;
	EXPECT_CALL(*mockEventManager, postEvent(_, _)).Times(1);
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_X] = -300;
	EXPECT_CALL(*mockEventManager, postEvent(_, _)).Times(1);
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_Y] = -100;
	EXPECT_CALL(*mockEventManager, postEvent(_, _)).Times(1);
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_Y] = -300;
	EXPECT_CALL(*mockEventManager, postEvent(_, _)).Times(1);
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_Y] = 100;
	EXPECT_CALL(*mockEventManager, postEvent(_, _)).Times(1);
	EXPECT_FALSE(inputManager.OnEvent(event));

	event.JoystickEvent.Axis[event.JoystickEvent.AXIS_Y] = 300;
	EXPECT_CALL(*mockEventManager, postEvent(_, _)).Times(1);
	EXPECT_FALSE(inputManager.OnEvent(event));
}

TEST(InputManagerTest, testMouseCentering) {
	std::shared_ptr<RetrogradeTest::MockDevice> mockDevice = std::make_shared<RetrogradeTest::MockDevice>();
	std::shared_ptr<RetrogradeTest::MockCursorControl> mockCursorControl = std::make_shared<RetrogradeTest::MockCursorControl>();
	std::shared_ptr<RetrogradeTest::MockEventManager> mockEventManager = std::make_shared<RetrogradeTest::MockEventManager>();
	EXPECT_CALL(*mockDevice, getCursorControl()).WillOnce(Return(mockCursorControl.get()));
	EXPECT_CALL(*mockCursorControl, setPosition(irr::core::position2df(0.5f))).WillRepeatedly(Return());
	EXPECT_CALL(*mockCursorControl, getRelativePosition()).WillOnce(Return(irr::core::position2df(0.5f)));
	Engine::InputManager inputManager(mockDevice, mockEventManager);
	inputManager.setMouseCentering(true);

	irr::SEvent event;
	event.EventType = irr::EET_MOUSE_INPUT_EVENT;
	event.MouseInput.Event = irr::EMIE_MOUSE_MOVED;
	std::shared_ptr<Engine::MouseAnalogInputBinding> mouseBinding = std::make_shared<Engine::MouseAnalogInputBinding>();
	mouseBinding->bind(Engine::EMAI_MOUSE_LEFT, "ev_left");
	inputManager.setMouseAnalogBinding(mouseBinding);

	EXPECT_CALL(*mockCursorControl, getRelativePosition()).WillOnce(Return(irr::core::position2df(0.f, 0.5f)));
	EXPECT_CALL(*mockEventManager, postEvent(Eq(Engine::MagnitudeEvent("ev_left", 0.5f)), &inputManager)).WillOnce(Return());
	EXPECT_FALSE(inputManager.OnEvent(event));
	EXPECT_CALL(*mockCursorControl, getRelativePosition()).WillOnce(Return(irr::core::position2df(0.5f)));
	EXPECT_EQ(irr::core::position2df(0.5f), inputManager.getRelativeMousePosition());
}