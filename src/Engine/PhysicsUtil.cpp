#include "PhysicsUtil.h"

btVector3 Engine::transformIrrVector(const irr::core::vector3df& vector)
{
	return btVector3(vector.X, vector.Y, vector.Z);
}

irr::core::vector3df Engine::transformBulletVector(const btVector3& vector) 
{
	return irr::core::vector3df(vector.getX(), vector.getY(), vector.getZ());
}

irr::video::SColorf Engine::transformBulletColor(const btVector3& color)
{
	return irr::video::SColorf(color.getX(), color.getY(), color.getZ());
}