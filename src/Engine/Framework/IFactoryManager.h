#pragma once

#include "Engine/Framework/IEntity.h"
#include "Engine/Framework/IEntityFactory.h"

#include <irrString.h>
#include <memory>

namespace Engine { namespace Framework {

	class IFactoryManager {
	public:
		virtual ~IFactoryManager() {};

		virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType) =0;
		virtual void registerFactory(std::shared_ptr<Engine::Framework::IEntityFactory> factory) =0;
		virtual void clearRegistry() =0;
	};

}}