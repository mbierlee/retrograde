#include "CameraEntityComponent.h"

#include "Engine/EntityComponents/SceneNodeEntityComponent.h"
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
	irr::scene::ISceneManager* sceneManager = device->getSceneManager();
	auto sceneNodeComponent = COMPONENT(SceneNodeEntityComponent);
	if (sceneManager && sceneNodeComponent) {
		cameraSceneNode = sceneManager->addCameraSceneNode(sceneNodeComponent.get());
	}
}