#include "Event.h"

Engine::Event::Event( irr::u32 eventType )
	: eventType(eventType)
{
}

irr::u32 Engine::Event::getType() const
{
	return eventType;
}