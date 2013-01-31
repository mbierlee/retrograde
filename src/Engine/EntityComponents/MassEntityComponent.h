#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <irrTypes.h>

namespace Engine { namespace EntityComponents {

	class MassEntityComponent 
		: public Engine::Base::BaseEntityComponent
	{	
	private:
		irr::f32 mass;

	public:
		MassEntityComponent(irr::f32 mass = 0.);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);

		irr::f32 getMass() const;
		void setMass(irr::f32 mass);
	};

}}