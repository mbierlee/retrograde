#include "TestGame.h"

#include "Game/GameEventDefinitions.h"
#include "Game/GameEntityDefinitions.h"

#include <Engine/Entity.h>
#include <Engine/DefaultEntityDefinitions.h>
#include <Engine/PhysicsManager.h>
#include <Engine/EntityFactories/DefaultEntityFactory.h>
#include <Engine/EntityFactories/DebugEntityFactory.h>
#include <Engine/KeyboardInputBinding.h>

#include <ICameraSceneNode.h>

Game::TestGame::TestGame(std::shared_ptr<irr::IrrlichtDevice> device
						 , std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager
						 , std::shared_ptr<Engine::Framework::IEntityManager> entityManager
						 , std::shared_ptr<Engine::Framework::IEventManager> eventManager
						 , std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService
						 , std::shared_ptr<Engine::Framework::IInputManager> inputManager)
						 : Engine::Base::BaseGame(device, entityManager, eventManager, entityFactoryService, inputManager)
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
	device->setEventReceiver(dynamic_cast<irr::IEventReceiver*>(inputManager.get()));

	inputManager->setMouseCentering(true);
	std::shared_ptr<Engine::KeyboardInputBinding> keyboardInputBinding = std::make_shared<Engine::KeyboardInputBinding>();
	keyboardInputBinding->bind(irr::KEY_ESCAPE, EV_QUIT);
	keyboardInputBinding->bind(irr::KEY_KEY_W, EV_MOVE_FORWARD);
	keyboardInputBinding->bind(irr::KEY_KEY_S, EV_MOVE_BACKWARD);
	keyboardInputBinding->bind(irr::KEY_KEY_A, EV_MOVE_LEFT);
	keyboardInputBinding->bind(irr::KEY_KEY_D, EV_MOVE_RIGHT);
	keyboardInputBinding->bind(irr::KEY_LEFT, EV_TURN_LEFT);
	keyboardInputBinding->bind(irr::KEY_RIGHT, EV_TURN_RIGHT);
	inputManager->setKeyboardBinding(keyboardInputBinding);

	physicsManager->initialize();
	physicsManager->setDebugDrawing(true);

	entityManager->addEntity(entityFactoryService->createEntity(ENTITY_PLAYER));
	entityManager->addEntity(entityFactoryService->createEntity(ENTITY_DEBUG_PHYS_FLOOR));
	entityManager->addEntity(entityFactoryService->createEntity(ENTITY_DEBUG_PHYS_CUBE));
	//entityManager->addEntity(entityFactoryService->createEntity(ENTITY_DEBUG_FLY_CAMERA));

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
