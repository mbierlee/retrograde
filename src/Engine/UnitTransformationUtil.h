#pragma once

#include <Bullet/LinearMath/btVector3.h>
#include <Bullet/LinearMath/btQuaternion.h>
#include <vector3d.h>
#include <quaternion.h>
#include <SColor.h>

namespace Engine {

	btVector3 transformIrrVector(const irr::core::vector3df& vector);
	irr::core::vector3df transformBulletVector(const btVector3& vector);

	btQuaternion transformIrrQuaternion(const irr::core::quaternion& quaternion);
	irr::core::quaternion transformBulletQuaternion(const btQuaternion& quaternion);

	irr::core::vector3df vecRadToDeg(const irr::core::vector3df& vector);
	irr::core::vector3df vecDegToRad(const irr::core::vector3df& vector);

	irr::video::SColorf transformBulletColor(const btVector3& color);
}