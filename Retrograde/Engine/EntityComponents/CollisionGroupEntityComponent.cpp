#include "CollisionGroupEntityComponent.h"

Engine::EntityComponents::CollisionGroupEntityComponent::CollisionGroupEntityComponent(irr::s16 group)
	: group(group)
{
}

const irr::core::stringc Engine::EntityComponents::CollisionGroupEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::CollisionGroupEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::CollisionGroupEntityComponent::componentType()
{
	return "CollisionGroupEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::CollisionGroupEntityComponent::familyType()
{
	return "CollisionGroupEntityComponent";
}

void Engine::EntityComponents::CollisionGroupEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

irr::s16 Engine::EntityComponents::CollisionGroupEntityComponent::getGroup() const
{
	return group;
}