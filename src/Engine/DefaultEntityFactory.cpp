#include "DefaultEntityFactory.h"

#include "Engine/Entity.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/CameraEntityComponent.h"
#include "Engine/EntityComponents/FreeflightCameraEntityComponent.h"
#include "Engine/DefaultEntityDefinitions.h"

void Engine::DefaultEntityFactory::clearPool()
{
	//There is no pool.
}

std::shared_ptr<Engine::Framework::IEntity> Engine::DefaultEntityFactory::makeDebugFlyCameraEntity() 
{
	std::shared_ptr<Engine::Framework::IEntity> entity = std::make_shared<Engine::Entity>(ENTITY_DEBUG_FLY_CAMERA);
	entity->addComponent(std::make_shared<Engine::EntityComponents::PositionEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::RotationEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::FreeflightCameraEntityComponent>(device)); 
	return entity;
}

std::shared_ptr<Engine::Framework::IEntity> Engine::DefaultEntityFactory::create(irr::core::stringc entityType)
{
	if (entityType == ENTITY_DEBUG_FLY_CAMERA) {
		return makeDebugFlyCameraEntity();
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
