#include "FreeflightCameraEntityComponent.h"

#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"

#include "ISceneManager.h"

Engine::EntityComponents::FreeflightCameraEntityComponent::FreeflightCameraEntityComponent( std::shared_ptr<irr::IrrlichtDevice> device )
	: device(device)
{
	cameraSceneNode = device->getSceneManager()->addCameraSceneNodeFPS();
}

const irr::core::stringc Engine::EntityComponents::FreeflightCameraEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::FreeflightCameraEntityComponent::getFamilyType() const
{
	return familyType();
}

void Engine::EntityComponents::FreeflightCameraEntityComponent::update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime)
{	
	if (cameraSceneNode) {
		auto positionComponent = 
			std::static_pointer_cast<Engine::EntityComponents::PositionEntityComponent>(
			entity->getComponent(Engine::EntityComponents::PositionEntityComponent::familyType()));

		if (positionComponent) {
			positionComponent->setPosition(cameraSceneNode->getPosition());
		}
		
		auto rotationComponent = 
			std::static_pointer_cast<Engine::EntityComponents::RotationEntityComponent>(
			entity->getComponent(Engine::EntityComponents::RotationEntityComponent::familyType()));

		if (rotationComponent) {
			rotationComponent->setRotation(cameraSceneNode->getRotation());
		}
	}
}

const irr::core::stringc Engine::EntityComponents::FreeflightCameraEntityComponent::componentType()
{
	return "FreeflightCameraEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::FreeflightCameraEntityComponent::familyType()
{
	return "CameraEntityComponent";
}
