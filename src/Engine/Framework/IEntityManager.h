#pragma once

#include "Engine/Framework/IEntity.h"

#include "irrTypes.h"
#include "irrString.h"

namespace Engine { namespace Framework {

	class IEntityManager {
	public:
		virtual ~IEntityManager() {};

		virtual void addEntity(std::shared_ptr<Engine::Framework::IEntity> entity) =0;
		virtual void removeEntity(std::shared_ptr<Engine::Framework::IEntity> entity) =0;
		virtual void removeEntity(irr::u32 entityId) =0;
		virtual void clearEntities() =0;
		virtual std::shared_ptr<Engine::Framework::IEntity> getEntity(irr::u32 entityId) =0;
		virtual std::shared_ptr<Engine::Framework::IEntity> getEntity(irr::core::stringc entityType) =0;
		virtual irr::u32 entityCount() =0;
		
		virtual void updateEntities(irr::u32 frameTime, irr::u32 lastFrameTime) =0;
	};

}}