#pragma once

#include "Engine/Framework/IPhysicsService.h"

#include <btBulletDynamicsCommon.h>

#include <memory>

namespace Engine {
	class PhysicsService
		: public Engine::Framework::IPhysicsService
	{
	private:
		btDefaultCollisionConfiguration* collisionConfiguration;
		btCollisionDispatcher* dispatcher;
		btBroadphaseInterface* overlappingPairCache;
		btSequentialImpulseConstraintSolver* solver;
		btDiscreteDynamicsWorld* dynamicsWorld;

		std::shared_ptr<btIDebugDraw> debugDrawer;
		bool debugModeEnabled;

	public:
		PhysicsService(std::shared_ptr<btIDebugDraw> debugDrawer);

		virtual void initialize();
		virtual void setGravity(const irr::core::vector3df& gravity);
		virtual void update(irr::f32 timeStep);

		virtual void setDebugDrawing( bool enableDebugDrawing );

		virtual void drawDebugData();

		virtual void registerCollisionObject(std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject);

		virtual void registerCollisionObject( std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject, irr::s16 group, irr::s16 mask );

		virtual void registerRigidBody( std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody );

		virtual void registerRigidBody( std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody, irr::s16 group, irr::s16 mask );
	};
}