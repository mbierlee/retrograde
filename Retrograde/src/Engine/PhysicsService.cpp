#include "PhysicsService.h"

#include "Engine/UnitTransformationUtil.h"
#include "Engine/EntityComponents/CollisionObjectEntityComponent.h"
#include "Engine/EntityComponents/RigidBodyEntityComponent.h"

#define DEBUG_DRAW_FLAGS btIDebugDraw::DBG_DrawWireframe | btIDebugDraw::DBG_DrawAabb | btIDebugDraw::DBG_DrawText | btIDebugDraw::DBG_DrawNormals

Engine::PhysicsService::PhysicsService(std::shared_ptr<btIDebugDraw> debugDrawer)
	: collisionConfiguration(nullptr)
	, dispatcher(nullptr)
	, overlappingPairCache(nullptr)
	, solver(nullptr)
	, dynamicsWorld(nullptr)
	, debugDrawer(debugDrawer)
	, debugModeEnabled(false)
{
}

void Engine::PhysicsService::initialize()
{
	collisionConfiguration = new btDefaultCollisionConfiguration();
	dispatcher = new btCollisionDispatcher(collisionConfiguration);
	overlappingPairCache = new btDbvtBroadphase();
	solver = new btSequentialImpulseConstraintSolver;
	dynamicsWorld = new btDiscreteDynamicsWorld(dispatcher,overlappingPairCache,solver,collisionConfiguration);
	dynamicsWorld->setGravity(btVector3(0,-10,0));
	dynamicsWorld->setDebugDrawer(debugDrawer.get());
	debugDrawer->setDebugMode(DEBUG_DRAW_FLAGS);
}

void Engine::PhysicsService::setGravity(const irr::core::vector3df& gravity)
{
	dynamicsWorld->setGravity(transformIrrVector(gravity / 10.f));
}

void Engine::PhysicsService::update(irr::f32 timeStep)
{
	dynamicsWorld->stepSimulation(btScalar(timeStep * 0.001f));

	if (debugModeEnabled) {
		dynamicsWorld->debugDrawWorld();
	}
}

void Engine::PhysicsService::setDebugDrawing( bool enableDebugDrawing )
{
	debugModeEnabled = enableDebugDrawing;
}

void Engine::PhysicsService::drawDebugData()
{
	if (debugDrawer->getDebugMode() != btIDebugDraw::DBG_NoDebug) {
		std::dynamic_pointer_cast<Engine::Framework::IIDebugDrawer>(debugDrawer)->drawDebugData();
	}
}

void Engine::PhysicsService::registerCollisionObject(std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject)
{
	dynamicsWorld->addCollisionObject(collisionObject->getCollisionObject());
}

void Engine::PhysicsService::registerCollisionObject( std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject, irr::s16 group, irr::s16 mask )
{
	dynamicsWorld->addCollisionObject(collisionObject->getCollisionObject(), group, mask);
}

void Engine::PhysicsService::registerRigidBody( std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody )
{
	dynamicsWorld->addRigidBody(rigidBody->getRigidBody());
}

void Engine::PhysicsService::registerRigidBody( std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody, irr::s16 group, irr::s16 mask )
{
	dynamicsWorld->addRigidBody(rigidBody->getRigidBody(), group, mask);
}