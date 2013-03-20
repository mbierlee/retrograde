#include "IrrlichtPhysicsDebugDrawer.h"

#include "Engine/UnitTransformationUtil.h"

#include <SMaterial.h>
#include <matrix4.h>
#include <tuple>

Engine::Bullet::IrrlichtPhysicsDebugDrawer::IrrlichtPhysicsDebugDrawer( std::shared_ptr<irr::IrrlichtDevice> device )
	: debugMode(btIDebugDraw::DBG_NoDebug)
{
	driver = device->getVideoDriver();
	logger = device->getLogger();
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::drawLine( const btVector3& from,const btVector3& to,const btVector3& color )
{
	debugLines.push_back(SDebugLine(transformBulletVector(from)*10, transformBulletVector(to)*10, transformBulletColor(color).toSColor()));
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::drawContactPoint( const btVector3& PointOnB,const btVector3& normalOnB,btScalar distance,int lifeTime,const btVector3& color )
{
	//throw std::exception("The method or operation is not implemented.");
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::reportErrorWarning( const char* warningString )
{
	logger->log(warningString);
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::draw3dText( const btVector3& location, const char* textString )
{
	//TODO: add default font
	//sceneManager->addTextSceneNode(nullptr, irr::core::stringw(textString).c_str());
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::setDebugMode( int debugMode )
{
	this->debugMode = debugMode;
}

int Engine::Bullet::IrrlichtPhysicsDebugDrawer::getDebugMode() const
{
	return debugMode;
}

void Engine::Bullet::IrrlichtPhysicsDebugDrawer::drawDebugData()
{
	irr::video::SMaterial lineMaterial;
	lineMaterial.Lighting = false;
	lineMaterial.Thickness = 1;
	driver->setMaterial(lineMaterial);
	driver->setTransform(irr::video::ETS_WORLD, irr::core::IdentityMatrix);

	for (auto& line : debugLines) {
		driver->draw3DLine(line.from, line.to, line.color);
	}

	debugLines.clear();
}

Engine::Bullet::IrrlichtPhysicsDebugDrawer::SDebugLine::SDebugLine( irr::core::vector3df from, irr::core::vector3df to, irr::video::SColor color )
	: from(from)
	, to(to)
	, color(color)
{
}