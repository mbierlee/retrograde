#include "TestGame.h"

#include "Engine/Entity.h"
#include "Engine/DefaultEntityDefinitions.h"
#include "Engine/PhysicsManager.h"
#include "Engine/EntityFactories/DefaultEntityFactory.h"
#include "Engine/EntityFactories/DebugEntityFactory.h"

#include "Game/IrrEventReceiver.h"
#include "Game/EventConstants.h"

#include <ICameraSceneNode.h>

Game::TestGame::TestGame(std::shared_ptr<irr::IrrlichtDevice> device
						 , std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager
						 , std::shared_ptr<Engine::Framework::IEntityManager> entityManager
						 , std::shared_ptr<Engine::Framework::IEventManager> eventManager
						 , std::shared_ptr<Engine::Framework::IFactoryManager> factoryManager)
						 : Engine::Base::BaseGame(device, entityManager, eventManager, factoryManager)
						 , physicsManager(physicsManager)
{
}

Game::TestGame::~TestGame(void)
{
}

void Game::TestGame::initialize()
{
	BaseGame::initialize();

	eventManager->registerObserver(shared_from_this());
	device->setEventReceiver(new Game::IrrEventReceiver(eventManager.get()));

	physicsManager->initialize();
	physicsManager->setDebugDrawing(true);

	entityManager->addEntity(factoryManager->create(ENTITY_DEBUG_FLY_CAMERA));
	entityManager->addEntity(factoryManager->create(ENTITY_DEBUG_PHYS_FLOOR));
	entityManager->addEntity(factoryManager->create(ENTITY_DEBUG_PHYS_CUBE));

	sceneManager->loadScene("data/TestMap.irr");
}

void Game::TestGame::update(){
	Engine::Base::BaseGame::update();
	physicsManager->update((irr::f32)deltaTime);
}

void Game::TestGame::draw()
{
	driver->beginScene();
	physicsManager->drawDebugData();
	sceneManager->drawAll();
	driver->endScene();
}

void Game::TestGame::handleEvent( const Engine::Framework::IEvent& event, void* source )
{
	irr::core::stringc eventName = event.getName();

	if (eventName == EV_QUIT) {
		requestExit();
	}
}