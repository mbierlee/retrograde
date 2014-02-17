#include "FirstPersonCameraEntityComponent.h"

#include "Engine/EntityComponents/SceneNodeEntityComponent.h"
#include "Engine/EntityComponents/HeightEntityComponent.h"
#include "Engine/EntityComponents/HeadRotationEntityComponent.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"

#include "Engine/UnitTransformationUtil.h"

#include <ISceneManager.h>

Engine::EntityComponents::FirstPersonCameraEntityComponent::FirstPersonCameraEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device, irr::f32 eyeHeightOffset)
	: device(device)
	, cameraSceneNode(nullptr)
	, targetSceneNode(nullptr)
	, eyeHeightOffset(eyeHeightOffset)
	, syncedWithHeight(false)
	, syncedWithHeadRotation(false)
{
}

const irr::core::stringc Engine::EntityComponents::FirstPersonCameraEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::FirstPersonCameraEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::FirstPersonCameraEntityComponent::componentType()
{
	return "FirstPersonCameraEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::FirstPersonCameraEntityComponent::familyType()
{
	return "CameraEntityComponent";
}

void Engine::EntityComponents::FirstPersonCameraEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (device) {
		if (!cameraSceneNode) {
			initialize(entity);
		}

		if (cameraSceneNode && targetSceneNode) {
			if (!syncedWithHeight) {
				auto heightComponent = COMPONENT(HeightEntityComponent);
				if (heightComponent) {
					heightComponent->subscribeNotifications(shared_from_this());
					setEyeHeight(heightComponent->getHeight());
					syncedWithHeight = true;
				}
			}

			if (!syncedWithHeadRotation) {
				auto headRotationComponent = COMPONENT(HeadRotationEntityComponent);
				if (headRotationComponent) {
					headRotationComponent->subscribeNotifications(shared_from_this());
					setCameraRotation(headRotationComponent->getRotation());
					syncedWithHeadRotation = true;
				}
			}

			cameraSceneNode->setTarget(targetSceneNode->getAbsolutePosition());
		}
	}
}

void Engine::EntityComponents::FirstPersonCameraEntityComponent::initialize(Engine::Framework::IEntity* entity)
{
	irr::scene::ISceneManager* sceneManager = device->getSceneManager();
	auto sceneNodeComponent = COMPONENT(SceneNodeEntityComponent);
	if (sceneManager && sceneNodeComponent) {
		cameraSceneNode = sceneManager->addCameraSceneNode(sceneNodeComponent.get());
		if (cameraSceneNode) {
			targetSceneNode = sceneManager->addEmptySceneNode(cameraSceneNode);
			targetSceneNode->setPosition(irr::core::vector3df(0, 0, 10.f));
		}
	}
}

irr::f32 Engine::EntityComponents::FirstPersonCameraEntityComponent::getEyeHeightOffset() const
{
	return eyeHeightOffset;
}

void Engine::EntityComponents::FirstPersonCameraEntityComponent::setEyeHeightOffset( irr::f32 eyeHeightOffset )
{
	this->eyeHeightOffset = eyeHeightOffset;
}

void Engine::EntityComponents::FirstPersonCameraEntityComponent::handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent )
{
	if (entityComponent->getComponentType() == Engine::EntityComponents::HeightEntityComponent::componentType()) {
		auto heightComponent = std::static_pointer_cast<Engine::EntityComponents::HeightEntityComponent>(entityComponent);
		setEyeHeight(heightComponent->getHeight());
	} else if (entityComponent->getComponentType() == Engine::EntityComponents::HeadRotationEntityComponent::componentType()) {
		auto headRotationComponent = std::static_pointer_cast<Engine::EntityComponents::HeadRotationEntityComponent>(entityComponent);
		setCameraRotation(headRotationComponent->getRotation());
	}
}

void Engine::EntityComponents::FirstPersonCameraEntityComponent::setEyeHeight(irr::f32 headHeight)
{
	if (cameraSceneNode) {
		irr::f32 eyeHeight = headHeight - eyeHeightOffset;
		irr::core::vector3df eyePosition = cameraSceneNode->getPosition();
		eyePosition.Y = eyeHeight * 10.f;
		cameraSceneNode->setPosition(eyePosition);
	}
}

void Engine::EntityComponents::FirstPersonCameraEntityComponent::setCameraRotation( const irr::core::quaternion& headRotation )
{
	if (cameraSceneNode) {
		irr::core::vector3df rotation;
		headRotation.toEuler(rotation);
		cameraSceneNode->setRotation(Engine::vecRadToDeg(rotation));
	}
}
