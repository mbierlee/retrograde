#pragma once

#include "Engine/Framework/IEntityComponent.h"

namespace Game { namespace Test {

	class TestComponent 
		: public Engine::Framework::IEntityComponent
	{
	public:
		TestComponent();

		static irr::core::stringc componentFamilyType();
		static irr::core::stringc componentType();

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		virtual void update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime ) ;
	};


}}