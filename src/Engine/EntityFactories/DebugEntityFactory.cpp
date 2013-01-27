#include "DebugEntityFactory.h"

#include "Engine/TypeContainerConfig.h"
#include "Engine/DefaultEntityDefinitions.h"
#include "Engine/Framework/IPhysicsManager.h"
#include "Engine/Entity.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/CameraEntityComponent.h"
#include "Engine/EntityComponents/CollisionModelEntityComponent.h"
#include "Engine/EntityComponents/CollisionObjectEntityComponent.h"
#include "Engine/EntityComponents/RigidBodyEntityComponent.h"
#include "Engine/EntityComponents/MassEntityComponent.h"
#include "Engine/EntityComponents/InertiaEntityComponent.h"
#include "Engine/EntityComponents/FreeflightCameraEntityComponent.h"
#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"
#include "Engine/EntityComponents/VisualModelEntityComponent.h"

#include <btBulletDynamicsCommon.h>
#include <IMesh.h>

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
	} else if (entityType == ENTITY_DEBUG_PHYS_FLOOR) {
		return makeDebugPhysFloor();
	} else if (entityType == ENTITY_DEBUG_PHYS_CUBE) {
		return makeDebugPhysCube();
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DebugEntityFactory::makeDebugFlyCameraEntity() 
{
	auto entity = std::make_shared<Engine::Entity>(ENTITY_DEBUG_FLY_CAMERA);
	entity->addComponent(std::make_shared<Engine::EntityComponents::PositionEntityComponent>(irr::core::vector3df(10., 10., 0.)));
	entity->addComponent(std::make_shared<Engine::EntityComponents::RotationEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::FreeflightCameraEntityComponent>(device)); 
	return entity;
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DebugEntityFactory::makeDebugPhysCube()
{
	auto entity = std::make_shared<Engine::Entity>(ENTITY_DEBUG_PHYS_CUBE);
	std::shared_ptr<btCollisionShape> collisionShape = std::make_shared<btBoxShape>(btVector3(0.5,0.5,0.5));
	irr::scene::IMesh* visualMesh = device->getSceneManager()->getGeometryCreator()->createCubeMesh(irr::core::vector3df(10., 10., 10.));
	
	entity->addComponent(std::make_shared<Engine::EntityComponents::VisualModelEntityComponent>(device, visualMesh));
	entity->addComponent(std::make_shared<Engine::EntityComponents::PositionEntityComponent>(irr::core::vector3df(0., 50., 0.)));
	entity->addComponent(std::make_shared<Engine::EntityComponents::RotationEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::MassEntityComponent>(1.f));
	entity->addComponent(std::make_shared<Engine::EntityComponents::InertiaEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::CollisionModelEntityComponent>(collisionShape));
	entity->addComponent(std::make_shared<Engine::EntityComponents::RigidBodyEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::IrrlichtLoggerEntityComponent>(device->getLogger()));
	return entity;
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DebugEntityFactory::makeDebugPhysFloor()
{
	auto entity = std::make_shared<Engine::Entity>(ENTITY_DEBUG_PHYS_FLOOR);
	std::shared_ptr<btCollisionShape> shape = std::make_shared<btBoxShape>(btVector3(100.,1.,100.));

	entity->addComponent(std::make_shared<Engine::EntityComponents::PositionEntityComponent>(irr::core::vector3df(0., -1., 0.)));
	entity->addComponent(std::make_shared<Engine::EntityComponents::CollisionModelEntityComponent>(shape));
	entity->addComponent(std::make_shared<Engine::EntityComponents::CollisionObjectEntityComponent>());
	return entity;
}
