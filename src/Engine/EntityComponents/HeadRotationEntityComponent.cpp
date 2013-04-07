#include "HeadRotationEntityComponent.h"

Engine::EntityComponents::HeadRotationEntityComponent::HeadRotationEntityComponent(const irr::core::quaternion& headRotation)
	: headRotation(headRotation)
{
}

const irr::core::stringc Engine::EntityComponents::HeadRotationEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::HeadRotationEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::HeadRotationEntityComponent::componentType()
{
	return "HeadRotationEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::HeadRotationEntityComponent::familyType()
{
	return "HeadRotationEntityComponent";
}

void Engine::EntityComponents::HeadRotationEntityComponent::setRotation( const irr::core::quaternion& rotation )
{
	headRotation = rotation;
}

const irr::core::quaternion& Engine::EntityComponents::HeadRotationEntityComponent::getRotation() const
{
	return headRotation;
}

void Engine::EntityComponents::HeadRotationEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}