#include "DefaultEntityFactory.h"

#include "Engine/Entity.h"

#include "Engine/DefaultEntityDefinitions.h"

void Engine::EntityFactories::DefaultEntityFactory::clearPool()
{
	//There is no pool.
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DefaultEntityFactory::create(irr::core::stringc entityType)
{
	return std::shared_ptr<Engine::Framework::IEntity>();
}

Engine::EntityFactories::DefaultEntityFactory::~DefaultEntityFactory()
{
}

Engine::EntityFactories::DefaultEntityFactory::DefaultEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device)
	: device(device)
{
}