#pragma once

#include "Engine/Framework/IPhysicsManager.h"

#include "btBulletDynamicsCommon.h"

namespace Engine {

	class PhysicsManager 
		: public Engine::Framework::IPhysicsManager
	{
	private:
		btDefaultCollisionConfiguration* collisionConfiguration;
		btCollisionDispatcher* dispatcher;
		btBroadphaseInterface* overlappingPairCache;
		btSequentialImpulseConstraintSolver* solver;
		btDiscreteDynamicsWorld* dynamicsWorld;

		btVector3 transformIrrVector( const irr::core::vector3df& vector);
	public:
		PhysicsManager();

		virtual void initialize();
		virtual void setGravity( const irr::core::vector3df& gravity );
	};

}