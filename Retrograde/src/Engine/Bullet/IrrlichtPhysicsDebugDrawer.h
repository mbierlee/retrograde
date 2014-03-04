#pragma once

#include "Engine/Framework/IDebugDrawer.h"

#include <btBulletDynamicsCommon.h>

#include <Hypodermic/AutowiredConstructor.h>

#include <IrrlichtDevice.h>
#include <IVideoDriver.h>
#include <irrString.h>
#include <ISceneManager.h>

#include <memory>
#include <vector>
#include <tuple>

namespace Engine { namespace Bullet {
	class IrrlichtPhysicsDebugDrawer
		: public btIDebugDraw
		, public Engine::Framework::IIDebugDrawer
	{
	private:
		struct SDebugLine
		{
			irr::core::vector3df from;
			irr::core::vector3df to;
			irr::video::SColor color;

			SDebugLine(irr::core::vector3df from
				, irr::core::vector3df to
				, irr::video::SColor color);
		};

		irr::video::IVideoDriver* driver;
		int debugMode;
		irr::ILogger* logger;

		std::vector<SDebugLine> debugLines;

	public:
		typedef Hypodermic::AutowiredConstructor<IrrlichtPhysicsDebugDrawer(irr::IrrlichtDevice*)> AutowiredSignature;

		IrrlichtPhysicsDebugDrawer(std::shared_ptr<irr::IrrlichtDevice> device);

		virtual void drawLine( const btVector3& from,const btVector3& to,const btVector3& color );

		virtual void drawContactPoint( const btVector3& PointOnB,const btVector3& normalOnB,btScalar distance,int lifeTime,const btVector3& color );
		virtual void reportErrorWarning( const char* warningString );
		virtual void draw3dText( const btVector3& location,const char* textString );

		virtual void setDebugMode( int debugMode );
		virtual int getDebugMode() const;

		virtual void drawDebugData();
	};
}}
