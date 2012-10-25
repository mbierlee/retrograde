#include "Game/PShootGame.h"

#include "Game/Entities/Entities.h"
#include "Game/Event/IrrlichtEventReceiver.h"
#include "Game/SceneNodes/SceneNodeAnimatorCameraPlayer.h"
#include "Core/Mutators/CollisionResponseMutator.h"
#include "Game/Entities/CollectableItemEntity.h"
#include "Game/Network/ServerNetworkManager.h"
#include "Game/Network/ClientNetworkManager.h"

#include <memory>
#include <limits>

//Reserve IDs for player entities, we like to keep these reserved
//because they're the only entities which might rapidly change
#define RESERVED_ENTITY_IDS 32u

Game::PShootGame* Game::PShootGame::_gameInstance = nullptr;

Game::PShootGame::PShootGame()
	: Framework::BaseGame()
	, mouseMoved(false)
	, sceneManager(nullptr)
	, driver(nullptr)
	, device(nullptr)
	, worldTriangleSelector(nullptr)
	, lastUpdateTime(0)
	, entityIdCount(RESERVED_ENTITY_IDS + 1)
	, networkManager(nullptr)
	, localPlayerId(0)
{    
	gameEventManager.attach(this);
}

Game::PShootGame::~PShootGame(void)
{
	if (networkManager) delete networkManager;
	if (worldTriangleSelector) worldTriangleSelector->drop();

	gameEventManager.detach(this);
	setIrrDevice(nullptr);
	removeAllEntities();	
}

void Game::PShootGame::update()
{	
	if (networkManager) networkManager->service();

	irr::u32 updateTime = device->getTimer()->getTime();
	irr::u32 deltaTime = updateTime - lastUpdateTime;
	handleMouseMovement();
	updateAllEntities(deltaTime);
	checkPlayerItemPickups();

	lastUpdateTime = updateTime;

	if (networkManager) networkManager->service();
}

void Game::PShootGame::draw()
{
	driver->beginScene();
	sceneManager->drawAll();
	driver->endScene();
}

void Game::PShootGame::initialize()
{   
	device->getCursorControl()->setVisible(false);

	Game::Event::IrrlichtEventReceiver* irrEventReceiver = new Game::Event::IrrlichtEventReceiver(device, &gameEventManager);
	device->setEventReceiver(irrEventReceiver);
	gameEventManager.attach(irrEventReceiver);

	//TEMP network debugging
#ifdef DEBUG_CLIENT	
	device->setWindowCaption(L"Client");
	Game::Network::ClientNetworkManager* clientNetworkManager = new Game::Network::ClientNetworkManager(&gameEventManager, device->getLogger());
	gameEventManager.attach(clientNetworkManager);
	clientNetworkManager->initialize();
	clientNetworkManager->setupHost();
	networkManager = clientNetworkManager;
	clientNetworkManager->connect();	
#endif
#ifdef DEBUG_HOST
	device->setWindowCaption(L"Host");
	Game::Network::ServerNetworkManager* serverNetworkManager = new Game::Network::ServerNetworkManager(&gameEventManager, device->getLogger());
	gameEventManager.attach(serverNetworkManager);
	serverNetworkManager->initialize();
	serverNetworkManager->setupHost();
	networkManager = serverNetworkManager;
#endif

	device->getLogger()->setLogLevel(irr::ELL_WARNING); // temp: remove clutter from loaders

	//TEMP: load map
	sceneManager->loadScene("data/TestMap.irr");
	  
	//TEMP: set-up collision
	irr::scene::IMeshSceneNode* worldNode = (irr::scene::IMeshSceneNode*)sceneManager->getSceneNodeFromName("WorldMesh");
	if (worldNode) {
		setAntiAliasing(worldNode);				
		worldTriangleSelector = sceneManager->createOctreeTriangleSelector(worldNode->getMesh(), worldNode);
		worldNode->setTriangleSelector(worldTriangleSelector);
	}
		
	//TEMP: add item
	std::shared_ptr<Game::Entities::CollectableItemEntity> itemTest(new Entities::CollectableItemEntity(this, sceneManager->getRootSceneNode(), sceneManager), PShootGame::dropRefCounted);
	addEntity(itemTest);
	itemTest->initalize();

	device->getLogger()->setLogLevel(irr::ELL_INFORMATION); // temp: remove clutter from loaders

	//irr::scene::IMeshSceneNode* node = sceneManager->addMeshSceneNode(sceneManager->getMesh("data/dude.obj"),sceneManager->getRootSceneNode());
	//node->getMaterial(0).Lighting = false;


	/*
	//SUPERTEMP: experimental light
	irr::scene::ILightSceneNode* light = sceneManager->addLightSceneNode(sceneManager->getRootSceneNode(), irr::core::vector3df(0, 10, 0));
	light->setRadius(100.f);
	worldNode->setMaterialFlag(irr::video::EMF_LIGHTING, true);
	*/

#ifdef DEBUG_HOST
	gameEventManager.postEvent(Game::Event::GameEvent(Game::Event::EGET_REGISTER_LOCAL_PLAYER));
#endif // DEBUG_HOST

#if !defined(DEBUG_HOST) && !defined(DEBUG_CLIENT)
	//TEMP, single-play player
	gameEventManager.postEvent(Game::Event::GameEvent(Game::Event::EGET_PLAYER_SET_LOCAL_ID, 1));
	addPlayer(1);
#endif
}

