#include "CollisionObjectEntityComponent.h"

#include "Engine/EntityComponents/CollisionModelEntityComponent.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/MassEntityComponent.h"
#include "Engine/EntityComponents/InertiaEntityComponent.h"

Engine::EntityComponents::CollisionObjectEntityComponent::CollisionObjectEntityComponent(std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager)
	: collisionObject(nullptr)
	, physicsManager(physicsManager)
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
		auto collisionModel = COMPONENT(CollisionModelEntityComponent);
		auto mass = COMPONENT(MassEntityComponent);
		auto inertia = COMPONENT(InertiaEntityComponent);		
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
