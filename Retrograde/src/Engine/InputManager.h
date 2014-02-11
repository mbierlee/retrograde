#pragma once

#include "Engine/Framework/IInputManager.h"
#include "Engine/Framework/IEventManager.h"

#include <ILogger.h>
#include <IrrlichtDevice.h>
#include <ICursorControl.h>

namespace Engine {
	class InputManager
		: public Engine::Framework::IInputManager
		, public irr::IEventReceiver
	{
	private:
		std::shared_ptr<Engine::KeyboardInputBinding> keyboardInputBinding;
		std::shared_ptr<Engine::JoystickDigitalInputBinding> joystickDigitalInputBinding;
		std::shared_ptr<Engine::JoystickAnalogInputBinding> joystickAnalogInputBinding;
		std::shared_ptr<Engine::MouseEventInputBinding> mouseEventInputBinding;
		std::shared_ptr<Engine::MouseAnalogInputBinding> mouseAnalogInputBinding;
		std::shared_ptr<Engine::Framework::IEventManager> eventManager;
		irr::ILogger* logger;
		bool joystickButtonPressedState[irr::SEvent::SJoystickEvent::NUMBER_OF_BUTTONS];
		irr::s16 axisMagnitude[irr::SEvent::SJoystickEvent::NUMBER_OF_AXES];
		bool cancelAxes;
		irr::core::position2df relativeMousePosition;
		std::shared_ptr<irr::IrrlichtDevice> device;
		irr::core::vector2df previousPositionDiff;
		std::map<Engine::JoystickAnalogInput, irr::f32> joystickDeadzones;
		bool centerMouse;
		irr::gui::ICursorControl* cursorControl;

		void handleMouseMovement( irr::f32 posDiff, irr::f32 prevPosDiff, Engine::MouseAnalogInput negativeAxisInput, Engine::MouseAnalogInput positiveAxisInput );

	public:
		InputManager(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IEventManager> eventManager, irr::ILogger* logger = nullptr);

		virtual void handleMouseInput(const irr::SEvent& event);
		virtual void handleKeyboardInput(const irr::SEvent& event);
		virtual void handleJoystickInput(const irr::SEvent& event);

		virtual void setKeyboardBinding(const std::shared_ptr<Engine::KeyboardInputBinding> binding);
		virtual void setJoystickDigitalBinding(const std::shared_ptr<Engine::JoystickDigitalInputBinding> binding);
		virtual void setJoystickAnalogBinding(const std::shared_ptr<Engine::JoystickAnalogInputBinding> binding);
		virtual void setMouseEventBinding(const std::shared_ptr<Engine::MouseEventInputBinding> binding);
		virtual void setMouseAnalogBinding( const std::shared_ptr<Engine::MouseAnalogInputBinding> binding );

		virtual void setJoystickDeadzone(const Engine::JoystickAnalogInput& input, irr::f32 threshold);
		virtual irr::f32 getJoystickDeadzone(Engine::JoystickAnalogInput& input) const;
		virtual void setJoystickDeadzones(irr::f32 threshold);

		virtual void setMouseCentering( bool centerMouse );

		virtual const irr::core::position2df getRelativeMousePosition() const;
		virtual const irr::core::position2di& getAbsoluteMousePosition() const;

		virtual bool OnEvent( const irr::SEvent& event );
	};
}
