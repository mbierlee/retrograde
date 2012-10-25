#pragma once

#include "Core/Network/BaseNetworkManager.h"
#include "Framework/IGameEventManager.h"
#include "Game/Network/Protocol.h"

namespace Game { namespace Network {

class ClientNetworkManager :
	public Core::Network::BaseNetworkManager
{
private:
	bool connected;
	ENetPeer* serverPeer;

	void identPlayer();

	void sendProtocolData( IdentPacketData& data, int packetSize );

	void handleProtocolPacket( ENetPacket * packet);

public:
	ClientNetworkManager(Framework::IGameEventManager* gameEventManager = nullptr, irr::ILogger* logger = nullptr);
	~ClientNetworkManager(void);

	virtual void service();
	virtual void setupHost();

	bool connect(/*TODO: connection parameters*/);
	void disconnect();	

	virtual void handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject );
	void sendGameEventData( Framework::IGameEvent& event );
	void handleGameEventPacket( ENetPacket * packet);
};

}}