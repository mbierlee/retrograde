#pragma once
#include "Framework/BaseEntity.h"
#include "Framework/IGameEventObserver.h"

#include "ISceneManager.h"

namespace Game {
	class PShootGame;	
}

namespace Game { namespace Entities {
	
class CollectableItemEntity :
	public Framework::BaseEntity,
	public irr::scene::ISceneNode,
	public Framework::IGameEventObserver
{
private:
	Game::PShootGame* game;
	irr::scene::ISceneManager* sceneManager;
	irr::scene::IMeshSceneNode* itemMeshNode;
	irr::core::aabbox3df aabb;
	bool collected; //TOSTATE

public:
	CollectableItemEntity(Game::PShootGame* game, irr::scene::ISceneNode* parent, irr::scene::ISceneManager* sceneManager);
	~CollectableItemEntity(void);

	virtual void initalize();
	virtual void update( unsigned int deltaTime );

	virtual std::wstring getEntityName() const;

	virtual void render();

	virtual const irr::core::aabbox3d<irr::f32>& getBoundingBox() const;

	bool isCollected() const;
	void setCollected(bool collected);

	virtual int getEntityType();

	virtual void handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject );
};

}}