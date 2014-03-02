#pragma once

#include "Engine/Framework/IEntityFactoryService.h"

#include <vector>

namespace Engine {
	class EntityFactoryService
		: public Engine::Framework::IEntityFactoryService
	{
	private:
		std::vector<std::shared_ptr<Engine::Framework::IEntityFactory>> factoryRegistry;

	public:
		virtual std::shared_ptr<Engine::Framework::IEntity> createEntity(irr::core::stringc entityType);
		virtual void registerFactory( std::shared_ptr<Engine::Framework::IEntityFactory> factory );
		virtual void clearRegistry();
	};
}
