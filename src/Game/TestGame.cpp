#include "TestGame.h"

#include "Engine/Entity.h"
#include "Engine/DefaultEntityDefinitions.h"

#include "Game/IrrEventReceiver.h"
#include "Game/Event/Events.h"

#include "ICameraSceneNode.h"

Game::TestGame::TestGame(std::shared_ptr<irr::IrrlichtDevice> device
						 , std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager
						 , std::shared_ptr<Engine::Framework::IEntityManager> entityManager
						 , std::shared_ptr<Engine::Framework::IEventManager> eventManager
						 , std::shared_ptr<Engine::Framework::IEntityFactory> entityFactory)
	: Engine::Base::BaseGame(device, entityManager, eventManager)
	, physicsManager(physicsManager)
	, entityFactory(entityFactory)
{
}


Game::TestGame::~TestGame(void)
{
}

void Game::TestGame::initialize()
{
	eventManager->registerObserver(shared_from_this());
	device->setEventReceiver(new Game::IrrEventReceiver(eventManager.get()));

	physicsManager->initialize();
		
	entityManager->addEntity(entityFactory->create(ENTITY_FLYCAMERA));
	
	sceneManager->loadScene("data/TestMap.irr");
}

void Game::TestGame::update()
{
	Engine::Base::BaseGame::update();
}

void Game::TestGame::draw()
{
	driver->beginScene();
	sceneManager->drawAll();
	driver->endScene();
}

void Game::TestGame::handleEvent( Engine::Framework::IEvent& event, void* source )
{
	switch (event.getType())
	{
	case Game::Event::Events::QUIT_GAME_EVENT:
		requestExit();
		break;
	}
}
