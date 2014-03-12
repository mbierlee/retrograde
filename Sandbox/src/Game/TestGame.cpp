#include "TestGame.h"

#include "Game/GameEventDefinitions.h"
#include "Game/GameEntityDefinitions.h"

#include <Engine/Entity.h>
#include <Engine/DefaultEntityDefinitions.h>
#include <Engine/PhysicsService.h>
#include <Engine/EntityFactories/DefaultEntityFactory.h>
#include <Engine/EntityFactories/DebugEntityFactory.h>
#include <Engine/KeyboardInputBinding.h>

#include <ICameraSceneNode.h>

Game::TestGame::TestGame(std::shared_ptr<irr::IrrlichtDevice> device
						 , std::shared_ptr<Engine::Framework::IPhysicsService> physicsService
						 , std::shared_ptr<Engine::Framework::IEntityService> entityService
						 , std::shared_ptr<Engine::Framework::IEventService> eventService
						 , std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService
						 , std::shared_ptr<Engine::Framework::IInputService> inputService)
						 : Engine::Base::BaseGame(device, entityService, eventService, entityFactoryService, inputService)
						 , physicsService(physicsService)
{
}

Game::TestGame::~TestGame(void)
{
}

void Game::TestGame::initialize()
{
	BaseGame::initialize();

	eventService->registerObserver(shared_from_this());
	device->setEventReceiver(dynamic_cast<irr::IEventReceiver*>(inputService.get()));

	inputService->setMouseCentering(true);
	std::shared_ptr<Engine::KeyboardInputBinding> keyboardInputBinding = std::make_shared<Engine::KeyboardInputBinding>();
	keyboardInputBinding->bind(irr::KEY_ESCAPE, EV_QUIT);
	keyboardInputBinding->bind(irr::KEY_KEY_W, EV_MOVE_FORWARD);
	keyboardInputBinding->bind(irr::KEY_KEY_S, EV_MOVE_BACKWARD);
	keyboardInputBinding->bind(irr::KEY_KEY_A, EV_MOVE_LEFT);
	keyboardInputBinding->bind(irr::KEY_KEY_D, EV_MOVE_RIGHT);
	keyboardInputBinding->bind(irr::KEY_LEFT, EV_TURN_LEFT);
	keyboardInputBinding->bind(irr::KEY_RIGHT, EV_TURN_RIGHT);
	inputService->setKeyboardBinding(keyboardInputBinding);

	physicsService->initialize();
	physicsService->setDebugDrawing(true);

	entityService->addEntity(entityFactoryService->createEntity(ENTITY_PLAYER));
	entityService->addEntity(entityFactoryService->createEntity(ENTITY_DEBUG_PHYS_FLOOR));
	entityService->addEntity(entityFactoryService->createEntity(ENTITY_DEBUG_PHYS_CUBE));
	//entityService->addEntity(entityFactoryService->createEntity(ENTITY_DEBUG_FLY_CAMERA));

	sceneManager->loadScene("data/TestMap.irr");
}

void Game::TestGame::update(){
	Engine::Base::BaseGame::update();
	physicsService->update((irr::f32)deltaTime);
}

void Game::TestGame::draw()
{
	driver->beginScene();
	physicsService->drawDebugData();
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
