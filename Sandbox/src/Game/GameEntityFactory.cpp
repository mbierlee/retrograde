#include "GameEntityFactory.h"

#include "Game/GameEntityDefinitions.h"
#include "Game/GameEventDefinitions.h"

#include <Engine/Entity.h>
#include <Engine/UnitTransformationUtil.h>
#include <Engine/EntityComponents/PositionEntityComponent.h>
#include <Engine/EntityComponents/RotationEntityComponent.h>
#include <Engine/EntityComponents/FirstPersonCameraEntityComponent.h>
#include <Engine/EntityComponents/SceneNodeEntityComponent.h>
#include <Engine/EntityComponents/HeadRotationEntityComponent.h>
#include <Engine/EntityComponents/HeightEntityComponent.h>
#include <Engine/EntityComponents/RigidBodyEntityComponent.h>
#include <Engine/EntityComponents/CollisionModelEntityComponent.h>
#include <Engine/EntityComponents/FirstPersonInputEntityComponent.h>
#include <Engine/EntityComponents/OriginOffsetEntityComponent.h>
#include <Engine/EntityComponents/MassEntityComponent.h>
#include <Engine/EntityComponents/KillRotationEntityComponent.h>
#include <Engine/EntityComponents/FrictionEntityComponent.h>

#include <Bullet/BulletCollision/CollisionShapes/btCapsuleShape.h>

#include <memory>
#include <ISceneManager.h>

Game::GameEntityFactory::GameEntityFactory( std::shared_ptr<irr::IrrlichtDevice> device, std::shared_ptr<Engine::Framework::IPhysicsService> physicsService, std::shared_ptr<Engine::Framework::IEventService> eventService )
	: device(device)
	, physicsService(physicsService)
	, eventService(eventService)
{
}

std::shared_ptr<Engine::Framework::IEntity> Game::GameEntityFactory::create( irr::core::stringc entityType )
{
	if (entityType == ENTITY_PLAYER) {
		return makePlayer();
	}

	return std::shared_ptr<Engine::Framework::IEntity>();
}

void Game::GameEntityFactory::clearPool()
{
}

std::shared_ptr<Engine::Framework::IEntity> Game::GameEntityFactory::makePlayer()
{
	auto entity = std::make_shared<Engine::Entity>(ENTITY_PLAYER);
	irr::f32 height = 1.8f;
	std::shared_ptr<btCapsuleShape> shape = std::make_shared<btCapsuleShape>((btScalar)0.4, (btScalar)(height - 0.8));

	ADD_COMPONENT(KillRotationEntityComponent);
	ADD_COMPONENT(FrictionEntityComponent, 5.f);
	ADD_COMPONENT(PositionEntityComponent, irr::core::vector3df(-9.5, 0, -9.));
	ADD_COMPONENT(RotationEntityComponent);
	ADD_COMPONENT(HeadRotationEntityComponent);
	ADD_COMPONENT(MassEntityComponent, 1.f);
	ADD_COMPONENT(SceneNodeEntityComponent, device, device->getSceneManager()->getRootSceneNode());
	ADD_COMPONENT(FirstPersonCameraEntityComponent, device, 0.1f);
	ADD_COMPONENT(HeightEntityComponent, height);
	ADD_COMPONENT(RigidBodyEntityComponent, physicsService);
	ADD_COMPONENT(CollisionModelEntityComponent, shape);
	ADD_COMPONENT(OriginOffsetEntityComponent, irr::core::vector3df(0, (irr::f32) -(height/2.f), 0));
	Engine::EntityComponents::FirstPersonInputEntityComponent* inputEc = new Engine::EntityComponents::FirstPersonInputEntityComponent(
		EV_MOVE_FORWARD,
		EV_MOVE_BACKWARD,
		EV_MOVE_LEFT,
		EV_MOVE_RIGHT,
		EV_TURN_LEFT,
		EV_TURN_RIGHT
		);

	entity->addComponent(std::shared_ptr<Engine::EntityComponents::FirstPersonInputEntityComponent>(inputEc));
	eventService->registerObserver(entity);
	return entity;
}