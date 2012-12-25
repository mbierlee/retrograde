#pragma once

#include "Engine/Framework/IEntityFactory.h"

#include <IrrlichtDevice.h>

namespace Engine { namespace EntityFactories {

	class DebugEntityFactory 
		: public Engine::Framework::IEntityFactory
	{
	private:
		std::shared_ptr<irr::IrrlichtDevice> device;

		std::shared_ptr<Engine::Framework::IEntity> makeDebugFlyCameraEntity();
		std::shared_ptr<Engine::Framework::IEntity> makeDebugPhysCube();

	public:
		DebugEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device);

		virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType);
		virtual void clearPool();
	};

}}