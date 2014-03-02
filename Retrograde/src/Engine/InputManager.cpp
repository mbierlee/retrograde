#include "InputManager.h"

#include "Engine\Event.h"
#include "Engine\MagnitudeEvent.h"
#include "Engine\BindingProperties.h"

#include <cmath>

Engine::InputManager::InputManager(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IEventService> eventService, irr::ILogger* logger)
	: eventService(eventService)
	, logger(logger)
	, cancelAxes(true)
	, device(device)
	, centerMouse(false)
	, cursorControl(nullptr)
{
	for (irr::u32 i = 0; i < irr::SEvent::SJoystickEvent::NUMBER_OF_BUTTONS; ++i) {
		joystickButtonPressedState[i] = false;
	}

	for (irr::u32 i = 0; i < irr::SEvent::SJoystickEvent::NUMBER_OF_AXES; ++i) {
		axisMagnitude[i] = 0;
	}

	if (device) {
		cursorControl = device->getCursorControl();
		if (cursorControl) {
			relativeMousePosition = cursorControl->getRelativePosition();
		}
	}
}

void Engine::InputManager::handleMouseInput( const irr::SEvent& event )
{
	if (mouseEventInputBinding) {
		if (mouseEventInputBinding->hasBinding(event.MouseInput.Event)) {
			const Engine::BindingProperties& properties = mouseEventInputBinding->getBoundEvent(event.MouseInput.Event);
			irr::f32 magnitude = !properties.IsInverted ? 1.f : 0;
			eventService->postEvent(Engine::MagnitudeEvent(properties.EventName, magnitude), this);
		}
	}

	if (mouseAnalogInputBinding) {
		if(event.MouseInput.Event == irr::EMIE_MOUSE_MOVED) {
			irr::core::vector2df previousPosition = relativeMousePosition;
			relativeMousePosition = getRelativeMousePosition();
			if (previousPosition != relativeMousePosition) {
				irr::core::vector2df positionDiff = relativeMousePosition - previousPosition;
				if (positionDiff.X != 0) {
					handleMouseMovement(positionDiff.X, previousPositionDiff.X, Engine::EMAI_MOUSE_LEFT, Engine::EMAI_MOUSE_RIGHT);
				}

				if (positionDiff.Y != 0) {
					handleMouseMovement(positionDiff.Y, previousPositionDiff.Y, Engine::EMAI_MOUSE_UP, Engine::EMAI_MOUSE_DOWN);
				}

				previousPositionDiff = positionDiff;
			}
		} else if (event.MouseInput.Event == irr::EMIE_MOUSE_WHEEL) {
			Engine::MouseAnalogInput wheelInput = (event.MouseInput.Wheel > 0) ? Engine::EMAI_WHEEL_UP : Engine::EMAI_WHEEL_DOWN;
			if (mouseAnalogInputBinding->hasBinding(wheelInput)) {
				const Engine::BindingProperties& properties = mouseAnalogInputBinding->getBoundEvent(wheelInput);
				irr::f32 magnitude = std::abs(event.MouseInput.Wheel);
				eventService->postEvent(Engine::MagnitudeEvent(properties.EventName, magnitude), this);
			}
		}
	}
}

void Engine::InputManager::handleKeyboardInput( const irr::SEvent& event )
{
	if (keyboardInputBinding) {
		if (keyboardInputBinding->hasBinding(event.KeyInput.Key)) {
			const Engine::BindingProperties& properties = keyboardInputBinding->getBoundEvent(event.KeyInput.Key);
			irr::f32 magnitude = event.KeyInput.PressedDown;
			if (properties.IsInverted) {
				magnitude = 1.f - magnitude;
			}

			eventService->postEvent(Engine::MagnitudeEvent(properties.EventName, event.KeyInput.PressedDown ? 1.f : 0), this);
		}
	}
}

