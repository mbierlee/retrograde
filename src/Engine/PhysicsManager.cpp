#include "PhysicsManager.h"

#include "Engine/PhysicsUtil.h"
#include "Engine/EntityComponents/CollisionObjectEntityComponent.h"
#include "Engine/EntityComponents/RigidBodyEntityComponent.h"

#define DEBUG_DRAW_FLAGS btIDebugDraw::DBG_DrawWireframe | btIDebugDraw::DBG_DrawAabb | btIDebugDraw::DBG_DrawText | btIDebugDraw::DBG_DrawNormals

Engine::PhysicsManager::PhysicsManager(std::shared_ptr<btIDebugDraw> debugDrawer)
	: collisionConfiguration(nullptr)
	, dispatcher(nullptr)
	, overlappingPairCache(nullptr)
	, solver(nullptr)
	, dynamicsWorld(nullptr)
	, debugDrawer(debugDrawer)
	, debugModeEnabled(false)
{
}

void Engine::PhysicsManager::initialize()
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

void Engine::PhysicsManager::setGravity(const irr::core::vector3df& gravity)
{
	dynamicsWorld->setGravity(transformIrrVector(gravity / 10.f));
}

void Engine::PhysicsManager::testStuff()
{
	setGravity(irr::core::vector3df(0, -100, 0));

	btAlignedObjectArray<btCollisionShape*> collisionShapes;
	
	// Test body 1
	{
		btCollisionShape* groundShape = new btBoxShape(btVector3(btScalar(10.),btScalar(1.),btScalar(10.)));	
		collisionShapes.push_back(groundShape);

		btTransform groundTransform;
		groundTransform.setIdentity();
		groundTransform.setOrigin(btVector3(0, -1., 0));

		btScalar mass = 0.;
		bool isDynamic = (mass != 0.);

		btVector3 localInertia(0,0,0);
		if (isDynamic) {
			groundShape->calculateLocalInertia(mass, localInertia);
		}

		btDefaultMotionState* motionState = new btDefaultMotionState(groundTransform);
		btRigidBody::btRigidBodyConstructionInfo rbInfo(mass, motionState, groundShape, localInertia);
		btRigidBody* body = new btRigidBody(rbInfo);

		dynamicsWorld->addRigidBody(body);
	}

	// Test body 2
	{
		//create a dynamic rigidbody

		btCollisionShape* colShape = new btSphereShape(btScalar(1.));
		collisionShapes.push_back(colShape);

		/// Create Dynamic Objects
		btTransform startTransform;
		startTransform.setIdentity();
		startTransform.setOrigin(btVector3(0,3,0));

		btScalar	mass(1.f);

		//rigidbody is dynamic if and only if mass is non zero, otherwise static
		bool isDynamic = (mass != 0.f);

		btVector3 localInertia(0,0,0);
		if (isDynamic)
			colShape->calculateLocalInertia(mass,localInertia);

		
		

		//using motionstate is recommended, it provides interpolation capabilities, and only synchronizes 'active' objects
		btDefaultMotionState* myMotionState = new btDefaultMotionState(startTransform);
		btRigidBody::btRigidBodyConstructionInfo rbInfo(mass,myMotionState,colShape,localInertia);
		btRigidBody* body = new btRigidBody(rbInfo);

		dynamicsWorld->addRigidBody(body);
	}
}

void Engine::PhysicsManager::update(irr::f32 timeStep)
{
	//TODO: Configurable timestep and substep
	dynamicsWorld->stepSimulation(btScalar(timeStep * 0.001f));

	if (debugModeEnabled) {
		dynamicsWorld->debugDrawWorld();
	}
}

void Engine::PhysicsManager::setDebugDrawing( bool enableDebugDrawing )
{
	debugModeEnabled = enableDebugDrawing;
}

void Engine::PhysicsManager::drawDebugData()
{
	if (debugDrawer->getDebugMode() != btIDebugDraw::DBG_NoDebug) {
		std::dynamic_pointer_cast<Engine::Framework::IIDebugDrawer>(debugDrawer)->drawDebugData();
	}
}

void Engine::PhysicsManager::registerCollisionObject(std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject)
{
	dynamicsWorld->addCollisionObject(collisionObject->getCollisionObject());
}

void Engine::PhysicsManager::registerCollisionObject( std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject, irr::s16 group, irr::s16 mask )
{
	dynamicsWorld->addCollisionObject(collisionObject->getCollisionObject(), group, mask);
}

void Engine::PhysicsManager::registerRigidBody( std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody )
{
	dynamicsWorld->addRigidBody(rigidBody->getRigidBody());
}

void Engine::PhysicsManager::registerRigidBody( std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody, irr::s16 group, irr::s16 mask )
{
	dynamicsWorld->addRigidBody(rigidBody->getRigidBody(), group, mask);
}
