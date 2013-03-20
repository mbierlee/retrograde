#pragma once

#include "Engine/Framework/IEntityComponent.h"

#include <vector>

namespace Engine { namespace Base {
	class BaseEntityComponent
		: public Engine::Framework::IEntityComponent
		, public std::enable_shared_from_this<Engine::Base::BaseEntityComponent>
	{
	private:
		std::vector<std::shared_ptr<Engine::Framework::IEntityComponent>> notificationSubscribers;

	protected:
		void notifyAll();
		bool initialized;

	public:
		BaseEntityComponent();

		virtual void subscribeNotifications(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent);
		virtual void unsubscribeNotifications(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent);
		virtual void handleNotification(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent);
		virtual void handleEvent( Engine::Framework::IEvent& event, Engine::Framework::IEntity* entity, void* source );
		virtual void cleanup( Engine::Framework::IEntity* entity );
		virtual bool isInitialized() const;
	};
}}