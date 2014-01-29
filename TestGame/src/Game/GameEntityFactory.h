#pragma once

#include <Engine/Framework/IEntityFactory.h>
#include <Engine/Framework/IPhysicsManager.h>
#include <Engine/Framework/IEventManager.h>

#include <IrrlichtDevice.h>

namespace Game {
	class GameEntityFactory
		: public Engine::Framework::IEntityFactory
	{
	private:
		virtual std::shared_ptr<Engine::Framework::IEntity> makePlayer();
		std::shared_ptr<irr::IrrlichtDevice> device;
		std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager;
		std::shared_ptr<Engine::Framework::IEventManager> eventManager;

	public:
		GameEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager, std::shared_ptr<Engine::Framework::IEventManager> eventManager);

		virtual std::shared_ptr<Engine::Framework::IEntity> create( irr::core::stringc entityType );
		virtual void clearPool();
	};
}