#pragma once

#include "Framework/BaseEntity.h"
#include "Framework/IGameEventObserver.h"
#include "Game/Event/GameEvent.h"
#include "Game/Entities/State/PlayerEntityState.h"

#include "ISceneNode.h"
#include "aabbox3d.h"
#include "ICameraSceneNode.h"
#include "ICursorControl.h"
#include "IMeshSceneNode.h"
#include "ISceneCollisionManager.h"

namespace Framework {
	class IGameEventManager;
}

namespace Game {
	class PShootGame;
}

#include <queue>

namespace Game { namespace Entities {

enum PlayerMoveMode {
	EPMM_WALK,
	EPMM_SWIM, // UNSUPPORTED YET
	EPMM_FLY // UNSUPPORTED YET
};

class PlayerEntity :
	public Framework::BaseEntity,
	public irr::scene::ISceneNode,
	public Framework::IGameEventObserver
{ 
private:
	Game::Entities::State::PlayerEntityState state;

	irr::core::aabbox3df boundingBox;
	irr::gui::ICursorControl* cursor;
	irr::core::vector3df gravity, normalizedGravity;
	Game::PShootGame* game;
	std::vector<std::shared_ptr<Game::Event::GameEvent>> eventBuffer;
	PlayerMoveMode moveMode;
	
	bool collidesWithGround();
	void resetBoundingBox();
	void handleMovementEvents();
	
public:
	PlayerEntity(Game::PShootGame* game, irr::scene::ISceneNode* parent, irr::scene::ISceneManager* sceneManager, irr::s32 id, irr::gui::ICursorControl* cursor);
	~PlayerEntity(void);

	virtual void initalize();
	virtual void update(unsigned int deltaTime);
	
	virtual void render();
	virtual const irr::core::aabbox3d<irr::f32>& getBoundingBox() const;
	virtual void handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject );
	virtual void OnRegisterSceneNode();

	void setModeMode(Entities::PlayerMoveMode moveMode);
	Game::Entities::PlayerMoveMode getMoveMode();
	irr::core::vector3df getHeadRotation();
	irr::f32 getHeight();
	virtual std::wstring getEntityName() const;

	virtual int getEntityType();
	void handleAttributeChangeEvent( Game::Event::ChangeAttributeGameEvent& attributeEvent );
};

}}