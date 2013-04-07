#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <vector3d.h>

namespace Engine { namespace EntityComponents {
	class CameraTargetEntityComponent
		: public Engine::Base::BaseEntityComponent
	{
	private:
		irr::core::vector3df targetPosition;

	public:
		CameraTargetEntityComponent(const irr::core::vector3df& targetPosition = irr::core::vector3df());

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);

		void setTargetPosition(const irr::core::vector3df& position);
		const irr::core::vector3df& getTargetPosition() const;
	};
}}