#include "CameraTargetEntityComponent.h"

Engine::EntityComponents::CameraTargetEntityComponent::CameraTargetEntityComponent(const irr::core::vector3df& targetPosition /* = irr::core::vector3df()*/)
	: targetPosition(targetPosition)
{
}

const irr::core::stringc Engine::EntityComponents::CameraTargetEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::CameraTargetEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::CameraTargetEntityComponent::componentType()
{
	return "CameraTargetEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::CameraTargetEntityComponent::familyType()
{
	return "CameraTargetEntityComponent";
}

void Engine::EntityComponents::CameraTargetEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

void Engine::EntityComponents::CameraTargetEntityComponent::setTargetPosition( const irr::core::vector3df& position )
{
	this->targetPosition = position;
}

const irr::core::vector3df& Engine::EntityComponents::CameraTargetEntityComponent::getTargetPosition() const
{
	return targetPosition;
}