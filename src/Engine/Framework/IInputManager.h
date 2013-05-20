#pragma once

#include "Engine/KeyboardInputBinding.h"
#include "Engine/JoystickDigitalInputBinding.h"
#include "Engine/JoystickAnalogInputBinding.h"
#include "Engine/MouseEventInputBinding.h"
#include "Engine/MouseAnalogInputBinding.h"

#include <IEventReceiver.h>
#include <position2d.h>

#include <memory>

namespace Engine { namespace Framework {
	class IInputManager
	{
	public:
		virtual ~IInputManager() {}

		virtual void handleMouseInput(const irr::SEvent& event) =0;
		virtual void handleKeyboardInput(const irr::SEvent& event) =0;
		virtual void handleJoystickInput(const irr::SEvent& event) =0;

		virtual void setKeyboardBinding(const std::shared_ptr<Engine::KeyboardInputBinding> binding) =0;
		virtual void setJoystickDigitalBinding(const std::shared_ptr<Engine::JoystickDigitalInputBinding> binding) =0;
		virtual void setJoystickAnalogBinding(const std::shared_ptr<Engine::JoystickAnalogInputBinding> binding) =0;
		virtual void setMouseEventBinding(const std::shared_ptr<Engine::MouseEventInputBinding> binding) =0;
		virtual void setMouseAnalogBinding(const std::shared_ptr<Engine::MouseAnalogInputBinding> binding) =0;

		virtual void setJoystickDeadzone(Engine::JoystickAnalogInput& input, irr::f32 threshold) =0;
		virtual irr::f32 getJoystickDeadzone(Engine::JoystickAnalogInput& input) const =0;
		virtual void setJoystickDeadzones(irr::f32 threshold) =0;

		virtual void setMouseCentering(bool centerMouse) =0;

		virtual const irr::core::position2df getRelativeMousePosition() const =0;
		virtual const irr::core::position2di& getAbsoluteMousePosition() const =0;
	};
}}