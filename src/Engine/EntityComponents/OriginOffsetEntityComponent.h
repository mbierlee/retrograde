#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <vector3d.h>

namespace Engine { namespace EntityComponents {

	class OriginOffsetEntityComponent 
		: public Engine::Base::BaseEntityComponent
	{	
	private:
		irr::core::vector3df origin;

	public:
		OriginOffsetEntityComponent(const irr::core::vector3df& origin);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		void setOrigin(const irr::core::vector3df& origin);
		const irr::core::vector3df& getOrigin() const;

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);
	};

}}