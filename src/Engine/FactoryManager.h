#pragma once

#include "Engine/Framework/IFactoryManager.h"

#include <vector>

namespace Engine {
	class FactoryManager
		: public Engine::Framework::IFactoryManager
	{
	private:
		std::vector<std::shared_ptr<Engine::Framework::IEntityFactory>> factoryRegistry;

	public:
		virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType);
		virtual void registerFactory( std::shared_ptr<Engine::Framework::IEntityFactory> factory );
		virtual void clearRegistry();
	};
}