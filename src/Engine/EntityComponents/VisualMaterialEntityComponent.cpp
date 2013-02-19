#include "VisualMaterialEntityComponent.h"

#include "Engine/EntityComponents/TextureEntityComponent.h"

Engine::EntityComponents::VisualMaterialEntityComponent::VisualMaterialEntityComponent(irr::video::SMaterial& visualMaterial)
	: visualMaterial(visualMaterial)
	, usingTextureComponent(false)
{
}

const irr::core::stringc Engine::EntityComponents::VisualMaterialEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::VisualMaterialEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::VisualMaterialEntityComponent::componentType()
{
	return "VisualMaterialEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::VisualMaterialEntityComponent::familyType()
{
	return "VisualMaterialEntityComponent";
}

void Engine::EntityComponents::VisualMaterialEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (!usingTextureComponent) {
		auto textureComponent = COMPONENT(TextureEntityComponent);
		if (textureComponent) {
			visualMaterial.setTexture(0, textureComponent->getTexture());
			usingTextureComponent = true;
		}
	}
}

const irr::video::SMaterial& Engine::EntityComponents::VisualMaterialEntityComponent::getVisualMaterial() const
{
	return visualMaterial;
}

void Engine::EntityComponents::VisualMaterialEntityComponent::setVisualMaterial(const irr::video::SMaterial& material)
{
	this->visualMaterial = material;
	notifyAll();
}
