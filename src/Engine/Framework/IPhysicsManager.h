#pragma once

#include "Engine/Framework/IDebugDrawer.h"

#include <vector3d.h>

#include <vector>
#include <memory>

namespace Engine { 
	namespace EntityComponents {
		class CollisionObjectEntityComponent;
		class RigidBodyEntityComponent;
	}
	
	namespace Framework {

	class IPhysicsManager 
		: public Engine::Framework::IIDebugDrawer
	{
	public:
		virtual ~IPhysicsManager() {}

		virtual void initialize() =0;
		virtual void setGravity(const irr::core::vector3df& gravity) =0;
		virtual void update(irr::f32 timeStep) =0;
		virtual void setDebugDrawing(bool enableDebugDrawing) =0;
		virtual void registerCollisionObject(std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject) =0;
		virtual void registerCollisionObject(std::shared_ptr<Engine::EntityComponents::CollisionObjectEntityComponent> collisionObject, irr::s16 group, irr::s16 mask) =0;
		virtual void registerRigidBody(std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody) =0;		
		virtual void registerRigidBody(std::shared_ptr<Engine::EntityComponents::RigidBodyEntityComponent> rigidBody, irr::s16 group, irr::s16 mask) =0;
	};

}}