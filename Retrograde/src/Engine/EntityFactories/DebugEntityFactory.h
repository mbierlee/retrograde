#pragma once

#include "Engine/Framework/IEntityFactory.h"
#include "Engine/Framework/IPhysicsService.h"

#include <IrrlichtDevice.h>

#include <Hypodermic/AutowiredConstructor.h>

namespace Engine { namespace EntityFactories {
	class DebugEntityFactory
		: public Engine::Framework::IEntityFactory
	{
	private:
		std::shared_ptr<irr::IrrlichtDevice> device;
		std::shared_ptr<Engine::Framework::IPhysicsService> physicsService;

		std::shared_ptr<Engine::Framework::IEntity> makeDebugFlyCameraEntity();
		std::shared_ptr<Engine::Framework::IEntity> makeDebugPhysCube();
		std::shared_ptr<Engine::Framework::IEntity> makeDebugPhysFloor();

	public:
		typedef Hypodermic::AutowiredConstructor<DebugEntityFactory(irr::IrrlichtDevice*, Engine::Framework::IPhysicsService*)> AutowiredSignature;

		DebugEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsService> physicsService);

		virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType);
		virtual void clearPool();
	};
}}
