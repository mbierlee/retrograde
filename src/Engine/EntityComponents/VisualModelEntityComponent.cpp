#include "VisualModelEntityComponent.h"

#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"
#include "Engine/EntityComponents/SceneNodeEntityComponent.h"
#include "Engine/UnitTransformationUtil.h"

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