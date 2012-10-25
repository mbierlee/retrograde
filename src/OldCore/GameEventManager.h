#pragma once

#include "Framework/IGameEventManager.h"
#include "Framework/IGameEventObserver.h"

#include <vector>

namespace Core {

class GameEventManager :
    public Framework::IGameEventManager
{
private:
    std::vector<Framework::IGameEventObserver*> observers;

public:
    GameEventManager(void);
    ~GameEventManager(void);

    virtual void attach( Framework::IGameEventObserver* observer );

    virtual void detach( Framework::IGameEventObserver* observer );

	virtual void postEvent( Framework::IGameEvent& event, void* sourceObject = nullptr );

};

}