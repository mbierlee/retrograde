#include "UnitTransformationUtil.h"

btVector3 Engine::transformIrrVector(const irr::core::vector3df& vector) {
	return btVector3(vector.X, vector.Y, vector.Z);
}

irr::core::vector3df Engine::transformBulletVector(const btVector3& vector) {
	return irr::core::vector3df(vector.getX(), vector.getY(), vector.getZ());
}

irr::video::SColorf Engine::transformBulletColor(const btVector3& color) {
	return irr::video::SColorf(color.getX(), color.getY(), color.getZ());
}

btQuaternion Engine::transformIrrQuaternion(const irr::core::quaternion& quaternion) {
	return btQuaternion(quaternion.X, quaternion.Y, quaternion.Z, quaternion.W);
}

irr::core::quaternion Engine::transformBulletQuaternion(const btQuaternion& quaternion) {
	return irr::core::quaternion(quaternion.getX(), quaternion.getY(), quaternion.getZ(), quaternion.getW());
}

irr::core::vector3df Engine::vecRadToDeg(const irr::core::vector3df& vector) {
	return irr::core::vector3df(irr::core::radToDeg(vector.X), irr::core::radToDeg(vector.Y), irr::core::radToDeg(vector.Z));
}

irr::core::vector3df Engine::vecDegToRad(const irr::core::vector3df& vector) {
	return irr::core::vector3df(irr::core::degToRad(vector.X), irr::core::degToRad(vector.Y), irr::core::degToRad(vector.Z));
}

irr::core::vector3df Engine::makePhysicsToWorldsizeVector(irr::f32 x, irr::f32 y, irr::f32 z) {
	return irr::core::vector3df(x * Engine::visualWorldSize, y * Engine::visualWorldSize, z * Engine::visualWorldSize);
}

irr::core::vector3df Engine::makePhysicsToWorldsizeVector(const irr::core::vector3df& vector) {
	return irr::core::vector3df(vector * Engine::visualWorldSize);
}

irr::core::vector3df Engine::makePhysicsToWorldsizeVector(const btVector3& vector) {
	irr::core::vector3df transformedVector = Engine::transformBulletVector(vector);
	return Engine::makePhysicsToWorldsizeVector(transformedVector);
}
