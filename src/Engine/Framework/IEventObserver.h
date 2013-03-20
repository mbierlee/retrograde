#pragma once

#include "Engine/Framework/IEvent.h"

namespace Engine { namespace Framework {
	class IEventObserver {
	public:
		virtual ~IEventObserver() {}

		virtual void handleEvent(Engine::Framework::IEvent& event, void* source) =0;
	};
}}