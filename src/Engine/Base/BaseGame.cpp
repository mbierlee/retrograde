#include "BaseGame.h"

#include "Engine/EntityManager.h"
#include "Engine/EventManager.h"

Engine::Base::BaseGame::BaseGame( irr::IrrlichtDevice* device )
	: isExitRequested(false)
	, device(device)
	, lastFrameTime(0)
{
	if (device) {
		sceneManager = device->getSceneManager();
		driver = device->getVideoDriver();
		lastFrameTime = device->getTimer()->getTime();
	}

	entityManager = new Engine::EntityManager();
	eventManager = new Engine::EventManager();
}

Engine::Base::BaseGame::~BaseGame() {
	delete entityManager;
	delete eventManager;
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
