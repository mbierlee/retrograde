#include "BaseEntityComponent.h"

Engine::Base::BaseEntityComponent::BaseEntityComponent()
	: initialized(false)
{
}

void Engine::Base::BaseEntityComponent::subscribeNotifications( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent )
{
	if (entityComponent) {
		notificationSubscribers.push_back(entityComponent);
	}
}

void Engine::Base::BaseEntityComponent::unsubscribeNotifications( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent )
{
	if (entityComponent) {
		std::vector<std::shared_ptr<Engine::Framework::IEntityComponent>>::iterator it;
		for (it = notificationSubscribers.begin(); it != notificationSubscribers.end(); it++) {
			if (*it == entityComponent) {
				notificationSubscribers.erase(it);
			}
		}
	}
}

void Engine::Base::BaseEntityComponent::handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent )
{
	// Do nothing
}

void Engine::Base::BaseEntityComponent::notifyAll()
{
	for (auto& subscriber : notificationSubscribers) {
		subscriber->handleNotification(shared_from_this());
	}
}

void Engine::Base::BaseEntityComponent::handleEvent( Engine::Framework::IEvent& event, Engine::Framework::IEntity* entity, void* source )
{
	// Don't do jack
}

void Engine::Base::BaseEntityComponent::cleanup( Engine::Framework::IEntity* entity )
{
	// Crispy clean
}

bool Engine::Base::BaseEntityComponent::isInitialized() const
{
	return initialized;
}