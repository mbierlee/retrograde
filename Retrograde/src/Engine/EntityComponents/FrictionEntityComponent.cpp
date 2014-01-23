#include "FrictionEntityComponent.h"

Engine::EntityComponents::FrictionEntityComponent::FrictionEntityComponent( irr::f32 friction /*= 0.f*/ )
	: friction(friction)
{
}

const irr::core::stringc Engine::EntityComponents::FrictionEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::FrictionEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::FrictionEntityComponent::componentType()
{
	return "FrictionEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::FrictionEntityComponent::familyType()
{
	return "FrictionEntityComponent";
}

void Engine::EntityComponents::FrictionEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

void Engine::EntityComponents::FrictionEntityComponent::setFriction( const irr::f32& friction )
{
	this->friction = friction;
}

irr::f32 Engine::EntityComponents::FrictionEntityComponent::getFriction() const
{
	return friction;
}