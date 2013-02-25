#include "RotationEntityComponent.h"

#include <irrMath.h>

Engine::EntityComponents::RotationEntityComponent::RotationEntityComponent( irr::core::vector3df& rotation /*= irr::core::vector3df(0)*/ )
{
	setEulerRotation(rotation);
}

Engine::EntityComponents::RotationEntityComponent::RotationEntityComponent( irr::core::quaternion& rotation /*= irr::core::quaternion()*/ )
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

const irr::core::vector3df Engine::EntityComponents::RotationEntityComponent::getEulerRotation() const
{
	irr::core::vector3df eulerRotation;
	rotation.toEuler(eulerRotation);
	return eulerRotation;
}

void Engine::EntityComponents::RotationEntityComponent::setEulerRotation( const irr::core::vector3df& rotation )
{
	setRotation(irr::core::quaternion(rotation));
}

const irr::core::quaternion& Engine::EntityComponents::RotationEntityComponent::getRotation() const
{
	return rotation;
}

void Engine::EntityComponents::RotationEntityComponent::setRotation( const irr::core::quaternion& rotation )
{
	this->rotation = rotation;
	notifyAll();
}
