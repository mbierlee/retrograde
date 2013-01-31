#include "VisualModelEntityComponent.h"

#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/PhysicsUtil.h"

#include <ISceneManager.h>
#include <irrTypes.h>

Engine::EntityComponents::VisualModelEntityComponent::VisualModelEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device, irr::scene::IMesh* mesh)
	: mesh(mesh)
	, meshSceneNode(nullptr)
	, device(device)
{
}

const irr::core::stringc Engine::EntityComponents::VisualModelEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::VisualModelEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::VisualModelEntityComponent::componentType()
{
	return "VisualModelEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::VisualModelEntityComponent::familyType()
{
	return "VisualModelEntityComponent";
}

void Engine::EntityComponents::VisualModelEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (device) {
		if (!meshSceneNode) {
			initialize(entity);
		} 

		auto positionComponent = COMPONENT(PositionEntityComponent);
		auto rotationComponent = COMPONENT(RotationEntityComponent);
	}
}

void Engine::EntityComponents::VisualModelEntityComponent::initialize(Engine::Framework::IEntity* entity)
{
	if (!mesh) {
		auto loggerComponent = COMPONENT(IrrlichtLoggerEntityComponent);
		loggerComponent->log("VisualModelEntityComponent: No mesh supplied. Nothing added.", irr::ELL_WARNING);
	}

	auto positionComponent = COMPONENT(PositionEntityComponent);
	auto rotationComponent = COMPONENT(RotationEntityComponent);

	irr::scene::ISceneManager* sceneManager = device->getSceneManager();

	if (sceneManager) {
		irr::core::vector3df position, rotation;
		if (positionComponent) position = positionComponent->getPosition() * 10.;
		if (rotationComponent) rotation = rotationComponent->getEulerRotation();

		meshSceneNode = sceneManager->addMeshSceneNode(mesh, sceneManager->getRootSceneNode(), -1, position, vecRadToDeg(rotation));
		//TODO: Add scenenode entity component so we can use an entity's node as parent.

		positionComponent->subscribeNotifications(shared_from_this());
		rotationComponent->subscribeNotifications(shared_from_this());
	}
}

void Engine::EntityComponents::VisualModelEntityComponent::handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent )
{
	if (!meshSceneNode) {
		return;
	}

	if (entityComponent->getComponentType() == PositionEntityComponent::componentType()) {
		auto positionComponent = std::static_pointer_cast<Engine::EntityComponents::PositionEntityComponent>(entityComponent);
		meshSceneNode->setPosition(positionComponent->getPosition() * 10.);
	}

	if (entityComponent->getComponentType() == RotationEntityComponent::componentType()) {
		auto rotationComponent = std::static_pointer_cast<Engine::EntityComponents::RotationEntityComponent>(entityComponent);
		meshSceneNode->setRotation(vecRadToDeg(rotationComponent->getEulerRotation()));
	}
}
