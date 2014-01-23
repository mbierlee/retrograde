#pragma once

#include "Engine/Base/BaseInputBinding.h"

#include <IEventReceiver.h>

namespace Engine {
	struct JoystickAnalogInput {
	public:
		JoystickAnalogInput(irr::u32 axis, bool positiveAxis)
			: Axis(axis)
			, PositiveAxis(positiveAxis)
		{
		}

		bool operator< (const JoystickAnalogInput& other) const
		{
			int myOrder = Axis + (PositiveAxis * irr::SEvent::SJoystickEvent::NUMBER_OF_AXES);
			int otherOrder = other.Axis + (other.PositiveAxis * irr::SEvent::SJoystickEvent::NUMBER_OF_AXES);
			return myOrder < otherOrder;
		}

		irr::u32 Axis;
		bool PositiveAxis;
	};

	class JoystickAnalogInputBinding
		: public Engine::Base::BaseInputBinding<JoystickAnalogInput>
	{
	};
}