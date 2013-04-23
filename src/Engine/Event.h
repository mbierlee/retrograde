#pragma once

#include "Engine/Framework/IEvent.h"

namespace Engine {
	class Event
		: public Engine::Framework::IEvent
	{
	protected:
		irr::core::stringc eventName;

	public:
		Event(const irr::core::stringc& eventName);
		virtual const irr::core::stringc& getName() const;
		virtual bool operator ==( const IEvent& obj ) const;
	};
}