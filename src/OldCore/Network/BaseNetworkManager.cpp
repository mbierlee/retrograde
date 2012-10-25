#include "BaseNetworkManager.h"

#include "irrString.h"

Core::Network::BaseNetworkManager::BaseNetworkManager( Framework::IGameEventManager* eventManager, irr::ILogger* logger )
	: eventManager(eventManager)
	, logger(logger)
	, initialized(false)
	, host(nullptr)
{
}


Core::Network::BaseNetworkManager::~BaseNetworkManager(void)
{
	if (initialized) {
		if (host) {
			enet_host_destroy(host);
			host = nullptr;
		}

		enet_deinitialize();
	}
}

void Core::Network::BaseNetworkManager::setEventManager( Framework::IGameEventManager* manager )
{
	this->eventManager = manager;
}

bool Core::Network::BaseNetworkManager::initialize()
{
	int initResult = enet_initialize();
	if (initResult != 0 && logger) {
		irr::core::stringw resultLog(L"ENet failed to initialize. Totally unhelpful init result code: ");
		resultLog.append(irr::core::stringw(initResult));		
		log(resultLog.c_str(), irr::ELL_ERROR);
	}

	initialized = initResult == 0 ? true : false;
	return initialized;
}

bool Core::Network::BaseNetworkManager::isInitialized()
{
	return initialized;
}

void Core::Network::BaseNetworkManager::log( const wchar_t* text, irr::ELOG_LEVEL level /*= irr::ELL_INFORMATION*/ )
{
	if (logger)
		logger->log(text, level);
}
