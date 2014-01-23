#pragma once

#include "Engine/Base/BaseInputBinding.h"

#include <IEventReceiver.h>

namespace Engine {
	class KeyboardInputBinding
		: public Engine::Base::BaseInputBinding<irr::EKEY_CODE>
	{
	};
}
