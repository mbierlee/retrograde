#pragma once

#include "Engine/Framework/IEntityComponent.h"

namespace Engine { namespace EntityComponents {

	class CollisionMaskEntityComponent 
		: public Engine::Framework::IEntityComponent
	{	
	private:
		irr::s16 mask;

	public:
		CollisionMaskEntityComponent(irr::s16 mask);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		irr::s16 getMask() const;

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);
	};

}}