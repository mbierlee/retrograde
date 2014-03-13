#pragma once

#include <Engine/Base/BaseGame.h>
#include <Engine/Framework/IEntity.h>
#include <Engine/Framework/IPhysicsService.h>
#include <Engine/Framework/IEventObserver.h>
#include <Engine/Framework/IInputService.h>

#include <irrlicht.h>

#include <Hypodermic/AutowiredConstructor.h>

namespace Breakout {

class BreakoutGame: public Engine::Base::BaseGame {
public:
	typedef Hypodermic::AutowiredConstructor<
			BreakoutGame(irr::IrrlichtDevice*, Engine::Framework::IPhysicsService*, Engine::Framework::IEntityService*,
					Engine::Framework::IEventService*, Engine::Framework::IEntityFactoryService*, Engine::Framework::IInputService*)> AutowiredSignature;

	BreakoutGame(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsService> physicsService,
			std::shared_ptr<Engine::Framework::IEntityService> entityService, std::shared_ptr<Engine::Framework::IEventService> eventService,
			std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService,
			std::shared_ptr<Engine::Framework::IInputService> inputService);

	virtual ~BreakoutGame() {
	}

};

}
