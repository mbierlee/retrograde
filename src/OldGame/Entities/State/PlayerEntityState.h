#pragma once

#include "Game/Entities/State/EntityState.h"

#include "vector3d.h"

#define MOUSE_SPEED 220.f

namespace Game { namespace Entities { namespace State {

	struct PlayerEntityState
		: Game::Entities::State::EntityState
	{
		PlayerEntityState()
			: turnMagnitude(0.f)
			, lookMagnitude(0.f)
			, moveForward(false)
			, moveBackward(false)
			, strafeLeft(false)
			, strafeRight(false)    
			, turnLeft(false)
			, turnRight(false)
			, lookUp(false)
			, lookDown(false)
			, rotateSpeed(MOUSE_SPEED)
			, mouseLook(true)
			, jumpMagnitude(0)
			, doJump(false)
			, jumps(1)
			, crawl(false)
		{		
		}

		// Irrlicht Managed
		irr::core::vector3df position, rotation;

		//Custom
		irr::core::vector3df headRotation;
		irr::f32 jumpMagnitude;
		irr::u8 jumps;
		bool moveForward, moveBackward, strafeLeft,
			strafeRight, turnLeft, turnRight, lookUp, lookDown,
			doJump, crawl;
		irr::f32 turnMagnitude, lookMagnitude;
		irr::f32 rotateSpeed;
		bool mouseLook;
	};

}}}