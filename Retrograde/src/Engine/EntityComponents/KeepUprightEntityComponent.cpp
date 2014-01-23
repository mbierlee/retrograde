#include "KeepUprightEntityComponent.h"

#include "Engine/EntityComponents/RigidBodyEntityComponent.h"

Engine::EntityComponents::KeepUprightEntityComponent::KeepUprightEntityComponent()
	: uprightSet(false)
{
}

const irr::core::stringc Engine::EntityComponents::KeepUprightEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::KeepUprightEntityComponent::getFamilyType() const
{
	return familyType();
}

const irr::core::stringc Engine::EntityComponents::KeepUprightEntityComponent::componentType()
{
	return "KeepUprightEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::KeepUprightEntityComponent::familyType()
{
	return "KeepUprightEntityComponent";
}

void Engine::EntityComponents::KeepUprightEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (!uprightSet) {
		auto rigitBodyComponent = COMPONENT(RigidBodyEntityComponent);
		btRigidBody* rigidBody = rigitBodyComponent->getRigidBody();
		rigidBody->setAngularFactor(btVector3(0, 1, 0));
		uprightSet = true;
	}
}

bool Engine::EntityComponents::KeepUprightEntityComponent::isUpright()
{
	return uprightSet;
}