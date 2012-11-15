#pragma once

#include <btBulletDynamicsCommon.h>

#include "IrrlichtDevice.h"
#include "IVideoDriver.h"

#include <memory>

namespace Engine { namespace Bullet {

	class IrrlichtPhysicsDebugDrawer 
		: public btIDebugDraw
	{
	private:
		irr::video::IVideoDriver* driver;
		int debugMode;
		irr::ILogger* logger;

	public:
		IrrlichtPhysicsDebugDrawer(std::shared_ptr<irr::IrrlichtDevice> device);

		virtual void drawLine( const btVector3& from,const btVector3& to,const btVector3& color );
		
		virtual void drawContactPoint( const btVector3& PointOnB,const btVector3& normalOnB,btScalar distance,int lifeTime,const btVector3& color );
		virtual void reportErrorWarning( const char* warningString );
		virtual void draw3dText( const btVector3& location,const char* textString );

		virtual void setDebugMode( int debugMode );
		virtual int getDebugMode() const;
	};

}}