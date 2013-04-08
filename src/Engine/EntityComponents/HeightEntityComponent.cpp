#include "HeightEntityComponent.h"

Engine::EntityComponents::HeightEntityComponent::HeightEntityComponent( irr::f32 height /*= 0*/ )
	: height(height)
{
}

const irr::core::stringc Engine::EntityComponents::HeightEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::HeightEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::HeightEntityComponent::componentType()
{
	return "HeightEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::HeightEntityComponent::familyType()
{
	return "HeightEntityComponent";
}

void Engine::EntityComponents::HeightEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

irr::f32 Engine::EntityComponents::HeightEntityComponent::getHeight() const
{
	return height;
}

void Engine::EntityComponents::HeightEntityComponent::setHeight( irr::f32 height )
{
	this->height = height;
}