#include "IrrlichtPhysicsDebugDrawer.h"

#include "Engine/PhysicsUtil.h"

Engine::Bullet::IrrlichtPhysicsDebugDrawer::IrrlichtPhysicsDebugDrawer( std::shared_ptr<irr::IrrlichtDevice> device )
	: debugMode(btIDebugDraw::DBG_NoDebug)
{
	driver = device->getVideoDriver();
	logger = device->getLogger();
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::drawLine( const btVector3& from,const btVector3& to,const btVector3& color )
{
	//TODO: Translate to world proportions
	driver->draw3DLine(transformBulletVector(from)*10, transformBulletVector(to)*10, transformBulletColor(color).toSColor());
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::drawContactPoint( const btVector3& PointOnB,const btVector3& normalOnB,btScalar distance,int lifeTime,const btVector3& color )
{
	//throw std::exception("The method or operation is not implemented.");
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::reportErrorWarning( const char* warningString )
{
	logger->log(warningString);
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::draw3dText( const btVector3& location,const char* textString )
{
	//throw std::exception("The method or operation is not implemented.");
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::setDebugMode( int debugMode )
{
	this->debugMode = debugMode;
}

int Engine::Bullet::IrrlichtPhysicsDebugDrawer::getDebugMode() const
{
	return debugMode;
}