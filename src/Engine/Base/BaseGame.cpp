#include "BaseGame.h"

Engine::Base::BaseGame::BaseGame(std::shared_ptr<irr::IrrlichtDevice> device
								 , std::shared_ptr<Engine::Framework::IEntityManager> entityManager
								 , std::shared_ptr<Engine::Framework::IEventManager> eventManager)
	: device(device)
	, entityManager(entityManager)
	, eventManager(eventManager)
	, isExitRequested(false)
	, lastFrameTime(0)
{
	if (device) {
		sceneManager = device->getSceneManager();
		driver = device->getVideoDriver();
		lastFrameTime = device->getTimer()->getTime();
	}
}

Engine::Base::BaseGame::~BaseGame() {
}

bool Engine::Base::BaseGame::exitRequested()
{
	return isExitRequested;
}

void Engine::Base::BaseGame::requestExit()
{
	isExitRequested = true;
}

void Engine::Base::BaseGame::update()
{
	irr::u32 frameTime = device ? device->getTimer()->getTime() : 0;

	if (entityManager) {
		entityManager->updateEntities(frameTime, lastFrameTime);
	}

	lastFrameTime = frameTime;
}
