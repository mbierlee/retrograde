#include "RigidBodyEntityComponent.h"

#include "Engine/EntityComponents/CollisionModelEntityComponent.h"
#include "Engine/EntityComponents/MassEntityComponent.h"
#include "Engine/EntityComponents/InertiaEntityComponent.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/CollisionGroupEntityComponent.h"
#include "Engine/EntityComponents/CollisionMaskEntityComponent.h"
#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"
#include "Engine/PhysicsUtil.h"
#include "Engine/TypeContainerConfig.h"

Engine::EntityComponents::RigidBodyEntityComponent::RigidBodyEntityComponent()
	: rigidBody(nullptr)
	, motionState(nullptr)
{
	physicsManager = typeContainer->resolve<Engine::Framework::IPhysicsManager>();
}

const irr::core::stringc Engine::EntityComponents::RigidBodyEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::RigidBodyEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::RigidBodyEntityComponent::componentType()
{
	return "RigidBodyEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::RigidBodyEntityComponent::familyType()
{
	return "CollisionObjectEntityComponent";
}

void Engine::EntityComponents::RigidBodyEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (!rigidBody) {
		initialize(entity);
	} 

	if (motionState && motionState->isChanged()) {
		btTransform transform;
		motionState->getWorldTransform(transform);
		
		auto positionComponent = COMPONENT(PositionEntityComponent);
		auto rotationComponent = COMPONENT(RotationEntityComponent);

		positionComponent->setPosition(transformBulletVector(transform.getOrigin()));
		//TODO: Set rotation when converted rotationcomponent to quarternion
		motionState->resetChanged();
	}
}

btRigidBody* Engine::EntityComponents::RigidBodyEntityComponent::getRigidBody() const
{
	return rigidBody;
}

void Engine::EntityComponents::RigidBodyEntityComponent::initialize( Engine::Framework::IEntity* entity )
{
	auto collisionModelComponent = COMPONENT(CollisionModelEntityComponent);

	if (collisionModelComponent) {
		std::shared_ptr<btCollisionShape> shape = collisionModelComponent->getCollisionShape();
		if (shape) {
			auto massComponent = COMPONENT(MassEntityComponent);
			auto inertiaComponent = COMPONENT(InertiaEntityComponent);		
			auto positionComponent = COMPONENT(PositionEntityComponent);
			auto rotationComponent = COMPONENT(RotationEntityComponent);
			auto collisionGroupComponent = COMPONENT(CollisionGroupEntityComponent);
			auto collisionMaskComponent = COMPONENT(CollisionMaskEntityComponent);

			btTransform startTransform;
			startTransform.setIdentity();
			if (positionComponent) startTransform.setOrigin(transformIrrVector(positionComponent->getPosition()));
			if (rotationComponent) {
				irr::core::vector3df rotation = rotationComponent->getEulerRotation();
				startTransform.setRotation(btQuaternion(rotation.Y, rotation.X, rotation.Z));
			}

			btVector3 inertia;
			irr::f32 mass = 0.;
			if (massComponent && inertiaComponent) {
				mass = massComponent->getMass();
				inertia = transformIrrVector(inertiaComponent->getIntertia());
				bool isDynamic = (mass != 0.);
				if (isDynamic) {
					shape->calculateLocalInertia(mass, inertia);
				}
			}

			motionState = new Engine::Bullet::HandledMotionState(startTransform);
			btRigidBody::btRigidBodyConstructionInfo rigidBodyInfo(mass, motionState, shape.get(), inertia);
			rigidBody = new btRigidBody(rigidBodyInfo);

			irr::s16 group = collisionGroupComponent ? collisionGroupComponent->getGroup() : 0;
			irr::s16 mask = collisionMaskComponent ? collisionMaskComponent->getMask() : 0;

			if (collisionGroupComponent || collisionMaskComponent) {
				physicsManager->registerRigidBody(shared_from_this(), group, mask);
			} else {
				physicsManager->registerRigidBody(shared_from_this());	
			}
		}
	} else {
		auto loggerComponent = COMPONENT(IrrlichtLoggerEntityComponent);
		if (loggerComponent) {
			char logText[1024];
			snprintf(logText, 2, "CollisionObjectEntityComponent: Entity %s(%u) has no collision model component.", entity->getType(), entity->getId());
			loggerComponent->log(logText);
		}
	}
}
