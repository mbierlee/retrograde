#pragma once

#include <Engine/Base/BaseGame.h>
#include <Engine/Framework/IEntity.h>
#include <Engine/Framework/IPhysicsService.h>
#include <Engine/Framework/IEventObserver.h>
#include <Engine/Framework/IInputService.h>

#include <irrlicht.h>

#include <memory>

#include <Hypodermic/AutowiredConstructor.h>

namespace Game {

class SandboxGame: public Engine::Base::BaseGame, public Engine::Framework::IEventObserver, public std::enable_shared_from_this<Game::SandboxGame> {
private:
	std::shared_ptr<Engine::Framework::IPhysicsService> physicsService;

public:
	typedef Hypodermic::AutowiredConstructor<
			SandboxGame(irr::IrrlichtDevice*, Engine::Framework::IPhysicsService*, Engine::Framework::IEntityService*, Engine::Framework::IEventService*,
					Engine::Framework::IEntityFactoryService*, Engine::Framework::IInputService*)> AutowiredSignature;

	SandboxGame(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsService> physicsService,
			std::shared_ptr<Engine::Framework::IEntityService> entityService, std::shared_ptr<Engine::Framework::IEventService> eventService,
			std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService,
			std::shared_ptr<Engine::Framework::IInputService> inputService);

	virtual ~SandboxGame(void);

	virtual void initialize() override;

	virtual void update() override;

	virtual void draw() override;

	virtual void handleEvent(const Engine::Framework::IEvent& event, void* source) override;
};

}
