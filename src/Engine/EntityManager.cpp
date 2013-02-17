#include "EntityManager.h"

Engine::EntityManager::EntityManager()
	: nextAllocatableId(1)
{
}

void Engine::EntityManager::addEntity( std::shared_ptr<Engine::Framework::IEntity> entity )
{
	if (!entity) {
		//TODO: Log stuff
		return;
	}

	if (entity->getId() == 0) {
		if (!recycledIds.empty()) {
			entity->setId(recycledIds.back());
			recycledIds.pop_back();
		} else {
			entity->setId(nextAllocatableId++);
		}
	}

	entities.push_back(entity);
}

void Engine::EntityManager::removeEntity( std::shared_ptr<Engine::Framework::IEntity> entity )
{	
	if (!entity) {
		//TODO: Log stuff
		return;
	}

	if (entity->getId() != 0) {
		recycledIds.push_back(entity->getId());
	}

	entity->setId(0);
	entities.remove(entity);
}

void Engine::EntityManager::removeEntity( irr::u32 entityId )
{
	if (entityId == 0)
		return;

	std::list<std::shared_ptr<Engine::Framework::IEntity>>::iterator it;
	for (it = entities.begin(); it != entities.end(); it++) {
		std::shared_ptr<Engine::Framework::IEntity> entity = std::static_pointer_cast<Engine::Framework::IEntity>(*it);
		if (entity->getId() == entityId) {
			recycledIds.push_back(entityId);
			entity->setId(0);
			entities.erase(it);
			break;
		}
	}
}

void Engine::EntityManager::clearEntities()
{
	entities.clear();
	recycledIds.clear();
	nextAllocatableId = 1;
}

irr::u32 Engine::EntityManager::entityCount()
{
	return entities.size();
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityManager::getEntity( irr::u32 entityId )
{
	if (entityId == 0)
		return std::shared_ptr<Engine::Framework::IEntity>();

	for (auto& entity : entities) {
		if (entity->getId() == entityId) {
			return entity;
		}
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityManager::getEntity( irr::core::stringc entityType )
{
	for (auto& entity : entities) {
		if (entity->getType() == entityType) {
			return entity;
		}
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}

void Engine::EntityManager::updateEntities( irr::u32 frameTime, irr::u32 lastFrameTime )
{
	for (auto& entity : entities) {
		entity->update(frameTime, lastFrameTime);
	}
}
