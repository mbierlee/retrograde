#include "GameEventManager.h"

//TODO: move implementations to common base

Core::GameEventManager::GameEventManager(void)
{    
}


Core::GameEventManager::~GameEventManager(void)
{
	observers.clear();
}

void Core::GameEventManager::attach( Framework::IGameEventObserver* observer )
{
	for(unsigned int i = 0; i < observers.size(); i++) {
		if (observers[i] == observer) return;
	}

	observers.push_back(observer);
}

void Core::GameEventManager::detach( Framework::IGameEventObserver* observer )
{
	for (unsigned int i = 0; i < observers.size(); i++) 
	{
		if (observers[i] == observer) {
			observers.erase(observers.begin()+i);
			return;
		}
	}
}

void Core::GameEventManager::postEvent( Framework::IGameEvent& event, void* sourceObject /*= nullptr */ )
{
	for (unsigned int i = 0; i < observers.size(); i++) {
		observers[i]->handleGameEvent(event, this, sourceObject);
	}
}