void Game::PShootGame::handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject )
{
	Event::GameEvent& gameEvent = static_cast<Event::GameEvent&>(event);

	switch (gameEvent.type)
	{
	case Event::EGET_QUIT_GAME:
		gameExitRequested = true;
		break;
	case Event::EGET_PLAYER_SET_LOCAL_ID:
		localPlayerId = gameEvent.targetEntityId;
		break;
	case Event::EGET_ADD_PLAYER:
		addPlayer(gameEvent.targetEntityId);
		break;
	case Event::EGET_REMOVE_PLAYER:
		removePlayer(gameEvent.targetEntityId);
		break;
	}
}

void Game::PShootGame::handleMouseMovement()
{
	//return; // TEMP

	if(!windowActive)
		return;

	irr::core::vector2df mouseCenterPos(0.5, 0.5);
	irr::core::vector2df mousePos = device->getCursorControl()->getRelativePosition();

	if (mousePos != mouseCenterPos) {
		gameEventManager.postEvent(Event::GameEvent(Event::EGET_SWITCH_MOUSELOOK, localPlayerId));
		if (mousePos.X < mouseCenterPos.X) {
			//Event::GameEvent turnLeftEvent(Event::EGET_TURN_LEFT, localPlayerId);
			//turnLeftEvent.turnLookEventData.magnitude = mouseCenterPos.X - mousePos.X;
			Event::TurnGameEvent turnLeftEvent(Game::Event::TurnGameEvent::ETGED_LEFT, mouseCenterPos.X - mousePos.X, localPlayerId);
			gameEventManager.postEvent(turnLeftEvent);
			gameEventManager.postEvent(Event::GameEvent(Event::EGET_STOP_TURN_RIGHT, localPlayerId));
		} else if (mousePos.X > mouseCenterPos.X) {
			//Event::GameEvent turnRightEvent(Event::EGET_TURN_RIGHT, localPlayerId);
			//turnRightEvent.turnLookEventData.magnitude =  mousePos.X - mouseCenterPos.X;
			Event::TurnGameEvent turnRightEvent(Event::TurnGameEvent::ETGED_RIGHT, mousePos.X - mouseCenterPos.X, localPlayerId);
			gameEventManager.postEvent(turnRightEvent);
			gameEventManager.postEvent(Event::GameEvent(Event::EGET_STOP_TURN_LEFT, localPlayerId));
		}

		if (mousePos.Y < mouseCenterPos.Y) {
			//Event::GameEvent lookUpEvent(Event::EGET_LOOK_UP, localPlayerId);
			//lookUpEvent.turnLookEventData.magnitude = mouseCenterPos.Y - mousePos.Y;
			Event::LookGameEvent lookUpEvent(Event::LookGameEvent::ELGED_UP, mouseCenterPos.Y - mousePos.Y, localPlayerId);
			gameEventManager.postEvent(lookUpEvent);
			gameEventManager.postEvent(Event::GameEvent(Event::EGET_STOP_LOOK_DOWN, localPlayerId));
		} else if (mousePos.Y > mouseCenterPos.Y) {
			//Event::GameEvent lookDownEvent(Event::EGET_LOOK_DOWN, localPlayerId);
			//lookDownEvent.turnLookEventData.magnitude = mousePos.Y - mouseCenterPos.Y;
			Event::LookGameEvent lookDownEvent(Event::LookGameEvent::ELGED_DOWN, mousePos.Y - mouseCenterPos.Y, localPlayerId);
			gameEventManager.postEvent(lookDownEvent);
			gameEventManager.postEvent(Event::GameEvent(Event::EGET_STOP_LOOK_UP, localPlayerId));
		}   

		mouseMoved = true;
		device->getCursorControl()->setPosition(mouseCenterPos);
	} else if(mouseMoved) {
		gameEventManager.postEvent(Event::GameEvent(Event::EGET_STOP_TURN, localPlayerId));
		gameEventManager.postEvent(Event::GameEvent(Event::EGET_STOP_LOOK, localPlayerId));
		mouseMoved = false;
	}
}

