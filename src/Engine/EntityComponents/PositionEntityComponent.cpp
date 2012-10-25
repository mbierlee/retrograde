#include "PositionEntityComponent.h"

const irr::core::stringc Engine::EntityComponents::PositionEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::PositionEntityComponent::getFamilyType() const
{
	return familyType();
}

void Engine::EntityComponents::PositionEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{	
}

const irr::core::stringc Engine::EntityComponents::PositionEntityComponent::componentType()
{
	return "PositionEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::PositionEntityComponent::familyType()
{
	return "PositionEntityComponent";
}

const irr::core::vector3df& Engine::EntityComponents::PositionEntityComponent::getPosition() const
{
	return position;
}

void Engine::EntityComponents::PositionEntityComponent::setPosition( const irr::core::vector3df& position )
{
	this->position = position;
}
