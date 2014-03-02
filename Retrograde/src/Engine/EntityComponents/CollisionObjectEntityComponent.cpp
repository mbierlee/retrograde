#include "CollisionObjectEntityComponent.h"

#include "Engine/EntityComponents/CollisionModelEntityComponent.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"
#include "Engine/EntityComponents/CollisionGroupEntityComponent.h"
#include "Engine/EntityComponents/CollisionMaskEntityComponent.h"
#include "Engine/EntityComponents/FrictionEntityComponent.h"
#include "Engine/UnitTransformationUtil.h"

Engine::EntityComponents::CollisionObjectEntityComponent::CollisionObjectEntityComponent(std::shared_ptr<Engine::Framework::IPhysicsService> physicsService)
	: collisionObject(nullptr)
	, physicsService(physicsService)
{
}

const irr::core::stringc Engine::EntityComponents::CollisionObjectEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::CollisionObjectEntityComponent::getFamilyType() const
{
	return familyType();
}

void Engine::EntityComponents::CollisionObjectEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (!collisionObject) {
		initialize(entity);
	}
}

const irr::core::stringc Engine::EntityComponents::CollisionObjectEntityComponent::componentType()
{
	return "CollisionObjectEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::CollisionObjectEntityComponent::familyType()
{
	return "CollisionObjectEntityComponent";
}

btCollisionObject* Engine::EntityComponents::CollisionObjectEntityComponent::getCollisionObject() const
{
	return collisionObject;
}

void Engine::EntityComponents::CollisionObjectEntityComponent::initialize( Engine::Framework::IEntity* entity )
{
	auto collisionModelComponent = COMPONENT(CollisionModelEntityComponent);

	if (collisionModelComponent) {
		std::shared_ptr<btCollisionShape> shape = collisionModelComponent->getCollisionShape();

		if (shape) {
			auto positionComponent = COMPONENT(PositionEntityComponent);
			auto rotationComponent = COMPONENT(RotationEntityComponent);
			auto collisionGroupComponent = COMPONENT(CollisionGroupEntityComponent);
			auto collisionMaskComponent = COMPONENT(CollisionMaskEntityComponent);
			auto frictionComponent = COMPONENT(FrictionEntityComponent);

			btTransform transform;
			transform.setIdentity();
			if (positionComponent) transform.setOrigin(transformIrrVector(positionComponent->getPosition()));
			if (rotationComponent) {
				transform.setRotation(transformIrrQuaternion(rotationComponent->getRotation()));
			}

			btScalar friction = 1.f;
			if (frictionComponent) {
				friction = frictionComponent->getFriction();
			}

			collisionObject = new btCollisionObject();
			collisionObject->setCollisionShape(shape.get());
			collisionObject->setWorldTransform(transform);
			collisionObject->setFriction(friction);

			irr::s16 group = collisionGroupComponent ? collisionGroupComponent->getGroup() : btBroadphaseProxy::StaticFilter;
			irr::s16 mask = collisionMaskComponent ? collisionMaskComponent->getMask() : btBroadphaseProxy::AllFilter ^ btBroadphaseProxy::StaticFilter;

			if (collisionGroupComponent || collisionMaskComponent) {
				physicsService->registerCollisionObject(std::static_pointer_cast<Engine::EntityComponents::CollisionObjectEntityComponent>(shared_from_this()), group, mask);
			} else {
				physicsService->registerCollisionObject(std::static_pointer_cast<Engine::EntityComponents::CollisionObjectEntityComponent>(shared_from_this()));
			}
		}
	} else {
		auto loggerComponent = COMPONENT(IrrlichtLoggerEntityComponent);
		if (loggerComponent) {
			char logText[1024];
			snprintf(logText, 2, "CollisionObjectEntityComponent: Entity %s(%u) has no collision model component.", entity->getType().c_str(), entity->getId());
			loggerComponent->log(logText);
		}
	}
}
