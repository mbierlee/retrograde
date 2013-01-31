#include "BaseEntityComponent.h"


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
	std::vector<std::shared_ptr<Engine::Framework::IEntityComponent>>::iterator it;
	for (it = notificationSubscribers.begin(); it != notificationSubscribers.end(); it++) {
		(*it)->handleNotification(shared_from_this());
	}
}
