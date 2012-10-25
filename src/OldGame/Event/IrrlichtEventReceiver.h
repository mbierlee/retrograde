#pragma once

#include "Framework/IGameEventManager.h"
#include "Framework/IGameEventObserver.h"

#include "IEventReceiver.h"
#include "IrrlichtDevice.h"

namespace Game { namespace Event {

class IrrlichtEventReceiver :
	public irr::IEventReceiver,
	public Framework::IGameEventObserver
{
private:
	irr::IrrlichtDevice* device;
	Framework::IGameEventManager* eventManager;

	bool keyIsDown[irr::KEY_KEY_CODES_COUNT];
	bool movedMouse;
	irr::u32 localPlayerId;

public:
	IrrlichtEventReceiver(irr::IrrlichtDevice* device, Framework::IGameEventManager* eventManager);
	~IrrlichtEventReceiver(void);

	virtual bool OnEvent( const irr::SEvent& event );

	virtual void handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject );

};

}}