#include "TextureEntityComponent.h"

Engine::EntityComponents::TextureEntityComponent::TextureEntityComponent( irr::video::ITexture* texture )
	: texture(texture)
{
}

const irr::core::stringc Engine::EntityComponents::TextureEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::TextureEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::TextureEntityComponent::componentType()
{
	return "TextureEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::TextureEntityComponent::familyType()
{
	return "TextureEntityComponent";
}

void Engine::EntityComponents::TextureEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

irr::video::ITexture* Engine::EntityComponents::TextureEntityComponent::getTexture() const
{
	return texture;
}