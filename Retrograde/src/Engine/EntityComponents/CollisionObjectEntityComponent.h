#pragma once

#include "Engine/Base/BaseEntityComponent.h"
#include "Engine/Framework/IPhysicsService.h"

#include <btBulletCollisionCommon.h>

#include <memory>

namespace Engine {
namespace EntityComponents {

class CollisionObjectEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	btCollisionObject* collisionObject;
	std::shared_ptr<Engine::Framework::IPhysicsService> physicsService;
	void initialize(Engine::Framework::IEntity* entity);

public:
	CollisionObjectEntityComponent(std::shared_ptr<Engine::Framework::IPhysicsService> physicsService);

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;

	btCollisionObject* getCollisionObject() const;
};

}
}
