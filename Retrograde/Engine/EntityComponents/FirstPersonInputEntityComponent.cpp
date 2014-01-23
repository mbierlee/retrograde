#include "FirstPersonInputEntityComponent.h"

#include "Engine/EntityComponents/RigidBodyEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/HeadRotationEntityComponent.h"
#include "Engine/MagnitudeEvent.h"
#include "Engine/UnitTransformationUtil.h"

#include <BulletDynamics/Dynamics/btRigidBody.h>

Engine::EntityComponents::FirstPersonInputEntityComponent::FirstPersonInputEntityComponent(
	irr::core::stringc moveForwardEvent, irr::core::stringc moveBackwardEvent,
	irr::core::stringc moveLeftEvent, irr::core::stringc moveRightEvent,
	irr::core::stringc turnLeftEvent, irr::core::stringc turnRightEvent)
	: subscribedToEvents(false)
	, moveForwardEvent(moveForwardEvent)
	, moveBackwardEvent(moveBackwardEvent)
	, moveLeftEvent(moveLeftEvent)
	, moveRightEvent(moveRightEvent)
	, turnLeftEvent(turnLeftEvent)
	, turnRightEvent(turnRightEvent)
	, forwardMagnitude(0.f)
	, backwardsMagnitude(0.f)
	, leftMagnitude(0.f)
	, rightMagnitude(0.f)
	, turnLeftMagnitude(0.f)
	, turnRightMagnitude(0.f)
	, previouslyMoving(false)
{
}

const irr::core::stringc Engine::EntityComponents::FirstPersonInputEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::FirstPersonInputEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::FirstPersonInputEntityComponent::componentType()
{
	return "FirstPersonInputEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::FirstPersonInputEntityComponent::familyType()
{
	return "FirstPersonInputEntityComponent";
}

void Engine::EntityComponents::FirstPersonInputEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (!subscribedToEvents) {
		entity->subscribeToEvents(shared_from_this());
		subscribedToEvents = true;
	}

	if (previouslyMoving) {
		auto rigidBodyEc = COMPONENT(RigidBodyEntityComponent);
		btRigidBody* rigidBody = rigidBodyEc->getRigidBody();
		// Set damping instead? Would need to be adjusted while mid-air
		btVector3 linearVelocity = rigidBody->getLinearVelocity();
		linearVelocity.setX(0);
		linearVelocity.setZ(0);
		rigidBody->setLinearVelocity(linearVelocity);
		previouslyMoving = false;
	}

	btVector3 movementVector(0, 0, 0);

	if (forwardMagnitude > 0.f || backwardsMagnitude > 0.f) {
		btScalar velocity = 10.f;
		auto rotationEc = COMPONENT(RotationEntityComponent);
		irr::core::quaternion rotation = rotationEc->getRotation();
		irr::f32 angle;
		irr::core::vector3df axis;
		rotation.toAngleAxis(angle, axis);

		btVector3 direction(0, 0, 1);
		direction.rotate(transformIrrVector(axis), angle);
		direction.normalize();

		if (forwardMagnitude > 0.f) {
			movementVector.rotate(transformIrrVector(axis), angle);
			movementVector = direction * velocity * forwardMagnitude;
		}

		if (backwardsMagnitude > 0.f) {
			movementVector.rotate(transformIrrVector(axis), angle);
			movementVector = -direction * velocity * backwardsMagnitude;
		}
	}

	if (!movementVector.isZero()) {
		auto rigidBodyEc = COMPONENT(RigidBodyEntityComponent);
		btRigidBody* rigidBody = rigidBodyEc->getRigidBody();
		rigidBody->activate(true);
		rigidBody->applyCentralImpulse(movementVector);
		previouslyMoving = true;
	}

	// TEMP till rotation is in properly
	auto rotationEc = COMPONENT(RotationEntityComponent);
	irr::core::quaternion rotation = rotationEc->getRotation();
	auto headEc = COMPONENT(HeadRotationEntityComponent);
	headEc->setRotation(rotation);
	//////////////////////////////////////////////////////////////////////////
}

void Engine::EntityComponents::FirstPersonInputEntityComponent::handleEvent( const Engine::Framework::IEvent& event, Engine::Framework::IEntity* entity, void* source )
{
	if (event.getName() == moveForwardEvent) {
		const Engine::MagnitudeEvent& magEvent = static_cast<const Engine::MagnitudeEvent&>(event);
		forwardMagnitude = magEvent.getMagnitude();
	} else if (event.getName() == moveBackwardEvent) {
		const Engine::MagnitudeEvent& magEvent = static_cast<const Engine::MagnitudeEvent&>(event);
		backwardsMagnitude = magEvent.getMagnitude();
	} else if (event.getName() == moveLeftEvent) {
		const Engine::MagnitudeEvent& magEvent = static_cast<const Engine::MagnitudeEvent&>(event);
		leftMagnitude = magEvent.getMagnitude();
	} else if (event.getName() == moveRightEvent) {
		const Engine::MagnitudeEvent& magEvent = static_cast<const Engine::MagnitudeEvent&>(event);
		rightMagnitude = magEvent.getMagnitude();
	} else if (event.getName() == turnLeftEvent) {
		const Engine::MagnitudeEvent& magEvent = static_cast<const Engine::MagnitudeEvent&>(event);
		turnLeftMagnitude = magEvent.getMagnitude();
	} else if (event.getName() == turnRightEvent) {
		const Engine::MagnitudeEvent& magEvent = static_cast<const Engine::MagnitudeEvent&>(event);
		turnRightMagnitude = magEvent.getMagnitude();
	}
}