#include "Entity.h"

#include "Engine/Framework/IEntityComponent.h"

Engine::Entity::Entity(const irr::core::stringc typeName) 
	: entityId(0)
	, componentRemovalLocked(false)
	, entityType(typeName)
{
}

irr::u32 Engine::Entity::getId() const {
	return entityId;
}

void Engine::Entity::setId( const int entityId )
{
	this->entityId = entityId;
}

void Engine::Entity::addComponent( std::shared_ptr<Engine::Framework::IEntityComponent> component )
{
	components.insert(std::pair<irr::core::stringc, std::shared_ptr<Engine::Framework::IEntityComponent>>(component->getFamilyType(), component));
}

std::shared_ptr<Engine::Framework::IEntityComponent> Engine::Entity::getComponent( const irr::core::stringc familyType )
{
	std::map<irr::core::stringc, std::shared_ptr<Engine::Framework::IEntityComponent>>::iterator it;
	it = components.find(familyType);
	return it != components.end() ? it->second : std::shared_ptr<Engine::Framework::IEntityComponent>();
}

void Engine::Entity::removeComponent( const irr::core::stringc familyType )
{
	if (!componentRemovalLocked)
		components.erase(familyType);
	else
		componentRemovalSchedule.push_back(familyType);
}

void Engine::Entity::clearComponents()
{
	components.clear();
}

void Engine::Entity::update(irr::u32 frameTime, irr::u32 lastFrameTime)
{
	componentRemovalLocked = true;
	std::map<irr::core::stringc, std::shared_ptr<Engine::Framework::IEntityComponent>>::iterator it;
	for (it = components.begin(); it != components.end(); ++it) {
		it->second->update(this, frameTime, lastFrameTime);
	}
	componentRemovalLocked = false;

	removeScheduledComponents();
}

void Engine::Entity::removeScheduledComponents()
{
	if (!componentRemovalSchedule.empty()) {
		std::list<irr::core::stringc>::iterator it;
		for (it = componentRemovalSchedule.begin(); it != componentRemovalSchedule.end(); ++it) {
			removeComponent(*it);
		}

		componentRemovalSchedule.clear();
	}
}

bool Engine::Entity::hasComponent( const irr::core::stringc familyType )
{
	return components.count(familyType) == 1;
}

const irr::core::stringc Engine::Entity::getType() const
{
	return this->entityType;
}

void Engine::Entity::setType( const irr::core::stringc entityTypeName )
{
	this->entityType = entityTypeName;
}
