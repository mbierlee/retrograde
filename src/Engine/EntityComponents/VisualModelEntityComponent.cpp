#include "VisualModelEntityComponent.h"

#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"

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
		auto positionComponent = COMPONENT(PositionEntityComponent);
		auto rotationComponent = COMPONENT(RotationEntityComponent);

		if (!meshSceneNode) {
			if (!mesh) {
				auto loggerComponent = COMPONENT(IrrlichtLoggerEntityComponent);
				loggerComponent->log("VisualModelEntityComponent: No mesh supplied. Nothing added.", irr::ELL_WARNING);
			}

			irr::scene::ISceneManager* sceneManager = device->getSceneManager();

			if (sceneManager) {
				irr::core::vector3df position, rotation;
				if (positionComponent) position = positionComponent->getPosition() * 10.;
				if (rotationComponent) rotation = rotationComponent->getRotation();

				meshSceneNode = sceneManager->addMeshSceneNode(mesh, sceneManager->getRootSceneNode(), -1, position, rotation);
				//TODO: Add scenenode entity component so we can use an entity's node as parent.
			}
		} 

		if (positionComponent) meshSceneNode->setPosition(positionComponent->getPosition() * 10.);
		if (rotationComponent) meshSceneNode->setRotation(rotationComponent->getRotation());
	}
}
