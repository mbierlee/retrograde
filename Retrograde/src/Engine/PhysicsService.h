#pragma once

#include "Engine/Framework/IPhysicsService.h"

#include <btBulletDynamicsCommon.h>

#include <Hypodermic/AutowiredConstructor.h>

#include <memory>

namespace Engine {

class PhysicsService: public Engine::Framework::IPhysicsService {
private:
	btDefaultCollisionConfiguration* collisionConfiguration;
	btCollisionDispatcher* dispatcher;
	btBroadphaseInterface* overlappingPairCache;
	btSequentialImpulseConstraintSolver* solver;
	btDiscreteDynamicsWorld* dynamicsWorld;

	std::shared_ptr<btIDebugDraw> debugDrawer;
	bool debugModeEnabled;

public:
	typedef Hypodermic::AutowiredConstructor<PhysicsService(btIDebugDraw*)> AutowiredSignature;

	PhysicsService(std::shared_ptr<btIDebugDraw> debugDrawer);

	virtual void initialize() override;
	virtual void setGravity(const irr::core::vector3df& gravity) override;
	virtual void update(irr::f32 timeStep) override;

	virtual void setDebugDrawing(bool enableDebugDrawing) override;

	virtual void drawDebugData() override;

	virtual void registerCollisionObject(std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject) override;

	virtual void registerCollisionObject(std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject, irr::s16 group,
			irr::s16 mask) override;

	virtual void registerRigidBody(std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody) override;

	virtual void registerRigidBody(std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody, irr::s16 group, irr::s16 mask) override;
};

}
