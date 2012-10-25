#include "EventManager.h"


void Engine::EventManager::postEvent( Engine::Framework::IEvent& event, void* source )
{
	std::list<std::shared_ptr<Engine::Framework::IEventObserver>>::iterator it;
	for (it = observers.begin(); it != observers.end(); it++)
	{
		std::shared_ptr<Engine::Framework::IEventObserver> observer = *it;
		observer->handleEvent(event, source);
	}
}

void Engine::EventManager::registerObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer )
{
	observers.push_back(observer);
}

void Engine::EventManager::unregisterObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer )
{
	observers.remove(observer);
}

void Engine::EventManager::clearObservers()
{
	observers.clear();
}

bool Engine::EventManager::hasObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer )
{
	bool observerFound = false;

	std::list<std::shared_ptr<Engine::Framework::IEventObserver>>::iterator it;
	for (it = observers.begin(); it != observers.end(); it++)
	{
		if (*it == observer) {
			observerFound = true;
			break;
		}
	}

	return observerFound;
}
