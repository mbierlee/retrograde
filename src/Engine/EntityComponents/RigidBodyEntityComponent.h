#pragma once

#include "Engine/Framework/IEntityComponent.h"
#include "Engine/Framework/IPhysicsManager.h"
#include "Engine/Bullet/HandledMotionState.h"

#include  <btBulletDynamicsCommon.h>

namespace Engine { namespace EntityComponents {

	class RigidBodyEntityComponent
		: public Engine::Framework::IEntityComponent
		, public std::enable_shared_from_this<RigidBodyEntityComponent>
	{	
	private:
		btRigidBody* rigidBody;
		std::shared_ptr<Engine::Framework::IPhysicsManager> physicsManager;
		Engine::Bullet::HandledMotionState* motionState;

	public:
		RigidBodyEntityComponent();

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);

		void initialize( Engine::Framework::IEntity* entity );

		btRigidBody* getRigidBody() const;
	};

}}