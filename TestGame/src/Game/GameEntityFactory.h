#pragma once

#include <Engine/Framework/IEntityFactory.h>
#include <Engine/Framework/IPhysicsService.h>
#include <Engine/Framework/IEventService.h>

#include <IrrlichtDevice.h>

namespace Game {
	class GameEntityFactory
		: public Engine::Framework::IEntityFactory
	{
	private:
		virtual std::shared_ptr<Engine::Framework::IEntity> makePlayer();
		std::shared_ptr<irr::IrrlichtDevice> device;
		std::shared_ptr<Engine::Framework::IPhysicsService> physicsService;
		std::shared_ptr<Engine::Framework::IEventService> eventService;

	public:
		GameEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsService> physicsService, std::shared_ptr<Engine::Framework::IEventService> eventService);

		virtual std::shared_ptr<Engine::Framework::IEntity> create( irr::core::stringc entityType );
		virtual void clearPool();
	};
}