#pragma once

#include "Engine/Base/BaseInputBinding.h"

#include <IEventReceiver.h>

namespace Engine {
	struct KeyboardInput {
	public:
		KeyboardInput(irr::EKEY_CODE keyCode, bool pressedDown = true)
			: KeyCode(keyCode)
			, PressedDown(pressedDown)
		{
		}

		bool operator< (const KeyboardInput& other) const
		{
			int myOrder = KeyCode + (PressedDown * irr::KEY_KEY_CODES_COUNT);
			int otherOrder = other.KeyCode + (other.PressedDown * irr::KEY_KEY_CODES_COUNT);
			return myOrder < otherOrder;
		}

		irr::EKEY_CODE KeyCode;
		bool PressedDown;
	};

	class KeyboardInputBinding
		: public Engine::Base::BaseInputBinding<Engine::KeyboardInput>
	{
	};
}
