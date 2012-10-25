#include "PhysicsManager.h"


Engine::PhysicsManager::PhysicsManager()
	: collisionConfiguration(nullptr)
	, dispatcher(nullptr)
	, overlappingPairCache(nullptr)
	, solver(nullptr)
	, dynamicsWorld(nullptr)
{
}

void Engine::PhysicsManager::initialize()
{
	btDefaultCollisionConfiguration* collisionConfiguration = new btDefaultCollisionConfiguration();
	btCollisionDispatcher* dispatcher = new	btCollisionDispatcher(collisionConfiguration);
	btBroadphaseInterface* overlappingPairCache = new btDbvtBroadphase();
	btSequentialImpulseConstraintSolver* solver = new btSequentialImpulseConstraintSolver;
	btDiscreteDynamicsWorld* dynamicsWorld = new btDiscreteDynamicsWorld(dispatcher,overlappingPairCache,solver,collisionConfiguration);
	dynamicsWorld->setGravity(btVector3(0,-10,0));
}

void Engine::PhysicsManager::setGravity( const irr::core::vector3df& gravity )
{
	dynamicsWorld->setGravity(transformIrrVector(gravity));
}

btVector3 Engine::PhysicsManager::transformIrrVector( const irr::core::vector3df& vector )
{
	return btVector3(vector.X, vector.Y, vector.Z);
}
