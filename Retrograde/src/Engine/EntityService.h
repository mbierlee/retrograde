#pragma once

#include "Engine/Framework/IEntityService.h"

#include <list>
#include <vector>

namespace Engine {
	class EntityService
		: public Engine::Framework::IEntityService
	{
	private:
		std::list<std::shared_ptr<Engine::Framework::IEntity>> entities;
		irr::u32 nextAllocatableId;
		std::vector<irr::u32> recycledIds;

	public:
		EntityService();

		virtual void addEntity( std::shared_ptr<Engine::Framework::IEntity> entity );
		virtual void removeEntity( std::shared_ptr<Engine::Framework::IEntity> entity );
		virtual void removeEntity( irr::u32 entityId );
		virtual void clearEntities();
		virtual irr::u32 entityCount();
		virtual std::shared_ptr<Engine::Framework::IEntity> getEntity( irr::u32 entityId );
		virtual std::shared_ptr<Engine::Framework::IEntity> getEntity( irr::core::stringc entityType );

		virtual void updateEntities( irr::u32 frameTime, irr::u32 lastFrameTime );
	};
}