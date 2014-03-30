#include "BreakoutGame.h"

#include "Breakout/BreakoutEntityDefinitions.h"

Breakout::BreakoutGame::BreakoutGame(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsService> physicsService,
		std::shared_ptr<Engine::Framework::IEntityService> entityService, std::shared_ptr<Engine::Framework::IEventService> eventService,
		std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService,
		std::shared_ptr<Engine::Framework::IInputService> inputService) :
		Engine::Base::BaseGame(device, entityService, eventService, entityFactoryService, inputService), physicsService(physicsService) {

}

void Breakout::BreakoutGame::initialize() {
	BaseGame::initialize();

	entityService->addEntity(entityFactoryService->createEntity(ENTITY_BORDER));
}

void Breakout::BreakoutGame::update() {
	Engine::Base::BaseGame::update();
}

void Breakout::BreakoutGame::draw() {
	Engine::Base::BaseGame::draw();
}
