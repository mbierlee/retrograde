#include "CollisionMaskEntityComponent.h"

Engine::EntityComponents::CollisionMaskEntityComponent::CollisionMaskEntityComponent( irr::s16 mask )
	: mask(mask)
{
}

const irr::core::stringc Engine::EntityComponents::CollisionMaskEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::CollisionMaskEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::CollisionMaskEntityComponent::componentType()
{
	return "CollisionMaskEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::CollisionMaskEntityComponent::familyType()
{
	return "CollisionMaskEntityComponent";
}

void Engine::EntityComponents::CollisionMaskEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

irr::s16 Engine::EntityComponents::CollisionMaskEntityComponent::getMask() const
{
	return mask;
}
