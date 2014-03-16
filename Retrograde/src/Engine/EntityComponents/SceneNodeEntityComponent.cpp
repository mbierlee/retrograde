#include "SceneNodeEntityComponent.h"

#include "Engine/UnitTransformationUtil.h"

#include <ISceneManager.h>

Engine::EntityComponents::SceneNodeEntityComponent::SceneNodeEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device,
		irr::scene::ISceneNode* parent /*= nullptr*/) :
		irr::scene::ISceneNode(parent, device->getSceneManager()), registeredWithRotation(false), registeredWithPosition(false), aabbox(
				irr::core::aabbox3df(irr::core::vector3df(0))) {
}

const irr::core::stringc Engine::EntityComponents::SceneNodeEntityComponent::getComponentType() const {
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::SceneNodeEntityComponent::getFamilyType() const {
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::SceneNodeEntityComponent::componentType() {
	return "SceneNodeEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::SceneNodeEntityComponent::familyType() {
	return "SceneNodeEntityComponent";
}

void Engine::EntityComponents::SceneNodeEntityComponent::update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) {
	if (!registeredWithPosition) {
		auto positionComponent = COMPONENT(PositionEntityComponent);
		if (positionComponent) {
			setPositionFromComponent(positionComponent);
			positionComponent->subscribeNotifications(shared_from_this());
			registeredWithPosition = true;
		}
	}

	if (!registeredWithRotation) {
		auto rotationComponent = COMPONENT(RotationEntityComponent);
		if (rotationComponent) {
			setRotationFromComponent(rotationComponent);
			rotationComponent->subscribeNotifications(shared_from_this());
			registeredWithRotation = true;
		}
	}
}

void Engine::EntityComponents::SceneNodeEntityComponent::handleNotification(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent) {
	if (entityComponent->getComponentType() == PositionEntityComponent::componentType()) {
		auto positionComponent = std::static_pointer_cast<Engine::EntityComponents::PositionEntityComponent>(entityComponent);
		setPositionFromComponent(positionComponent);
	}

	if (entityComponent->getComponentType() == RotationEntityComponent::componentType()) {
		auto rotationComponent = std::static_pointer_cast<Engine::EntityComponents::RotationEntityComponent>(entityComponent);
		setRotationFromComponent(rotationComponent);
	}
}

void Engine::EntityComponents::SceneNodeEntityComponent::render() {
}

const irr::core::aabbox3d<irr::f32>& Engine::EntityComponents::SceneNodeEntityComponent::getBoundingBox() const {
	return aabbox;
}

void Engine::EntityComponents::SceneNodeEntityComponent::OnRegisterSceneNode() {
	if (IsVisible) {
		SceneManager->registerNodeForRendering(this);
	}

	irr::scene::ISceneNode::OnRegisterSceneNode();
}

void Engine::EntityComponents::SceneNodeEntityComponent::setPositionFromComponent(
		std::shared_ptr<Engine::EntityComponents::PositionEntityComponent> component) {
	setPosition(component->getPosition() * Engine::visualWorldSize);
}

void Engine::EntityComponents::SceneNodeEntityComponent::setRotationFromComponent(
		std::shared_ptr<Engine::EntityComponents::RotationEntityComponent> component) {
	setRotation(vecRadToDeg(component->getEulerRotation()));
}