void Engine::InputManager::handleJoystickInput( const irr::SEvent& event )
{
	if (joystickDigitalInputBinding) {
		for (irr::u32 i = 0; i < event.JoystickEvent.NUMBER_OF_BUTTONS; ++i) {
			bool previousButtonState = joystickButtonPressedState[i];
			joystickButtonPressedState[i] = event.JoystickEvent.IsButtonPressed(i);
			bool isPressed = joystickButtonPressedState[i];
			if (previousButtonState != joystickButtonPressedState[i] && joystickDigitalInputBinding->hasBinding(i)) {
				const Engine::BindingProperties& properties = joystickDigitalInputBinding->getBoundEvent(i);
				irr::f32 magnitude = (irr::f32)isPressed;
				if (properties.IsInverted) {
					magnitude = 1.f - magnitude;
				}

				eventService->postEvent(Engine::MagnitudeEvent(properties.EventName, magnitude), this);
			}
		}
	}

	if (joystickAnalogInputBinding) {
		for (irr::u32 i = 0; i < event.JoystickEvent.NUMBER_OF_AXES; ++i) {
			irr::s16 previousMagnitude = axisMagnitude[i];
			axisMagnitude[i] = event.JoystickEvent.Axis[i];
			irr::s16 currentMagnitude = axisMagnitude[i];
			Engine::JoystickAnalogInput input(i, currentMagnitude > 0);

			if (joystickAnalogInputBinding->hasBinding(input)) {
				irr::f32 eventMagnitude = irr::f32(std::abs(currentMagnitude) / 32768.f);
				if (joystickDeadzones.count(input) == 1 && joystickDeadzones.at(input) < eventMagnitude) {
					axisMagnitude[i] = currentMagnitude = 0;
					eventMagnitude = 0;
				}

				if (previousMagnitude != currentMagnitude) {
					const Engine::BindingProperties& properties = joystickAnalogInputBinding->getBoundEvent(input);
					eventService->postEvent(Engine::MagnitudeEvent(properties.EventName, eventMagnitude), this);

					// Cancel out the effect of the event on the other end of the axis.
					// When, for example, the magnitude was negative before and is positive now, we cancel
					// out the negative axis by sending an event with a magnitude of zero (or one if inverted)
					if ((previousMagnitude != 0 && currentMagnitude != 0)
						&& (!(previousMagnitude > 0) != !(currentMagnitude > 0))) {
							Engine::JoystickAnalogInput oppositeInput(i, !input.PositiveAxis);
							if (joystickAnalogInputBinding->hasBinding(oppositeInput)) {
								const Engine::BindingProperties& oppositeProperties = joystickAnalogInputBinding->getBoundEvent(oppositeInput);
								irr::f32 magnitude = oppositeProperties.IsInverted ? 1.f : 0;
								eventService->postEvent(Engine::MagnitudeEvent(oppositeProperties.EventName, magnitude), this);
							}
					}
				}
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
	case irr::EET_MOUSE_INPUT_EVENT:
		handleMouseInput(event);
		break;
	default:
		return false;
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

void Engine::InputManager::setMouseEventBinding( const std::shared_ptr<Engine::MouseEventInputBinding> binding )
{
	mouseEventInputBinding = binding;
}

void Engine::InputManager::setMouseAnalogBinding( const std::shared_ptr<Engine::MouseAnalogInputBinding> binding )
{
	mouseAnalogInputBinding = binding;
}

const irr::core::position2df Engine::InputManager::getRelativeMousePosition() const
{
	return cursorControl->getRelativePosition();
}

const irr::core::position2di& Engine::InputManager::getAbsoluteMousePosition() const
{
	return cursorControl->getPosition();
}

void Engine::InputManager::handleMouseMovement( irr::f32 posDiff, irr::f32 prevPosDiff, Engine::MouseAnalogInput negativeAxisInput, Engine::MouseAnalogInput positiveAxisInput )
{
	Engine::MouseAnalogInput inputType = (posDiff < 0) ? negativeAxisInput : positiveAxisInput;
	if (mouseAnalogInputBinding->hasBinding(inputType)) {
		irr::f32 magnitude = std::abs(posDiff);
		const Engine::BindingProperties& properties = mouseAnalogInputBinding->getBoundEvent(inputType);
		if (properties.IsInverted) {
			magnitude = 1.f - magnitude;
		}

		eventService->postEvent(Engine::MagnitudeEvent(properties.EventName, magnitude), this);
		if (centerMouse) {
			relativeMousePosition = irr::core::position2df(0.5);
			cursorControl->setPosition(relativeMousePosition);
		}
	}

	// Cancel out magnitude by sending a magnitude event of 0 to the other "axis"
	// This behavior keeps eventing consistent for both mouse and joystick inputs.
	Engine::MouseAnalogInput previousInputType = (prevPosDiff < 0) ? negativeAxisInput : positiveAxisInput;
	if (previousInputType != inputType) {
		if (mouseAnalogInputBinding->hasBinding(previousInputType)) {
			const Engine::BindingProperties& properties = mouseAnalogInputBinding->getBoundEvent(previousInputType);
			eventService->postEvent(Engine::MagnitudeEvent(properties.EventName, 0), this);
		}
	}
}

void Engine::InputManager::setJoystickDeadzone(const Engine::JoystickAnalogInput& input, irr::f32 threshold)
{
	joystickDeadzones.insert(std::pair<Engine::JoystickAnalogInput, irr::f32>(input, threshold));
}

void Engine::InputManager::setJoystickDeadzones(irr::f32 threshold)
{
	for (irr::u32 i =0; i < irr::SEvent::SJoystickEvent::NUMBER_OF_AXES; ++i)
	{
		setJoystickDeadzone(Engine::JoystickAnalogInput(i, true), threshold);
		setJoystickDeadzone(Engine::JoystickAnalogInput(i, false), threshold);
	}
}

irr::f32 Engine::InputManager::getJoystickDeadzone(Engine::JoystickAnalogInput& input) const
{
	return joystickDeadzones.at(input);
}

void Engine::InputManager::setMouseCentering( bool centerMouse )
{
	this->centerMouse = centerMouse;
}
