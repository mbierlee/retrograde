#pragma once

#include "Game/Event/GameEvent.h"

#define NET_PROTOCOL_VERSION 1u

#define PLAYER_NAME_SIZE 32u

namespace Game { namespace Network {
		
	enum NetEventType // Don't use ENET_ prefix to not clash with ENet.
	{
		//Server to client events
		ENE_CLIENT_ACCEPTED,
		ENE_ADD_PLAYER,
		ENE_REMOVE_PLAYER,

		//Client to server events
		ENE_PLAYER_IDENT
	};
	
	enum DisconnectReason
	{
		EDR_REJECTED_INCOMPATIBLE_PROTOCOL,
		EDR_SERVER_SHUTDOWN
	};

	struct PacketData
	{
		PacketData(NetEventType eventType);
		NetEventType eventType;
	};

	struct PlayerAddData 
		: PacketData
	{
		PlayerAddData();;	

		irr::u32 playerNumber;
		bool localPlayer;
	};
	
	struct PlayerRemoveData
		: PacketData
	{
		PlayerRemoveData();
		irr::u32 playerNumber;
	};

	struct IdentPacketData
		: PacketData
	{
		IdentPacketData();
		wchar_t playerName[PLAYER_NAME_SIZE];
	};

	bool isAllowedClientEvent(Game::Event::GameEventType gameEventType);

}}