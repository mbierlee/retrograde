#include "BaseGame.h"

Engine::Base::BaseGame::BaseGame(std::shared_ptr<irr::IrrlichtDevice> device
								 , std::shared_ptr<Engine::Framework::IEntityManager> entityManager
								 , std::shared_ptr<Engine::Framework::IEventManager> eventManager
								 , std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService
								 , std::shared_ptr<Engine::Framework::IInputManager> inputManager)
								 : isExitRequested(false)
								 , device(device)
								 , entityManager(entityManager)
								 , eventManager(eventManager)
								 , entityFactoryService(entityFactoryService)
								 , inputManager(inputManager)
								 , lastFrameTime(0)
								 , frameTime(0)
								 , deltaTime(0)
{
	if (device) {
		sceneManager = device->getSceneManager();
		driver = device->getVideoDriver();
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
	frameTime = device ? device->getTimer()->getTime() : 0;
	deltaTime = frameTime - lastFrameTime;

	if (entityManager) {
		entityManager->updateEntities(frameTime, lastFrameTime);
	}

	lastFrameTime = frameTime;
}

void Engine::Base::BaseGame::initialize()
{
	lastFrameTime = device->getTimer()->getTime();
	frameTime = lastFrameTime;
	deltaTime = 0;
}
