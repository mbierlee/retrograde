#pragma once

#include "Engine/Framework/IEntity.h"
#include "Engine/Framework/IEntityComponent.h"

#include "irrString.h"

#include <map>
#include <list>
#include <memory>

namespace Engine {

	class Entity
		: public Engine::Framework::IEntity		
	{
	private:
		int entityId;
		std::map<irr::core::stringc, std::shared_ptr<Engine::Framework::IEntityComponent>> components;
		std::list<irr::core::stringc> componentRemovalSchedule;
		bool componentRemovalLocked;
		irr::core::stringc entityType;

		void removeScheduledComponents();

	public:
		Entity(const irr::core::stringc typeName = "Undefined");

		virtual irr::u32 getId() const;	
		virtual void setId( const int entityId );

		virtual const irr::core::stringc getType() const;
		virtual void setType( const irr::core::stringc typeName );

		virtual void addComponent( std::shared_ptr<Engine::Framework::IEntityComponent> component );
		virtual std::shared_ptr<Engine::Framework::IEntityComponent> getComponent( const irr::core::stringc familyType );
		virtual void removeComponent( const irr::core::stringc familyType );
		virtual void clearComponents();
		virtual void update(irr::u32 frameTime, irr::u32 lastFrameTime);
		virtual bool hasComponent( const irr::core::stringc familyType );
	};

}