#include "FirstPersonInputEntityComponent.h"

Engine::EntityComponents::FirstPersonInputEntityComponent::FirstPersonInputEntityComponent(
	irr::core::stringc moveForwardEvent, irr::core::stringc moveBackwardEvent,
	irr::core::stringc moveLeftEvent, irr::core::stringc moveRightEvent,
	irr::core::stringc turnLeftEvent, irr::core::stringc turnRightEvent)
	: subscribedToEvents(false)
	, moveForwardEvent(moveForwardEvent)
	, moveBackwardEvent(moveBackwardEvent)
	, moveLeftEvent(moveLeftEvent)
	, moveRightEvent(moveRightEvent)
	, turnLeftEvent(turnLeftEvent)
	, turnRightEvent(turnRightEvent)
{
}

const irr::core::stringc Engine::EntityComponents::FirstPersonInputEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::FirstPersonInputEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::FirstPersonInputEntityComponent::componentType()
{
	return "FirstPersonInputEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::FirstPersonInputEntityComponent::familyType()
{
	return "FirstPersonInputEntityComponent";
}

void Engine::EntityComponents::FirstPersonInputEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (!subscribedToEvents) {
		entity->subscribeToEvents(shared_from_this());
		subscribedToEvents = true;
	}
}

void Engine::EntityComponents::FirstPersonInputEntityComponent::handleEvent( const Engine::Framework::IEvent& event, Engine::Framework::IEntity* entity, void* source )
{
	if (event.getName() == moveForwardEvent) {
	} else if (event.getName() == moveBackwardEvent) {
	} else if (event.getName() == moveLeftEvent) {
	} else if (event.getName() == moveRightEvent) {
	} else if (event.getName() == turnLeftEvent) {
	} else if (event.getName() == turnRightEvent) {
	}
}