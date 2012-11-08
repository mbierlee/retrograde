#include "DefaultEntityFactory.h"

#include "Engine/Entity.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/CameraEntityComponent.h"
#include "Engine/DefaultEntityDefinitions.h"

void Engine::DefaultEntityFactory::clearPool()
{
	//There is no pool.
}

std::shared_ptr<Engine::Framework::IEntity> Engine::DefaultEntityFactory::makeFlyCameraEntity() 
{
	std::shared_ptr<Engine::Framework::IEntity> entity = std::make_shared<Engine::Entity>("flyCamera");
	entity->addComponent(std::make_shared<Engine::EntityComponents::PositionEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::RotationEntityComponent>());
	//TODO: Refactor camera to create its own with the irrlicht device.
	//entity->addComponent(std::make_shared<Engine::EntityComponents::CameraEntityComponent>(camera)); 
	return entity;
}

std::shared_ptr<Engine::Framework::IEntity> Engine::DefaultEntityFactory::create(irr::core::stringc entityType)
{
	if (entityType == ENTITY_FLYCAMERA) {
		return makeFlyCameraEntity();
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}

Engine::DefaultEntityFactory::~DefaultEntityFactory()
{
}

Engine::DefaultEntityFactory::DefaultEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device)
	: device(device)
{
}
