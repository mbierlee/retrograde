#include "MassEntityComponent.h"

Engine::EntityComponents::MassEntityComponent::MassEntityComponent(irr::f32 mass /* = 0.*/)
	: mass(mass)
{
}

const irr::core::stringc Engine::EntityComponents::MassEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::MassEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::MassEntityComponent::componentType()
{
	return "MassEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::MassEntityComponent::familyType()
{
	return "MassEntityComponent";
}

void Engine::EntityComponents::MassEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

irr::f32 Engine::EntityComponents::MassEntityComponent::getMass() const
{
	return mass;
}

void Engine::EntityComponents::MassEntityComponent::setMass( irr::f32 mass )
{
	this->mass = mass;
}
