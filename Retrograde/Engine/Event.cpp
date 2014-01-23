#include "Event.h"

Engine::Event::Event(const irr::core::stringc& eventName)
	: eventName(eventName)
{
}

const irr::core::stringc& Engine::Event::getName() const
{
	return eventName;
}

bool Engine::Event::operator==( const IEvent& obj ) const
{
	return obj.getName() == eventName;
}