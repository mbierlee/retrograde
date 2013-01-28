#pragma once

#include "Engine/Framework/IEntityComponent.h"

#include "vector3d.h"

namespace Engine { namespace EntityComponents {

	class RotationEntityComponent 
		: public Engine::Framework::IEntityComponent
	{
	private:
		irr::core::vector3df rotation;

	public:
		RotationEntityComponent(irr::core::vector3df& rotation = irr::core::vector3df(0));

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime );

		const irr::core::vector3df& getEulerRotation() const;
		void setEulerRotation(const irr::core::vector3df& rotation);
	};

}}