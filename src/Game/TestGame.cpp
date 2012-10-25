#include "TestGame.h"

#include "Engine/Entity.h"
#include "Game/Test/TestComponent.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"
#include "Engine/PhysicsManager.h"
#include "Game/IrrEventReceiver.h"

#include "Game/Entities.h"
#include "Game/Event/Events.h"

#include "ICameraSceneNode.h"

Game::TestGame::TestGame(irr::IrrlichtDevice* device)
	: Engine::Base::BaseGame(device)
{
	physicsManager = new Engine::PhysicsManager();
}


Game::TestGame::~TestGame(void)
{
	delete physicsManager;
}

void Game::TestGame::initialize()
{
	eventManager->registerObserver(shared_from_this());
	device->setEventReceiver(new Game::IrrEventReceiver(eventManager));

	physicsManager->initialize();

	irr::scene::ICameraSceneNode* cameraNode = sceneManager->addCameraSceneNode(sceneManager->getRootSceneNode());
	entityManager->addEntity(Game::createFlyCameraEntity(cameraNode));
	
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
