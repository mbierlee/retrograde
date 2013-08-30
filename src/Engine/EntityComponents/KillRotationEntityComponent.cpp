#include "KillRotationEntityComponent.h"

#include "Engine/EntityComponents/RigidBodyEntityComponent.h"

#include <BulletDynamics/Dynamics/btRigidBody.h>

Engine::EntityComponents::KillRotationEntityComponent::KillRotationEntityComponent()
	: killedRotation(false)
{
}

const irr::core::stringc Engine::EntityComponents::KillRotationEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::KillRotationEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::KillRotationEntityComponent::componentType()
{
	return "KillRotationEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::KillRotationEntityComponent::familyType()
{
	return "KillRotationEntityComponent";
}

void Engine::EntityComponents::KillRotationEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (!killedRotation) {
		auto rigidBodyEc = COMPONENT(RigidBodyEntityComponent);
		if (rigidBodyEc) {
			btRigidBody* rigidBody = rigidBodyEc->getRigidBody();
			rigidBody->setAngularFactor(0);
			killedRotation = true;
		}
	}
}