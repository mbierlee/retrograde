#pragma once

#include "Engine/KeyboardInputBinding.h"

#include <IEventReceiver.h>

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
	};
}}