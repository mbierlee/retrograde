#pragma once

#include "Engine/Framework/IEventService.h"

#include <list>

namespace Engine {
	class EventService
		: public Engine::Framework::IEventService
	{
	private:
		std::list<std::shared_ptr<Engine::Framework::IEventObserver>> observers;

	public:
		virtual void postEvent( const Engine::Framework::IEvent& event, void* source );
		virtual void registerObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer );
		virtual void unregisterObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer );
		virtual bool hasObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer );
		virtual void clearObservers();
	};
}