#include "CameraEntityComponent.h"

#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"

#include "ISceneManager.h"

Engine::EntityComponents::CameraEntityComponent::CameraEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device)
	: device(device)
	, cameraSceneNode(nullptr)
{
}

const irr::core::stringc Engine::EntityComponents::CameraEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::CameraEntityComponent::getFamilyType() const
{
	return familyType();
}

void Engine::EntityComponents::CameraEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (device) {
		auto positionComponent = COMPONENT(PositionEntityComponent);
		auto rotationComponent = COMPONENT(RotationEntityComponent);

		if (!cameraSceneNode) {
			irr::scene::ISceneManager* sceneManager = device->getSceneManager();
			cameraSceneNode = sceneManager->addCameraSceneNode(sceneManager->getRootSceneNode()); //TODO: Add to entity scenenode
		}

		if (positionComponent && positionComponent->getPosition() != cameraSceneNode->getPosition()) {
			cameraSceneNode->setPosition(positionComponent->getPosition());
		}

		if (rotationComponent && rotationComponent->getRotation() != cameraSceneNode->getRotation()) {
			cameraSceneNode->setRotation(rotationComponent->getRotation());
		}
	}
}

const irr::core::stringc Engine::EntityComponents::CameraEntityComponent::componentType()
{
	return "CameraEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::CameraEntityComponent::familyType()
{
	return "CameraEntityComponent";
}
