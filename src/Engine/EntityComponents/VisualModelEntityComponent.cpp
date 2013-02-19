#include "VisualModelEntityComponent.h"

#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"
#include "Engine/EntityComponents/SceneNodeEntityComponent.h"
#include "Engine/EntityComponents/VisualMaterialEntityComponent.h"
#include "Engine/UnitTransformationUtil.h"

#include <ISceneManager.h>
#include <irrTypes.h>

Engine::EntityComponents::VisualModelEntityComponent::VisualModelEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device, irr::scene::IMesh* mesh)
	: mesh(mesh)
	, meshSceneNode(nullptr)
	, device(device)
	, usingMaterialComponent(false)
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
		} else {
			if (!usingMaterialComponent) {
				auto materialComponent = COMPONENT(VisualMaterialEntityComponent);
				if (materialComponent) {
					meshSceneNode->getMaterial(0) = materialComponent->getVisualMaterial();
					materialComponent->subscribeNotifications(shared_from_this());
					usingMaterialComponent = true;
				}
			}
		}
	}
}

void Engine::EntityComponents::VisualModelEntityComponent::initialize(Engine::Framework::IEntity* entity)
{
	if (!mesh) {
		auto loggerComponent = COMPONENT(IrrlichtLoggerEntityComponent);
		loggerComponent->log("VisualModelEntityComponent: No mesh supplied. Nothing added.", irr::ELL_WARNING);
	}
	
	irr::scene::ISceneManager* sceneManager = device->getSceneManager();
	auto sceneNodeComponent = COMPONENT(SceneNodeEntityComponent);
	if (sceneManager && sceneNodeComponent) {		
		meshSceneNode = sceneManager->addMeshSceneNode(mesh, sceneNodeComponent.get());
	}
}

bool Engine::EntityComponents::VisualModelEntityComponent::isInitialized() const
{
	return meshSceneNode != nullptr;
}

void Engine::EntityComponents::VisualModelEntityComponent::handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent )
{
	if (entityComponent->getFamilyType() == Engine::EntityComponents::VisualMaterialEntityComponent::familyType()) {
		auto materialComponent = std::static_pointer_cast<Engine::EntityComponents::VisualMaterialEntityComponent>(entityComponent);
		meshSceneNode->getMaterial(0) = materialComponent->getVisualMaterial();
	}
}
