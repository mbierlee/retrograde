#pragma once

#include "Engine/Framework/IEntityComponent.h"

namespace Engine { namespace EntityComponents {

	class CollisionGroupEntityComponent 
		: public Engine::Framework::IEntityComponent
	{	
	private:
		irr::s16 group;

	public:
		CollisionGroupEntityComponent(irr::s16 group);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		irr::s16 getGroup() const;

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);
	};

}}