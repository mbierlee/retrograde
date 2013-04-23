#pragma once

#include "Engine/Base/BaseInputBinding.h"

namespace Engine {
	struct JoystickDigitalInput {
	public:
		JoystickDigitalInput(irr::u32 button, bool pressedDown)
			: Button(button)
			, PressedDown(pressedDown)
		{
		}

		bool operator< (const JoystickDigitalInput& other) const
		{
			int myOrder = Button + (PressedDown * irr::SEvent::SJoystickEvent::NUMBER_OF_BUTTONS);
			int otherOrder = other.Button + (other.PressedDown * irr::SEvent::SJoystickEvent::NUMBER_OF_BUTTONS);
			return myOrder < otherOrder;
		}

		irr::u32 Button;
		bool PressedDown;
	};

	class JoystickDigitalInputBinding
		: public Engine::Base::BaseInputBinding<JoystickDigitalInput>
	{
	};
}