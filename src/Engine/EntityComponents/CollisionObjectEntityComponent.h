#pragma once

#include "Engine/Base/BaseEntityComponent.h"
#include "Engine/Framework/IPhysicsManager.h"

#include <btBulletCollisionCommon.h>

#include <memory>

namespace Engine { namespace EntityComponents {

	class CollisionObjectEntityComponent 
		: public Engine::Base::BaseEntityComponent
		, public std::enable_shared_from_this<CollisionObjectEntityComponent>
	{
	private:
		btCollisionObject* collisionObject;
		std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager;
		void initialize( Engine::Framework::IEntity* entity );

	public:
		CollisionObjectEntityComponent();

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime );

		btCollisionObject* getCollisionObject() const;
	};

}}