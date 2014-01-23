#pragma once

#include "Engine/Framework/IEventObserver.h"
#include "Engine/Framework/IEvent.h"

#include <memory>

namespace Engine { namespace Framework {
	class IEventManager {
	public:
		virtual ~IEventManager() {}

		virtual void postEvent(const Engine::Framework::IEvent& event, void* source) =0;

		virtual void registerObserver(std::shared_ptr<Engine::Framework::IEventObserver> observer) =0;
		virtual void unregisterObserver(std::shared_ptr<Engine::Framework::IEventObserver> observer) =0;
		virtual bool hasObserver( std::shared_ptr<Engine::Framework::IEventObserver> observer ) =0;
		virtual void clearObservers() =0;
	};
}}