#include "DebugEntityFactory.h"

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
#include "Engine/EntityComponents/SceneNodeEntityComponent.h"
#include "Engine/EntityComponents/VisualMaterialEntityComponent.h"
#include "Engine/EntityComponents/TextureEntityComponent.h"

#include <btBulletDynamicsCommon.h>
#include <IMesh.h>
#include <ISceneManager.h>
#include <SMaterial.h>
#include <IVideoDriver.h>

#include <memory>

Engine::EntityFactories::DebugEntityFactory::DebugEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager)
	: device(device)
	, physicsManager(physicsManager)
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
	ADD_COMPONENT(PositionEntityComponent, irr::core::vector3df(10., 10., 0.));
	ADD_COMPONENT(RotationEntityComponent);
	ADD_COMPONENT(FreeflightCameraEntityComponent, device);
	return entity;
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DebugEntityFactory::makeDebugPhysCube()
{
	auto entity = std::make_shared<Engine::Entity>(ENTITY_DEBUG_PHYS_CUBE);
	std::shared_ptr<btCollisionShape> collisionShape = std::make_shared<btBoxShape>(btVector3(0.5,0.5,0.5));
	irr::scene::IMesh* visualMesh = device->getSceneManager()->getGeometryCreator()->createCubeMesh(irr::core::vector3df(10., 10., 10.));

	irr::video::IVideoDriver* driver = device->getVideoDriver();
	irr::video::SMaterial material;
	material.setFlag(irr::video::EMF_LIGHTING, false);
	material.setFlag(irr::video::EMF_TRILINEAR_FILTER, true);
	material.setFlag(irr::video::EMF_ANISOTROPIC_FILTER, true);

	ADD_COMPONENT(SceneNodeEntityComponent,device, device->getSceneManager()->getRootSceneNode());
	ADD_COMPONENT(VisualModelEntityComponent,device, visualMesh);
	ADD_COMPONENT(PositionEntityComponent,irr::core::vector3df(0., 50., 0.));
	ADD_COMPONENT(RotationEntityComponent,irr::core::quaternion(0, irr::core::degToRad(45.f), 0));
	ADD_COMPONENT(MassEntityComponent,1.f);
	ADD_COMPONENT(InertiaEntityComponent,);
	ADD_COMPONENT(CollisionModelEntityComponent,collisionShape);
	ADD_COMPONENT(RigidBodyEntityComponent,physicsManager);
	ADD_COMPONENT(IrrlichtLoggerEntityComponent,device->getLogger());
	ADD_COMPONENT(VisualMaterialEntityComponent,material);
	ADD_COMPONENT(TextureEntityComponent,driver->getTexture("data/default_texture.jpg"));
	return entity;
}

std::shared_ptr<Engine::Framework::IEntity> Engine::EntityFactories::DebugEntityFactory::makeDebugPhysFloor()
{
	auto entity = std::make_shared<Engine::Entity>(ENTITY_DEBUG_PHYS_FLOOR);
	std::shared_ptr<btCollisionShape> shape = std::make_shared<btBoxShape>(btVector3(100.,1.,100.));

	ADD_COMPONENT(PositionEntityComponent,irr::core::vector3df(0., -1., 0.));
	ADD_COMPONENT(CollisionModelEntityComponent,shape);
	ADD_COMPONENT(CollisionObjectEntityComponent,physicsManager);
	return entity;
}