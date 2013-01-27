#include "CollisionModelEntityComponent.h"

Engine::EntityComponents::CollisionModelEntityComponent::CollisionModelEntityComponent(std::shared_ptr<btCollisionShape> collisionShape)
	: collisionShape(collisionShape)
{	
}

const irr::core::stringc Engine::EntityComponents::CollisionModelEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::CollisionModelEntityComponent::getFamilyType() const
{
	return familyType();
}

void Engine::EntityComponents::CollisionModelEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

const irr::core::stringc Engine::EntityComponents::CollisionModelEntityComponent::componentType()
{
	return "CollisionModelEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::CollisionModelEntityComponent::familyType()
{
	return "CollisionModelEntityComponent";
}

std::shared_ptr<btCollisionShape> Engine::EntityComponents::CollisionModelEntityComponent::getCollisionShape()
{
	return collisionShape;
}
