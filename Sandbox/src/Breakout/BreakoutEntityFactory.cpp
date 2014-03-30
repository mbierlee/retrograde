#include "BreakoutEntityFactory.h"

#include "BreakoutEntityDefinitions.h"

#include <Engine/EntityComponents/VisualModelEntityComponent.h>
#include <Engine/Entity.h>

#include <IAnimatedMesh.h>
#include <ISceneManager.h>

Breakout::BreakoutEntityFactory::BreakoutEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device) :
		device(device) {
}

Breakout::BreakoutEntityFactory::~BreakoutEntityFactory() {
}

std::shared_ptr<Engine::Framework::IEntity> Breakout::BreakoutEntityFactory::create(irr::core::stringc entityType) {
	if (entityType == ENTITY_BORDER) {
		return createBorderEntity();
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}

void Breakout::BreakoutEntityFactory::clearPool() {
	// The pool is made out of cheese!
}

std::shared_ptr<Engine::Framework::IEntity> Breakout::BreakoutEntityFactory::createBorderEntity() {
	auto entity = std::make_shared<Engine::Entity>(ENTITY_BORDER);

	irr::scene::ISceneManager* sceneManager = device->getSceneManager();
	irr::scene::IAnimatedMesh* borderMesh = sceneManager->getMesh("data/border.obj");

	ADD_COMPONENT(VisualModelEntityComponent, device, borderMesh);

	return entity;
}
