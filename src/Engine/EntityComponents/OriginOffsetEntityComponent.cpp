#include "OriginOffsetEntityComponent.h"

Engine::EntityComponents::OriginOffsetEntityComponent::OriginOffsetEntityComponent( const irr::core::vector3df& origin )
	: origin(origin)
{
}

const irr::core::stringc Engine::EntityComponents::OriginOffsetEntityComponent::getComponentType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::OriginOffsetEntityComponent::getFamilyType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::OriginOffsetEntityComponent::componentType()
{
	return "OriginOffsetEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::OriginOffsetEntityComponent::familyType()
{
	return "OriginOffsetEntityComponent";
}

void Engine::EntityComponents::OriginOffsetEntityComponent::setOrigin( const irr::core::vector3df& origin )
{
	this->origin = origin;
}

const irr::core::vector3df& Engine::EntityComponents::OriginOffsetEntityComponent::getOrigin() const
{
	return origin;
}

void Engine::EntityComponents::OriginOffsetEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}