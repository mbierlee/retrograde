#include "EventService.h"

void Engine::EventService::postEvent( const Engine::Framework::IEvent& event, void* source )
{
	for (auto& observer : observers) {
		observer->handleEvent(event, source);
	}
}

void Engine::EventService::registerObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer )
{
	observers.push_back(observer);
}

void Engine::EventService::unregisterObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer )
{
	observers.remove(observer);
}

void Engine::EventService::clearObservers()
{
	observers.clear();
}

bool Engine::EventService::hasObserver( std::shared_ptr<Engine::Framework::IEventObserver> expectedObserver )
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