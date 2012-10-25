#pragma once

#include "Framework/IGameEventManager.h"

namespace Framework {

	class INetworkManager {
	public:
		virtual void setEventManager(Framework::IGameEventManager* manager) =0;

		virtual bool initialize() =0;
		virtual void setupHost() =0;
		virtual void service() =0;
		

		virtual bool isInitialized() =0;

		virtual ~INetworkManager(){};

	};

}