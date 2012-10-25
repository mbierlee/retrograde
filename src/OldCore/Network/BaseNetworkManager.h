#pragma once

#include "Framework/INetworkManager.h"
#include "Framework/IGameEventManager.h"

#include "ILogger.h"

#include "enet/enet.h"

namespace Core { namespace Network {

class BaseNetworkManager 
	: public Framework::INetworkManager
	, public Framework::IGameEventObserver
{
private:
	bool initialized;

protected:
	Framework::IGameEventManager* eventManager;	
	irr::ILogger* logger;
	ENetHost* host;

	void log(const wchar_t* text, irr::ELOG_LEVEL level = irr::ELL_INFORMATION);

public:
	BaseNetworkManager(Framework::IGameEventManager* eventManager = nullptr, irr::ILogger* logger = nullptr);
	~BaseNetworkManager(void);

	virtual void setEventManager( Framework::IGameEventManager* manager );

	virtual bool initialize();
	virtual bool isInitialized();

};

}}