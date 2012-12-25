#pragma once

#include <btBulletDynamicsCommon.h>
#include <vector3d.h>
#include <SColor.h>

namespace Engine {

	btVector3 transformIrrVector(const irr::core::vector3df& vector);
	irr::core::vector3df transformBulletVector(const btVector3& vector);

	irr::video::SColorf transformBulletColor(const btVector3& color);
}