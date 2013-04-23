#include "InputManager.h"

#include "Engine\Event.h"
#include "Engine\MagnitudeEvent.h"

#include <cmath>

Engine::InputManager::InputManager( std::shared_ptr<Engine::Framework::IEventManager> eventManager, irr::ILogger* logger)
	: eventManager(eventManager)
	, logger(logger)
{
	for (irr::u32 i = 0; i < irr::SEvent::SJoystickEvent::NUMBER_OF_BUTTONS; ++i) {
		joystickButtonPressedState[i] = false;
	}
}

void Engine::InputManager::handleMouseInput( const irr::SEvent& event )
{
	throw std::exception("The method or operation is not implemented.");
}

void Engine::InputManager::handleKeyboardInput( const irr::SEvent& event )
{
	if (keyboardInputBinding) {
		Engine::KeyboardInput input(event.KeyInput.Key, event.KeyInput.PressedDown);
		if (keyboardInputBinding->hasBinding(input)) {
			eventManager->postEvent(Engine::Event(keyboardInputBinding->getBoundEvent(input)), this);
		}
	}
}

void Engine::InputManager::handleJoystickInput( const irr::SEvent& event )
{
	if (joystickDigitalInputBinding) {
		for (irr::u32 i = 0; i < event.JoystickEvent.NUMBER_OF_BUTTONS; ++i) {
			bool previousButtonState = joystickButtonPressedState[i];
			joystickButtonPressedState[i] = event.JoystickEvent.IsButtonPressed(i);
			bool currentButtonState = joystickButtonPressedState[i];
			Engine::JoystickDigitalInput input(i, currentButtonState);
			if (previousButtonState != joystickButtonPressedState[i] && joystickDigitalInputBinding->hasBinding(input)) {
				eventManager->postEvent(Engine::Event(joystickDigitalInputBinding->getBoundEvent(input)), this);
			}
		}
	}

	if (joystickAnalogInputBinding) {
		for (irr::u32 i = 0; i < event.JoystickEvent.NUMBER_OF_AXES; ++i) {
			//TODO: Deadzone settings
			irr::s16 previousMagnitude = axisMagnitude[i];
			axisMagnitude[i] = event.JoystickEvent.Axis[i];
			irr::s16 currentMagnitude = axisMagnitude[i];
			Engine::JoystickAnalogInput input(i, currentMagnitude > 0);
			if (previousMagnitude != currentMagnitude && joystickAnalogInputBinding->hasBinding(input)) {
				eventManager->postEvent(Engine::MagnitudeEvent(joystickAnalogInputBinding->getBoundEvent(input), abs((irr::f32)currentMagnitude)), this);
			}
		}
	}
}

void Engine::InputManager::setKeyboardBinding( const std::shared_ptr<Engine::KeyboardInputBinding> binding )
{
	keyboardInputBinding = binding;
}

bool Engine::InputManager::OnEvent( const irr::SEvent& event )
{
	switch (event.EventType)
	{
	case irr::EET_KEY_INPUT_EVENT:
		handleKeyboardInput(event);
		break;
	case irr::EET_JOYSTICK_INPUT_EVENT:
		handleJoystickInput(event);
		break;
	}

	return false;
}

void Engine::InputManager::setJoystickDigitalBinding( const std::shared_ptr<Engine::JoystickDigitalInputBinding> binding )
{
	joystickDigitalInputBinding = binding;
}

void Engine::InputManager::setJoystickAnalogBinding( const std::shared_ptr<Engine::JoystickAnalogInputBinding> binding )
{
	joystickAnalogInputBinding = binding;
}