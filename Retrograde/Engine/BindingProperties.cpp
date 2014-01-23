#include "BindingProperties.h"

Engine::BindingProperties::BindingProperties( const irr::core::stringc& eventName, bool isInverted )
	: EventName(eventName)
	, IsInverted(isInverted)
{
}