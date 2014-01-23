#pragma once

#include "Engine/Framework/IEntityFactory.h"

#include <IrrlichtDevice.h>

namespace Engine { namespace EntityFactories {
	class DefaultEntityFactory
		: public Engine::Framework::IEntityFactory
	{
	private:
		std::shared_ptr<irr::IrrlichtDevice> device;

	public:
		DefaultEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device);
		virtual ~DefaultEntityFactory();

		virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType);
		virtual void clearPool();
	};
}}