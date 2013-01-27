#pragma once

#include "irrString.h"
#include "IEntity.h"

namespace Engine { namespace Framework {

	class IEntityFactory {
	public:
		virtual ~IEntityFactory() {};
				
		virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType) =0;
		virtual void clearPool() =0;
	};

}}
