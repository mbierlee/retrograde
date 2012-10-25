#pragma once

#include "Core/Network/BaseNetworkManager.h"
#include "Framework/IGameEventManager.h"
#include "Game/Network/Protocol.h"
#include "Game/Event/GameEvent.h"

#include "irrString.h"

#include <memory>

#define MAX_PLAYERS 32

namespace Game { namespace Network {

class ServerNetworkManager :
	public Core::Network::BaseNetworkManager
{
private:
	struct PeerIdentity
	{
		PeerIdentity();

		irr::core::stringw playerName;
		irr::u32 playerNumber;
		ENetPeer* peer;
	};

	std::shared_ptr<PeerIdentity> players[MAX_PLAYERS]; // TODO: unrestrict
	irr::u32 playerCount;
	irr::u32 localPlayerId;

	bool registerPlayer( std::shared_ptr<PeerIdentity> peerIdentity );
	void addPlayerLocally( std::shared_ptr<PeerIdentity> peerIdentity );
	void broadcastGameEventData( Game::Event::GameEvent& gameEvent );
	void broadcastRemovePlayer( std::shared_ptr<PeerIdentity> peerIdentity );
	void handleGameEventPacket( ENetPacket* packet, ENetPeer* peer );
	void handleIdentPacket( PacketData* data, ENetPeer* peer );
	void handleProtocolPacket( ENetPacket * packet, ENetPeer * peer );
	void removePlayerLocally( std::shared_ptr<PeerIdentity> player );
	void sendGameEventData( Game::Event::GameEvent& gameEvent, ENetPeer* peer );
	void sendProtocolData( PacketData& data, int packetSize, ENetPeer* peer );
	void unregisterPlayer( std::shared_ptr<PeerIdentity> peerIdentity );

public:
	ServerNetworkManager(Framework::IGameEventManager* gameEventManager = nullptr, irr::ILogger* logger = nullptr);
	~ServerNetworkManager(void);

	virtual void service();
	virtual void setupHost();
	virtual void handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject );
};

}}