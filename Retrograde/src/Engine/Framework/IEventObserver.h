#pragma once

#include "Engine/Framework/IEvent.h"

namespace Engine { namespace Framework {
	class IEventObserver {
	public:
		virtual ~IEventObserver() {}

		virtual void handleEvent(const Engine::Framework::IEvent& event, void* source) =0;
	};
}}