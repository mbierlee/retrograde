#include "FreeflightCameraEntityComponent.h"

#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"

#include <ISceneManager.h>

Engine::EntityComponents::FreeflightCameraEntityComponent::FreeflightCameraEntityComponent( std::shared_ptr<irr::IrrlichtDevice> device )
	: device(device)
	, cameraSceneNode(nullptr)
{
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
	if (device) {
		if (!cameraSceneNode) {
			initialize(entity);
		} else {
			auto positionComponent = COMPONENT(PositionEntityComponent);
			auto rotationComponent = COMPONENT(RotationEntityComponent);

			if (positionComponent) positionComponent->setPosition(cameraSceneNode->getPosition() / 10.);
			if (rotationComponent) rotationComponent->setEulerRotation(cameraSceneNode->getRotation());
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

void Engine::EntityComponents::FreeflightCameraEntityComponent::initialize( Engine::Framework::IEntity* entity )
{
	auto positionComponent = COMPONENT(PositionEntityComponent);
	auto rotationComponent = COMPONENT(RotationEntityComponent);

	cameraSceneNode = device->getSceneManager()->addCameraSceneNodeFPS(); // TODO Add to entity scenenode
	if (positionComponent) cameraSceneNode->setPosition(positionComponent->getPosition() * 10.);
	if (rotationComponent) cameraSceneNode->setRotation(rotationComponent->getEulerRotation());
}
