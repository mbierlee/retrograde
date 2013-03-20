#pragma once

#include "Engine/Framework/IEventManager.h"

#include <list>

namespace Engine {
	class EventManager
		: public Engine::Framework::IEventManager
	{
	private:
		std::list<std::shared_ptr<Engine::Framework::IEventObserver>> observers;

	public:
		virtual void postEvent( Engine::Framework::IEvent& event, void* source );
		virtual void registerObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer );
		virtual void unregisterObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer );
		virtual bool hasObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer );
		virtual void clearObservers();
	};
}