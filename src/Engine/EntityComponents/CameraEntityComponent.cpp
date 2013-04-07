#include "CameraEntityComponent.h"

#include "Engine/EntityComponents/SceneNodeEntityComponent.h"
#include "Engine/EntityComponents/CameraTargetEntityComponent.h"
#include "Engine/UnitTransformationUtil.h"

#include <ISceneManager.h>

Engine::EntityComponents::CameraEntityComponent::CameraEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device)
	: device(device)
	, cameraSceneNode(nullptr)
	, registeredWithTargetPosition(false)
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

		if (cameraSceneNode && !registeredWithTargetPosition) {
			auto targetComponent = COMPONENT(CameraTargetEntityComponent);
			if (targetComponent) {
				cameraSceneNode->setTarget(targetComponent->getTargetPosition());
				targetComponent->subscribeNotifications(shared_from_this());
				registeredWithTargetPosition = true;
			}
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

void Engine::EntityComponents::CameraEntityComponent::handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent )
{
	if (cameraSceneNode && entityComponent->getFamilyType() == Engine::EntityComponents::CameraTargetEntityComponent::familyType()) {
		auto targetComponent = std::static_pointer_cast<Engine::EntityComponents::CameraTargetEntityComponent>(entityComponent);
		cameraSceneNode->setTarget(targetComponent->getTargetPosition());
	}
}