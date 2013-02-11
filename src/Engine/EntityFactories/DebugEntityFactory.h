#pragma once

#include "Engine/Framework/IEntityFactory.h"
#include "Engine/Framework/IPhysicsManager.h"

#include <IrrlichtDevice.h>

namespace Engine { namespace EntityFactories {

	class DebugEntityFactory 
		: public Engine::Framework::IEntityFactory
	{
	private:
		std::shared_ptr<irr::IrrlichtDevice> device;
		std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager;

		std::shared_ptr<Engine::Framework::IEntity> makeDebugFlyCameraEntity();
		std::shared_ptr<Engine::Framework::IEntity> makeDebugPhysCube();
		std::shared_ptr<Engine::Framework::IEntity> makeDebugPhysFloor();

	public:
		DebugEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager);

		virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType);
		virtual void clearPool();
	};

}}