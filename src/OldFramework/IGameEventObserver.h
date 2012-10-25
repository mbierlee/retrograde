#pragma once

#include "IGameEvent.h"

namespace Framework {

	class IGameEventManager;

	class IGameEventObserver {
	public:
		virtual void handleGameEvent(Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject) =0;

		virtual ~IGameEventObserver() {};
	};

}