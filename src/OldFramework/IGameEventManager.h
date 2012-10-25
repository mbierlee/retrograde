#pragma once

#include "IGameEventObserver.h"
#include "IGameEvent.h"

namespace Framework {

    class IGameEventManager {
    public:
        virtual void attach(Framework::IGameEventObserver* observer) =0;
        virtual void detach(Framework::IGameEventObserver* observer) =0;
        virtual void postEvent(Framework::IGameEvent& event, void* sourceObject = nullptr) =0;

        virtual ~IGameEventManager() {};
    };

}