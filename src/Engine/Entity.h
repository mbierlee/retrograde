#pragma once

#include "Engine/Framework/IEntity.h"
#include "Engine/Framework/IEntityComponent.h"
#include "Engine/Framework/IEventObserver.h"

#include "irrString.h"

#include <map>
#include <list>
#include <memory>
#include <vector>

namespace Engine {

	class Entity
		: public Engine::Framework::IEntity
		, public Engine::Framework::IEventObserver
	{
	private:
		int entityId;
		std::map<irr::core::stringc, std::shared_ptr<Engine::Framework::IEntityComponent>> components;
		std::list<irr::core::stringc> componentRemovalSchedule;
		bool componentRemovalLocked;
		irr::core::stringc entityType, entityName;
		std::vector<std::shared_ptr<Engine::Framework::IEntityComponent>> eventSubscribers;

		void removeScheduledComponents();

	public:
		Entity(const irr::core::stringc typeName = "Undefined");

		virtual irr::u32 getId() const;	
		virtual void setId( const int entityId );

		virtual const irr::core::stringc& getType() const;
		virtual void setType( const irr::core::stringc& typeName );

		virtual void addComponent( std::shared_ptr<Engine::Framework::IEntityComponent> component );
		virtual std::shared_ptr<Engine::Framework::IEntityComponent> getComponent( const irr::core::stringc familyType );
		virtual void removeComponent( const irr::core::stringc familyType );
		virtual void clearComponents();
		virtual void update(irr::u32 frameTime, irr::u32 lastFrameTime);
		virtual bool hasComponent( const irr::core::stringc familyType );

		virtual void handleEvent( Engine::Framework::IEvent& event, void* source );
		virtual void subscribeToEvents( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent );

		virtual const irr::core::stringc& getName() const;

		virtual void setName( const irr::core::stringc& name );

	};

}