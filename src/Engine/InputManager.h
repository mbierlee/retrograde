#pragma once

#include "Engine/Framework/IInputManager.h"
#include "Engine/Framework/IEventManager.h"
#include "Engine/KeyboardInputBinding.h"
#include "Engine/JoystickDigitalInputBinding.h"
#include "Engine/JoystickAnalogInputBinding.h"

#include <ILogger.h>

namespace Engine {
	class InputManager
		: public Engine::Framework::IInputManager
		, public irr::IEventReceiver
	{
	private:
		std::shared_ptr<Engine::KeyboardInputBinding> keyboardInputBinding;
		std::shared_ptr<Engine::JoystickDigitalInputBinding> joystickDigitalInputBinding;
		std::shared_ptr<Engine::JoystickAnalogInputBinding> joystickAnalogInputBinding;
		std::shared_ptr<Engine::Framework::IEventManager> eventManager;
		irr::ILogger* logger;
		bool joystickButtonPressedState[irr::SEvent::SJoystickEvent::NUMBER_OF_BUTTONS];
		irr::s16 axisMagnitude[irr::SEvent::SJoystickEvent::NUMBER_OF_AXES];

	public:
		InputManager(std::shared_ptr<Engine::Framework::IEventManager> eventManager, irr::ILogger* logger = nullptr);

		virtual void handleMouseInput(const irr::SEvent& event);
		virtual void handleKeyboardInput(const irr::SEvent& event);
		virtual void handleJoystickInput(const irr::SEvent& event);

		virtual void setKeyboardBinding(const std::shared_ptr<Engine::KeyboardInputBinding> binding);
		virtual void setJoystickDigitalBinding(const std::shared_ptr<Engine::JoystickDigitalInputBinding> binding);
		virtual void setJoystickAnalogBinding(const std::shared_ptr<Engine::JoystickAnalogInputBinding> binding);
		virtual bool OnEvent( const irr::SEvent& event );
	};
}