void Game::PShootGame::dropRefCounted( irr::IReferenceCounted* irrManagedPtr )
{
	irrManagedPtr->drop();
}

Game::PShootGame* Game::PShootGame::getGame()
{
	if (!_gameInstance) {
		_gameInstance = new PShootGame();
	}

	return _gameInstance;
}

Core::GameEventManager* Game::PShootGame::getEventManager()
{
	return &gameEventManager;
}

void Game::PShootGame::setIrrDevice( irr::IrrlichtDevice* newDevice )
{
	if (device) {
		sceneManager->clear();
		sceneManager->drop();
		driver->drop();
		device->drop();
	}

	device = newDevice;
	if (newDevice) {
		newDevice->grab();
		sceneManager = newDevice->getSceneManager();
		driver = newDevice->getVideoDriver();
		sceneManager->grab();
		driver->grab();
		lastUpdateTime = device->getTimer()->getTime();
	}
}

irr::scene::ITriangleSelector* Game::PShootGame::getWorldTriangleSelector() const
{
	return worldTriangleSelector;
}

irr::scene::ISceneManager* Game::PShootGame::getSceneManager() const
{
	return sceneManager;
}

void Game::PShootGame::setAntiAliasing( irr::scene::IMeshSceneNode* sceneNode )
{
	for (irr::u32 i = 0; i < sceneNode->getMaterialCount(); i++) {
		sceneNode->getMaterial(i).AntiAliasing = irr::video::EAAM_FULL_BASIC | irr::video::EAAM_ALPHA_TO_COVERAGE;
	}
}

void Game::PShootGame::addEntity( std::shared_ptr<Framework::IEntity> entity )
{
	if (entity->getEntityId() == 0) {
		if (entityIdCount < std::numeric_limits<irr::u32>::max()) {
			entity->setEntityId(entityIdCount++);
		} else {
			device->getLogger()->log("Entity IDs exhausted! Future entities cannot be identified!", irr::ELL_WARNING);
		}
	}

	switch(entity->getEntityType()) {
	case EET_PLAYERENTITY:
		{		
			std::shared_ptr<Game::Entities::PlayerEntity> player = std::static_pointer_cast<Game::Entities::PlayerEntity>(entity);
			players.push_back(player);
			gameEventManager.attach(player.get());
		}
		break;
	case  EET_COLLECTABLEITEMENTITY:
		{
			std::shared_ptr<Game::Entities::CollectableItemEntity> item = std::static_pointer_cast<Game::Entities::CollectableItemEntity>(entity);
			collectableItems.push_back(item);
			gameEventManager.attach(item.get());
		}		
		break;
	}

	Framework::BaseGame::addEntity(entity);
}

void Game::PShootGame::removeEntity( std::shared_ptr<Framework::IEntity> entity )
{
	switch(entity->getEntityType()) {
	case EET_PLAYERENTITY:
		removePlayerEntity(entity);
		break;
	case EET_COLLECTABLEITEMENTITY:
		removeCollectableItemEntity(entity);
		break;
	}

	Framework::BaseGame::removeEntity(entity);
}

