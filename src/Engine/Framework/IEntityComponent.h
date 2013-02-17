#pragma once

/**
 * Gets a component of certain type from the entity.
 */
#define COMPONENT(_COMPTYPE) std::static_pointer_cast<Engine::EntityComponents::_COMPTYPE>(entity->getComponent(Engine::EntityComponents::_COMPTYPE::familyType()))

#include "Engine/Framework/IEntity.h"
#include "Engine/Framework/IEvent.h"

#include <memory>

#include "irrString.h"

namespace Engine { namespace Framework {
		
	class IEntityComponent {
	public:
		virtual ~IEntityComponent() {};

		virtual const irr::core::stringc getComponentType() const =0;
		virtual const irr::core::stringc getFamilyType() const =0;

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) =0;
		virtual void cleanup(Engine::Framework::IEntity* entity) =0;

		virtual void subscribeNotifications(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent) =0;
		virtual void unsubscribeNotifications(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent) =0;
		virtual void handleNotification(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent) =0;
		virtual void handleEvent(Engine::Framework::IEvent& event, Engine::Framework::IEntity* entity, void* source) =0;
	};

}}