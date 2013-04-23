#include "MagnitudeEvent.h"

Engine::MagnitudeEvent::MagnitudeEvent(const irr::core::stringc& eventName, irr::f32 magnitude)
	: Engine::Event(eventName)
	, magnitude(magnitude)
{
}

irr::f32 Engine::MagnitudeEvent::getMagnitude() const
{
	return magnitude;
}

bool Engine::MagnitudeEvent::operator==( const IEvent& obj ) const
{
	const MagnitudeEvent* magObj = dynamic_cast<const MagnitudeEvent*>(&obj);
	if (!magObj) {
		return false;
	}

	return eventName == magObj->getName() && magnitude == magObj->getMagnitude();
}