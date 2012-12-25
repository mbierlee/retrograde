#pragma once

#include "Engine/Framework/IEntityComponent.h"
#include "Engine/Framework/IPhysicsManager.h"

#include <btBulletDynamicsCommon.h>

#include <memory>

namespace Engine { namespace EntityComponents {

	class CollisionObjectEntityComponent 
		: public Engine::Framework::IEntityComponent
	{
	private:
		btCollisionObject* collisionObject;
		std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager;

	public:
		CollisionObjectEntityComponent(std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime );
	};

}}