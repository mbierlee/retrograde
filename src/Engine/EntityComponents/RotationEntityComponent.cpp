#include "RotationEntityComponent.h"


Engine::EntityComponents::RotationEntityComponent::RotationEntityComponent( irr::core::vector3df& rotation /*= irr::core::vector3df(0)*/ )
	: rotation(rotation)
{
}

const irr::core::stringc Engine::EntityComponents::RotationEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::RotationEntityComponent::getFamilyType() const
{
	return familyType();
}

void Engine::EntityComponents::RotationEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

const irr::core::stringc Engine::EntityComponents::RotationEntityComponent::componentType()
{
	return "RotationEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::RotationEntityComponent::familyType()
{
	return "RotationEntityComponent";
}

const irr::core::vector3df& Engine::EntityComponents::RotationEntityComponent::getRotation() const
{
	return rotation;
}

void Engine::EntityComponents::RotationEntityComponent::setRotation( const irr::core::vector3df& rotation )
{
	this->rotation = rotation;
}
