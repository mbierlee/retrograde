#include "DebugEntityFactory.h"

#include "Engine/DefaultEntityDefinitions.h"
#include "Engine/Entity.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/CameraEntityComponent.h"
#include "Engine/EntityComponents/CollisionModelEntityComponent.h"
#include "Engine/EntityComponents/CollisionObjectEntityComponent.h"
#include "Engine/EntityComponents/MassEntityComponent.h"
#include "Engine/EntityComponents/InertiaEntityComponent.h"
#include "Engine/EntityComponents/FreeflightCameraEntityComponent.h"

#include <btBulletDynamicsCommon.h>

#include <memory>

Engine::EntityFactories::DebugEntityFactory::DebugEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device)
	: device(device)
{
}

void Engine::EntityFactories::DebugEntityFactory::clearPool()
{
	// Someone peed in it. Job is already done.
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DebugEntityFactory::create(irr::core::stringc entityType)
{
	if (entityType == ENTITY_DEBUG_FLY_CAMERA) {
		return makeDebugFlyCameraEntity();
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DebugEntityFactory::makeDebugFlyCameraEntity() 
{
	auto entity = std::make_shared<Engine::Entity>(ENTITY_DEBUG_FLY_CAMERA);
	entity->addComponent(std::make_shared<Engine::EntityComponents::PositionEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::RotationEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::FreeflightCameraEntityComponent>(device)); 
	return entity;
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DebugEntityFactory::makeDebugPhysCube()
{
	auto entity = std::make_shared<Engine::Entity>(ENTITY_DEBUG_PHYS_CUBE);
	std::shared_ptr<btCollisionShape> shape = std::make_shared<btBoxShape>(btVector3(btScalar(10.),btScalar(1.),btScalar(10.)));

	entity->addComponent(std::make_shared<Engine::EntityComponents::PositionEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::RotationEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::MassEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::InertiaEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::CollisionModelEntityComponent>(shape));
	entity->addComponent(std::make_shared<Engine::EntityComponents::CollisionObjectEntityComponent>());
	return entity;
}
