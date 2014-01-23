#pragma once

#include "Engine/Base/BaseInputBinding.h"

#include <IEventReceiver.h>

namespace Engine {
	class MouseEventInputBinding
		: public Engine::Base::BaseInputBinding<irr::EMOUSE_INPUT_EVENT>
	{
	};
}