#include "EntityFactoryService.h"

void Engine::EntityFactoryService::registerFactory( std::shared_ptr<Engine::Framework::IEntityFactory> factory )
{
	factoryRegistry.push_back(factory);
}

void Engine::EntityFactoryService::clearRegistry()
{
	factoryRegistry.clear();
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactoryService::create(irr::core::stringc entityType)
{
	for (auto factory : factoryRegistry) {
		std::shared_ptr<Engine::Framework::IEntity> entity = factory->create(entityType);
		if (entity) {
			return entity;
		}
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}
