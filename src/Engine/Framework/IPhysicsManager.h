#pragma once

#include "vector3d.h"

namespace Engine { namespace Framework {

	class IPhysicsManager {
	public:
		virtual ~IPhysicsManager() {}

		virtual void initialize() =0;
		virtual void setGravity(const irr::core::vector3df& gravity) =0;
	};

}}