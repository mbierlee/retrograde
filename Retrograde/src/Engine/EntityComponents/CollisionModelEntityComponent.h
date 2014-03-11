#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <btBulletDynamicsCommon.h>

namespace Engine {
namespace EntityComponents {

class CollisionModelEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	std::shared_ptr<btCollisionShape> collisionShape;

public:
	CollisionModelEntityComponent(std::shared_ptr<btCollisionShape> collisionShape);

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	std::shared_ptr<btCollisionShape> getCollisionShape();
};

}
}
