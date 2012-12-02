#include "FactoryManager.h"

void Engine::FactoryManager::registerFactory( std::shared_ptr<Engine::Framework::IEntityFactory> factory )
{
	factoryRegistry.push_back(factory);
}

void Engine::FactoryManager::clearRegistry()
{
	factoryRegistry.clear();
}

std::shared_ptr<Engine::Framework::IEntity> Engine::FactoryManager::create(irr::core::stringc entityType)
{
	for (auto factory : factoryRegistry) {
		std::shared_ptr<Engine::Framework::IEntity> entity = factory->create(entityType);
		if (entity) {
			return entity;
		}
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}
