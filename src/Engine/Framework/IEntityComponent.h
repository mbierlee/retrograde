#pragma once

#include "Engine/Framework/IEntity.h"

#include <memory>

#include "irrString.h"

namespace Engine { namespace Framework {
		
	class IEntityComponent {
	public:
		virtual ~IEntityComponent() {};

		virtual const irr::core::stringc getComponentType() const =0;
		virtual const irr::core::stringc getFamilyType() const =0;

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) =0;
	};

}}