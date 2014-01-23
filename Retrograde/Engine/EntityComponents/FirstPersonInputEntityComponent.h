#pragma once

#include "Engine/Base/BaseEntityComponent.h"
#include "Engine/EntityComponents/RigidBodyEntityComponent.h"

#include <irrString.h>

namespace Engine { namespace EntityComponents {
	class FirstPersonInputEntityComponent
		: public Engine::Base::BaseEntityComponent
	{
	private:
		bool subscribedToEvents;
		irr::core::stringc moveForwardEvent, moveBackwardEvent, moveLeftEvent, moveRightEvent, turnLeftEvent, turnRightEvent;
		irr::f32 forwardMagnitude, backwardsMagnitude, leftMagnitude, rightMagnitude, turnLeftMagnitude, turnRightMagnitude;
		bool previouslyMoving;

	public:
		FirstPersonInputEntityComponent(irr::core::stringc moveForwardEvent, irr::core::stringc moveBackwardEvent,
			irr::core::stringc moveLeftEvent, irr::core::stringc moveRightEvent,
			irr::core::stringc turnLeftEvent, irr::core::stringc turnRightEvent);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);

		virtual void handleEvent( const Engine::Framework::IEvent& event, Engine::Framework::IEntity* entity, void* source );
	};
}}