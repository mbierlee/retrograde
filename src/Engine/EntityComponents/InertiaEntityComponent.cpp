#include "InertiaEntityComponent.h"

Engine::EntityComponents::InertiaEntityComponent::InertiaEntityComponent( irr::core::vector3df inertia /*= irr::core::vector3df(0)*/)
	: inertia(inertia)
{
}

const irr::core::stringc Engine::EntityComponents::InertiaEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::InertiaEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::InertiaEntityComponent::componentType()
{
	return "InertiaEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::InertiaEntityComponent::familyType()
{
	return "InertiaEntityComponent";
}

void Engine::EntityComponents::InertiaEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

irr::core::vector3df Engine::EntityComponents::InertiaEntityComponent::getIntertia() const
{
	return inertia;
}

void Engine::EntityComponents::InertiaEntityComponent::setInertia( irr::core::vector3df inertia )
{
	this->inertia = inertia;
}