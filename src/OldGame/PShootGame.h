#pragma once

#include "Framework/BaseGame.h"
#include "Framework/IGameEventObserver.h"
#include "Framework/IGameEvent.h"
#include "Game/Entities/PlayerEntity.h"
#include "Game/Entities/CollectableItemEntity.h"
#include "Core/GameEventManager.h"
#include "Core/Network/BaseNetworkManager.h"

#include "IReferenceCounted.h"
#include "ITriangleSelector.h"
#include "irrlicht.h"

#include <memory>

namespace Framework {
	class IGameEventManager;
}

namespace Game {

class PShootGame :
	public Framework::BaseGame,
	public Framework::IGameEventObserver
{
private:
	irr::IrrlichtDevice* device;
	irr::scene::ISceneManager* sceneManager;
	irr::video::IVideoDriver* driver;

	irr::scene::ITriangleSelector* worldTriangleSelector;
	
	Core::GameEventManager gameEventManager;
	Framework::INetworkManager* networkManager;

	bool mouseMoved;
	irr::u32 entityIdCount; //TODO: proper pooling
	irr::u32 localPlayerId;
	
	static PShootGame* _gameInstance;

	irr::u32 lastUpdateTime;

	std::vector<std::shared_ptr<Game::Entities::PlayerEntity>> players;
	std::vector<std::shared_ptr<Game::Entities::CollectableItemEntity>> collectableItems;

	void addPlayer( irr::u32 playerEntityId );

protected:
	PShootGame();
	~PShootGame(void);

public:	
	
	void handleMouseMovement();
	Core::GameEventManager* getEventManager();
	void setIrrDevice(irr::IrrlichtDevice* newDevice);

	virtual void update();

	void checkPlayerItemPickups();

	virtual void draw();
	virtual void initialize();

	void setAntiAliasing( irr::scene::IMeshSceneNode* sceneNode );

	virtual void handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject );	

	irr::scene::ITriangleSelector* getWorldTriangleSelector() const;

	static void dropRefCounted(irr::IReferenceCounted* irrManagedPtr);
	static PShootGame* getGame();
	static void dispose();

	irr::scene::ISceneManager* getSceneManager() const;

	virtual void addEntity( std::shared_ptr<Framework::IEntity> entity );
	virtual void removeEntity( std::shared_ptr<Framework::IEntity> entity );
	void removeCollectableItemEntity( std::shared_ptr<Framework::IEntity> itemEntity );
	void removePlayerEntity( std::shared_ptr<Framework::IEntity> playerEntity );
	virtual void removeAllEntities();
	void removePlayer( irr::u32 playerEntityId );

};

}