void Game::PShootGame::removePlayerEntity( std::shared_ptr<Framework::IEntity> playerEntity )
{
	std::shared_ptr<Game::Entities::PlayerEntity> player = std::static_pointer_cast<Game::Entities::PlayerEntity>(playerEntity);
	for (unsigned int i = 0; i < players.size(); i++) {
		if (players[i] == player) {
			players.erase(players.begin() + i);
			break;
		}
	}
}

void Game::PShootGame::removeAllEntities()
{
	players.clear();
	collectableItems.clear();
	Framework::BaseGame::removeAllEntities();
}

void Game::PShootGame::removeCollectableItemEntity( std::shared_ptr<Framework::IEntity> itemEntity )
{
	std::shared_ptr<Game::Entities::CollectableItemEntity> item = std::static_pointer_cast<Game::Entities::CollectableItemEntity>(itemEntity);
	for (unsigned int i = 0; i < players.size(); i++) {
		if (collectableItems[i] == item) {
			collectableItems.erase(collectableItems.begin() + i);
			break;
		}
	}
}

void Game::PShootGame::checkPlayerItemPickups()
{
	for (unsigned int playerIndex = 0; playerIndex < players.size(); playerIndex++) {
		std::shared_ptr<Game::Entities::PlayerEntity> player = players[playerIndex];
		player->updateAbsolutePosition();
		irr::core::aabbox3df playeraabb = player->getTransformedBoundingBox();

		for (unsigned int itemIndex = 0; itemIndex < collectableItems.size(); itemIndex++) {
			std::shared_ptr<Game::Entities::CollectableItemEntity> item = collectableItems[itemIndex];			
			item->updateAbsolutePosition();
			irr::core::aabbox3df itemaabb = item->getTransformedBoundingBox();		

			if (!item->isCollected() && player->getTransformedBoundingBox().intersectsWithBox(item->getTransformedBoundingBox())) {			
				Game::Event::GameEvent pickupEvent(Game::Event::EGET_ITEM_PICKED_UP);
				pickupEvent.sourceEntityId = player->getEntityId();
				pickupEvent.targetEntityId = item->getEntityId();
				gameEventManager.postEvent(pickupEvent);
			}
		}
	}
}

void Game::PShootGame::dispose()
{
	if (_gameInstance)
		delete _gameInstance;
}

void Game::PShootGame::addPlayer( irr::u32 playerEntityId )
{
	std::shared_ptr<Entities::PlayerEntity> player(new Entities::PlayerEntity(this, sceneManager->getRootSceneNode(), sceneManager, -1, device->getCursorControl()), PShootGame::dropRefCounted);
	player->setPosition(irr::core::vector3df(0, 2, 0)); //TODO: set to spawn points (receive from server)
	player->setEntityId(playerEntityId);
	player->addMutator(std::make_shared<Core::Mutators::CollisionResponseMutator>(worldTriangleSelector, device->getLogger()));

	if (playerEntityId == localPlayerId) {
		irr::scene::ICameraSceneNode* camera = sceneManager->addCameraSceneNode(sceneManager->getRootSceneNode(), player->getPosition() + irr::core::vector3df(0, player->getHeight() - 1.f, 0));
		Game::SceneNode::SceneNodeAnimatorCameraPlayer* camAnimator = new Game::SceneNode::SceneNodeAnimatorCameraPlayer(sceneManager, player);
		camera->addAnimator(camAnimator);
		camAnimator->drop();
	} else {
		//TEMP
		irr::scene::IMeshSceneNode* dude = sceneManager->addMeshSceneNode(sceneManager->getMesh("data/dude.obj"), player.get());
		dude->getMaterial(0).Lighting = false;
	}

	addEntity(player);
}

void Game::PShootGame::removePlayer( irr::u32 playerEntityId )
{
	for (unsigned int i = 0; i < players.size(); i++) {
		if (players[i]->getEntityId() == playerEntityId) {
			players[i]->removeAll();
			removeEntity(players[i]);
		}
	}
}
