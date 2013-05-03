#pragma once

#include "Engine/Base/BaseInputBinding.h"

namespace Engine {
	enum MouseAnalogInput
	{
		EMAI_MOUSE_UP,
		EMAI_MOUSE_DOWN,
		EMAI_MOUSE_LEFT,
		EMAI_MOUSE_RIGHT,
		EMAI_WHEEL_UP,
		EMAI_WHEEL_DOWN
	};

	class MouseAnalogInputBinding
		: public Engine::Base::BaseInputBinding<MouseAnalogInput>
	{
	};
}