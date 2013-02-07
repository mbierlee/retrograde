#include "CameraEntityComponent.h"

#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/UnitTransformationUtil.h"

#include <ISceneManager.h>

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
		if (!cameraSceneNode) {
			initialize(entity);
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

void Engine::EntityComponents::CameraEntityComponent::initialize(Engine::Framework::IEntity* entity)
{
	auto positionComponent = COMPONENT(PositionEntityComponent);
	auto rotationComponent = COMPONENT(RotationEntityComponent);

	irr::scene::ISceneManager* sceneManager = device->getSceneManager();
	cameraSceneNode = sceneManager->addCameraSceneNode(sceneManager->getRootSceneNode()); //TODO: Add to entity scenenode

	if (positionComponent) {
		cameraSceneNode->setPosition(positionComponent->getPosition());
		positionComponent->subscribeNotifications(shared_from_this());
	}

	if (rotationComponent) {
		cameraSceneNode->setRotation(vecRadToDeg(rotationComponent->getEulerRotation()));
		rotationComponent->subscribeNotifications(shared_from_this());
	}
}

void Engine::EntityComponents::CameraEntityComponent::handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent )
{
	if (entityComponent->getComponentType() == PositionEntityComponent::componentType()) {
		auto positionComponent = std::static_pointer_cast<Engine::EntityComponents::PositionEntityComponent>(entityComponent);
		cameraSceneNode->setPosition(positionComponent->getPosition() * 10.);
	}

	if (entityComponent->getComponentType() == RotationEntityComponent::componentType()) {
		auto rotationComponent = std::static_pointer_cast<Engine::EntityComponents::RotationEntityComponent>(entityComponent);
		cameraSceneNode->setRotation(vecRadToDeg(rotationComponent->getEulerRotation()));
	}
}
