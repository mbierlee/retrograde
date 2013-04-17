#include "EventManager.h"

void Engine::EventManager::postEvent( const Engine::Framework::IEvent& event, void* source )
{
	for (auto& observer : observers) {
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

bool Engine::EventManager::hasObserver( std::shared_ptr<Engine::Framework::IEventObserver> expectedObserver )
{
	bool observerFound = false;

	for (auto& observer : observers) {
		if (observer == expectedObserver) {
			observerFound = true;
			break;
		}
	}

	return observerFound;
}