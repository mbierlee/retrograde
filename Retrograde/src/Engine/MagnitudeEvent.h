#pragma once

#include "Engine/Event.h"

namespace Engine {
	class MagnitudeEvent
		: public Event
	{
	private:
		irr::f32 magnitude;

	public:
		MagnitudeEvent(const irr::core::stringc& eventName, irr::f32 magnitude);
		irr::f32 getMagnitude() const;
		virtual bool operator ==( const IEvent& obj ) const override;
	};
}
