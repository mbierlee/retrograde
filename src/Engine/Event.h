#pragma once

#include "Engine/Framework/IEvent.h"

namespace Engine {
	class Event
		: public Engine::Framework::IEvent
	{
	private:
		irr::u32 eventType;

	public:
		Event(irr::u32 eventType);
		virtual irr::u32 getType() const;
	};
}