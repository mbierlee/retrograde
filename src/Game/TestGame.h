#pragma once

#include "Engine/Base/BaseGame.h"

#include "Engine/Framework/IEntity.h"
#include "Engine/Framework/IPhysicsManager.h"
#include "Engine/Framework/IEventObserver.h"

#include "irrlicht.h"

namespace Game {

class TestGame 
	: public Engine::Base::BaseGame
	, public Engine::Framework::IEventObserver
	, public std::enable_shared_from_this<Game::TestGame>
{
private:	
	Engine::Framework::IPhysicsManager* physicsManager;

public:
	TestGame(irr::IrrlichtDevice* device);
	virtual ~TestGame(void);

	virtual void initialize();

	virtual void update();

	virtual void draw();

	virtual void handleEvent( Engine::Framework::IEvent& event, void* source );
};

}