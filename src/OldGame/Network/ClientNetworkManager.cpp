#include "ClientNetworkManager.h"

#include "Game/Event/GameEvent.h"

#include "irrString.h"

#include <string.h>

Game::Network::ClientNetworkManager::ClientNetworkManager( Framework::IGameEventManager* gameEventManager /*= nullptr*/, irr::ILogger* logger /*= nullptr*/ )
	: Core::Network::BaseNetworkManager(gameEventManager, logger)
	, connected(false)
	, serverPeer(nullptr)
{
}

Game::Network::ClientNetworkManager::~ClientNetworkManager( void )
{
	disconnect();
}

void Game::Network::ClientNetworkManager::service()
{	
	if (isInitialized() && connected && host) {
		ENetEvent netEvent;

		while (enet_host_service(host, &netEvent, 0) > 0)
		{
			switch (netEvent.type)
			{
			case ENET_EVENT_TYPE_CONNECT:
				log(L"Successfully connected to server.");
				break;
			case ENET_EVENT_TYPE_DISCONNECT:
				log(L"Disconnected from server.");
				netEvent.peer->data = nullptr;
				connected = false;
				break;
			case ENET_EVENT_TYPE_RECEIVE:
				{
					if (netEvent.peer == serverPeer) {
						if (netEvent.channelID == 0)
							handleProtocolPacket(netEvent.packet);

						if (netEvent.channelID == 1)
							handleGameEventPacket(netEvent.packet);
					}
					enet_packet_destroy(netEvent.packet);
				}
				break;
			}
		}
	}
}

void Game::Network::ClientNetworkManager::setupHost()
{
	if (!isInitialized()) {
		log(L"Cannot start hosting, ENet did not properly initialize.", irr::ELL_WARNING);
		return;
	}

	host = enet_host_create(nullptr, 1, 2, 0, 0);

	if (!host) {
		log(L"Unable to create host, creating client failed.", irr::ELL_ERROR);
		return;
	}
		
	log(L"Client started");
}

bool Game::Network::ClientNetworkManager::connect()
{
	ENetAddress address;
	ENetEvent netEvent;
		
	enet_address_set_host(&address, "localhost");
	address.port = 28015;

	serverPeer = enet_host_connect(host, &address, 2, NET_PROTOCOL_VERSION);

	//TODO: let service() handle this? that way it won't block.
	if (enet_host_service(host, &netEvent, 5000) > 0
		&& netEvent.type == ENET_EVENT_TYPE_CONNECT) {
			log(L"Successfully connected to server.");
			connected = true;
	} else {
		log(L"Unable to connect to server.");
		enet_peer_reset(serverPeer);
		connected = false;
	}
		
	return connected;
}

void Game::Network::ClientNetworkManager::disconnect()
{
	if (isInitialized() && connected && serverPeer) {
		enet_peer_disconnect(serverPeer, 0);

		ENetEvent netEvent;
		while (enet_host_service(host, &netEvent, 3000) > 0)
		{
			switch (netEvent.type)
			{
			case ENET_EVENT_TYPE_RECEIVE:
				enet_packet_destroy(netEvent.packet);
				break;
			case ENET_EVENT_TYPE_DISCONNECT:
				log(L"Successfully Disconnected.");
				connected = false;
				serverPeer = nullptr;
				return;
			}
		}

		enet_peer_reset(serverPeer);
		connected = false;
		serverPeer = nullptr;
		log(L"Disconnect: no response from server. Forced disconnection.");
	}
}

void Game::Network::ClientNetworkManager::identPlayer()
{
	if (serverPeer) {
		IdentPacketData data;
		wcscpy_s(data.playerName, sizeof(L"Test Dude"), L"Test Dude");

		sendProtocolData(data, sizeof(IdentPacketData));
	}
}

void Game::Network::ClientNetworkManager::handleProtocolPacket( ENetPacket * packet )
{
	//Always check packet sizes!

	if (!packet->data)
		return;
	
	if (packet->dataLength < sizeof(PacketData))
		return;

	PacketData* data = (PacketData*)packet->data;
	switch (data->eventType)
	{
	case ENE_CLIENT_ACCEPTED:
		identPlayer();
		break;
	case ENE_ADD_PLAYER:
		{
			if (packet->dataLength == sizeof(PlayerAddData)) {
				PlayerAddData* playerAddData = static_cast<PlayerAddData*>(data);
				if (playerAddData->localPlayer) {
					eventManager->postEvent(Game::Event::GameEvent(Game::Event::EGET_PLAYER_SET_LOCAL_ID, playerAddData->playerNumber), this);				
				}

				Game::Event::GameEvent addPlayerEvent(Game::Event::EGET_ADD_PLAYER);
				addPlayerEvent.targetEntityId = playerAddData->playerNumber;
				eventManager->postEvent(addPlayerEvent, this);
			}
		}
		break;
	//TODO: handle remove player
	}
}

void Game::Network::ClientNetworkManager::handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject )
{
	if (sourceObject == this)
		return;

	Game::Event::GameEvent& gameEvent = static_cast<Game::Event::GameEvent&>(event);

	if (isInitialized() && connected && Game::Network::isAllowedClientEvent(gameEvent.type)) {
		sendGameEventData(gameEvent);
	}
}

void Game::Network::ClientNetworkManager::sendProtocolData( IdentPacketData& data, int packetSize )
{
	ENetPacket* packet = enet_packet_create(&data, packetSize, ENET_PACKET_FLAG_RELIABLE);		
	enet_peer_send(serverPeer, 0, packet);
}

void Game::Network::ClientNetworkManager::sendGameEventData( Framework::IGameEvent& event )
{
	Game::Event::GameEvent& gameEvent = static_cast<Game::Event::GameEvent&>(event);
	ENetPacket* packet = enet_packet_create(&gameEvent, Game::Event::eventDataSize(gameEvent.type), ENET_PACKET_FLAG_RELIABLE);
	enet_peer_send(serverPeer, 1, packet);
}

void Game::Network::ClientNetworkManager::handleGameEventPacket( ENetPacket * packet )
{
	if (!packet->data)
		return;

	if (packet->dataLength < sizeof(Game::Event::GameEvent))
		return;
	
	Game::Event::GameEvent* gameEvent = (Game::Event::GameEvent*)packet->data;

	if (packet->dataLength != Game::Event::eventDataSize(gameEvent->type))
		return;

	if (!Game::Network::isAllowedClientEvent(gameEvent->type)) // TODO: and not allowed server event
		return;

	//TODO: cast to appropriate type

	eventManager->postEvent(*gameEvent, this);
}
