#pragma once

#include <Engine/Base/BaseGame.h>
#include <Engine/Framework/IEntity.h>
#include <Engine/Framework/IPhysicsService.h>
#include <Engine/Framework/IEventObserver.h>
#include <Engine/Framework/IInputManager.h>

#include "irrlicht.h"

#include <memory>

namespace Game {
	class TestGame
		: public Engine::Base::BaseGame
		, public Engine::Framework::IEventObserver
		, public std::enable_shared_from_this<Game::TestGame>
	{
	private:
		std::shared_ptr<Engine::Framework::IPhysicsService> physicsService;

	public:
		TestGame(std::shared_ptr<irr::IrrlichtDevice> device
			, std::shared_ptr<Engine::Framework::IPhysicsService> physicsService
			, std::shared_ptr<Engine::Framework::IEntityManager> entityManager
			, std::shared_ptr<Engine::Framework::IEventManager> eventManager
			, std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService
			, std::shared_ptr<Engine::Framework::IInputManager> inputManager);

		virtual ~TestGame(void);

		virtual void initialize();

		virtual void update();

		virtual void draw();

		virtual void handleEvent( const Engine::Framework::IEvent& event, void* source );
	};
}
