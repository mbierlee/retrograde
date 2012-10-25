#include "ServerNetworkManager.h"

#include "Game/Event/GameEvent.h"

#include "irrString.h"

#include "enet/enet.h"

#include <memory>

Game::Network::ServerNetworkManager::ServerNetworkManager( Framework::IGameEventManager* gameEventManager, irr::ILogger* logger )
	: Core::Network::BaseNetworkManager(gameEventManager, logger)
	, playerCount(0)
{	
}

Game::Network::ServerNetworkManager::~ServerNetworkManager( void )
{
	if (isInitialized() && host) {
		for (int i = 0; i < MAX_PLAYERS; i++) {
			std::shared_ptr<PeerIdentity> player = players[i];
			if (player && player->peer) {
				enet_peer_disconnect_now(player->peer, EDR_SERVER_SHUTDOWN);
			}
		}
	}
}

void Game::Network::ServerNetworkManager::service()
{
	if (isInitialized() && host) {
		ENetEvent netEvent;
		while(enet_host_service(host, &netEvent, 0) > 0) {
			switch(netEvent.type) {
			case ENET_EVENT_TYPE_CONNECT: 
				{
					if (netEvent.data != NET_PROTOCOL_VERSION) {
						enet_peer_disconnect(netEvent.peer, EDR_REJECTED_INCOMPATIBLE_PROTOCOL);
					} else {
						irr::core::stringw connectLog("Client connected from ");
						char* hostString = new char[32];
						enet_address_get_host_ip(&netEvent.peer->address, hostString, 32);
						connectLog.append(hostString);
						connectLog.append(':');
						connectLog.append(irr::core::stringw(netEvent.peer->address.port));
						log(connectLog.c_str());

						PacketData data(ENE_CLIENT_ACCEPTED);					
						sendProtocolData(data, sizeof(PacketData), netEvent.peer);
						//TODO: impose ident timeout
					}					
				}
				break;
			case  ENET_EVENT_TYPE_DISCONNECT:
				{
					irr::core::stringw disconnectLog("Client disconnected (");
					char* hostString = new char[32];
					enet_address_get_host_ip(&netEvent.peer->address, hostString, 32);
					disconnectLog.append(hostString);
					disconnectLog.append(':');
					disconnectLog.append(irr::core::stringw(netEvent.peer->address.port));
					disconnectLog.append(')');
					log(disconnectLog.c_str());

					if (netEvent.peer->data) { // Client is registered
						int playerNumber = (static_cast<PeerIdentity*>(netEvent.peer->data))->playerNumber;
						std::shared_ptr<PeerIdentity> peerIdentity = players[playerNumber-1];
						broadcastRemovePlayer(peerIdentity);
						unregisterPlayer(peerIdentity);
						netEvent.peer->data = nullptr;
					}
				}
				break;
			case ENET_EVENT_TYPE_RECEIVE:
				{
					if (netEvent.channelID == 0)
						handleProtocolPacket(netEvent.packet, netEvent.peer);

					if (netEvent.channelID == 1)
						handleGameEventPacket(netEvent.packet, netEvent.peer);

					enet_packet_destroy(netEvent.packet);
				}				
				break;
			}
		}
	}
}

void Game::Network::ServerNetworkManager::setupHost()
{
	if (!isInitialized()) {
		log(L"Cannot start hosting, ENet did not properly initialize.", irr::ELL_WARNING);
		return;
	}

	ENetAddress address;

	address.host = ENET_HOST_ANY;
	address.port = 28015;

	host = enet_host_create(&address, 32, 2, 0, 0);

	if (!host) {
		log(L"Unable to create host, creating server failed.", irr::ELL_ERROR);
		return;
	}

	irr::core::stringw successLog(L"Server started at port ");
	successLog.append(irr::core::stringw(address.port));
	log(successLog.c_str());
}

void Game::Network::ServerNetworkManager::handleProtocolPacket( ENetPacket* packet, ENetPeer* peer )
{
	//Always check packet sizes!

	if (!packet->data)
		return;	

	if (packet->dataLength < sizeof(PacketData)) 
		return;

	PacketData* data = (PacketData*)packet->data;
	switch (data->eventType)
	{
	case ENE_PLAYER_IDENT:
		{
			if (packet->dataLength == sizeof(IdentPacketData))
				handleIdentPacket(data, peer);
		}		
		break;
	}
}

bool Game::Network::ServerNetworkManager::registerPlayer( std::shared_ptr<PeerIdentity> peerIdentity )
{
	if (!peerIdentity)
		return false;

	for (int i = 0; i < MAX_PLAYERS; i++) {
		if (!players[i]) {
			players[i] = peerIdentity;
			playerCount++;
			peerIdentity->playerNumber = i+1;
			return true;
		}
	}

	irr::core::stringw registerErrorLog(L"Unable to register player ");
	registerErrorLog.append(peerIdentity->playerName);
	registerErrorLog.append(L", no slots available.");
	log(registerErrorLog.c_str(), irr::ELL_WARNING);
	return false;
}

void Game::Network::ServerNetworkManager::handleIdentPacket( PacketData* data, ENetPeer* peer )
{
	//TODO: prevent re-registration of the same peer

	IdentPacketData* identData = static_cast<IdentPacketData*>(data);

	std::shared_ptr<PeerIdentity> peerIdentity = std::make_shared<PeerIdentity>();			
	peerIdentity->playerName = irr::core::stringw(identData->playerName);
	peerIdentity->peer = peer;
	peer->data = peerIdentity.get();

	if (registerPlayer(peerIdentity)) {
		PlayerAddData newPlayerData;
		newPlayerData.playerNumber = peerIdentity->playerNumber;
		bool addLocally = false;
		for (int i = 0; i < MAX_PLAYERS; i++)
		{
			//TODO: sync player name
			//TODO: sync current player state
			if (players[i]) {
				newPlayerData.localPlayer = players[i]->playerNumber == peerIdentity->playerNumber;
				if (players[i]->peer) {
					sendProtocolData(newPlayerData, sizeof(PlayerAddData), players[i]->peer);
				} else {
					addLocally = true;
				}

				if (!newPlayerData.localPlayer) {
					PlayerAddData existingPlayerData;
					existingPlayerData.playerNumber = players[i]->playerNumber;
					existingPlayerData.localPlayer = false;
					sendProtocolData(existingPlayerData, sizeof(PlayerAddData), peer);
				}
			}
		}

		if (addLocally) addPlayerLocally(peerIdentity);	

		irr::core::stringw playerJoinLog("Player ");
		playerJoinLog.append(identData->playerName);
		playerJoinLog.append(" joined the game.");
		log(playerJoinLog.c_str());
	}	
}

void Game::Network::ServerNetworkManager::addPlayerLocally( std::shared_ptr<PeerIdentity> peerIdentity )
{
	Game::Event::GameEvent addPlayerEvent(Game::Event::EGET_ADD_PLAYER);
	addPlayerEvent.targetEntityId = peerIdentity->playerNumber;
	eventManager->postEvent(addPlayerEvent);
}

void Game::Network::ServerNetworkManager::sendProtocolData( PacketData& data, int packetSize, ENetPeer* peer )
{
	ENetPacket* packet = enet_packet_create(&data, packetSize, ENET_PACKET_FLAG_RELIABLE);
	enet_peer_send(peer, 0, packet);
}

void Game::Network::ServerNetworkManager::removePlayerLocally( std::shared_ptr<PeerIdentity> player )
{
	Game::Event::GameEvent removePlayerEvent(Game::Event::EGET_REMOVE_PLAYER);
	removePlayerEvent.targetEntityId = player->playerNumber;
	eventManager->postEvent(removePlayerEvent);
}

void Game::Network::ServerNetworkManager::sendGameEventData( Game::Event::GameEvent& gameEvent, ENetPeer* peer )
{
	ENetPacket* packet = enet_packet_create(&gameEvent, Game::Event::eventDataSize(gameEvent.type), ENET_PACKET_FLAG_RELIABLE);
	enet_peer_send(peer, 1, packet);
}

void Game::Network::ServerNetworkManager::handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject )
{
	if (sourceObject == this)
		return;

	Game::Event::GameEvent& gameEvent = static_cast<Game::Event::GameEvent&>(event);

	switch (gameEvent.type)
	{
	case Game::Event::EGET_REGISTER_LOCAL_PLAYER:
		{
			std::shared_ptr<PeerIdentity> peerIdentity = std::make_shared<PeerIdentity>();
			//TODO: set player name
			if (registerPlayer(peerIdentity)) {
				localPlayerId = peerIdentity->playerNumber;
				Game::Event::GameEvent setLocalIdEvent(Game::Event::EGET_PLAYER_SET_LOCAL_ID, peerIdentity->playerNumber);
				eventManager->postEvent(setLocalIdEvent);

				Game::Event::GameEvent addPlayerEvent(Game::Event::EGET_ADD_PLAYER);
				addPlayerEvent.targetEntityId = peerIdentity->playerNumber;
				eventManager->postEvent(addPlayerEvent);
			} else {
				log(L"Failed to add local player.", irr::ELL_WARNING);
			}
		}
		break;
	default:
		{
			if (Game::Network::isAllowedClientEvent(gameEvent.type)) { //TODO: or allowed server events
				broadcastGameEventData(gameEvent);
			}
		}
		break;
	}
}

void Game::Network::ServerNetworkManager::handleGameEventPacket( ENetPacket* packet, ENetPeer* peer )
{	
	if (packet->dataLength < sizeof(Game::Event::GameEvent))
		return;

	Game::Event::GameEvent* gameEvent = (Game::Event::GameEvent*)packet->data;

	if (packet->dataLength != Event::eventDataSize(gameEvent->type))
		return;

	if (!Game::Network::isAllowedClientEvent(static_cast<Game::Event::GameEventType>(gameEvent->type)))
		return;

	//TODO: prevent players from moving other players!

	bool postLocally = false;
	for (int i = 0; i < MAX_PLAYERS; i++) {
		std::shared_ptr<PeerIdentity> player = players[i];
		if (player) {
			if (player->peer && player->peer != peer) {
				sendGameEventData(*gameEvent, player->peer);
			} else {
				postLocally = true;
			}
		}
	}
	if (postLocally) eventManager->postEvent(*gameEvent, this);
}

void Game::Network::ServerNetworkManager::unregisterPlayer( std::shared_ptr<PeerIdentity> peerIdentity )
{
	peerIdentity.reset();
	playerCount--;
}

void Game::Network::ServerNetworkManager::broadcastRemovePlayer( std::shared_ptr<PeerIdentity> peerIdentity )
{
	PlayerRemoveData removeData;
	removeData.playerNumber = peerIdentity->playerNumber;
	bool removeLocally = false;
	for (int i = 0; i < MAX_PLAYERS; i++) {
		std::shared_ptr<PeerIdentity> player = players[i];
		if (player && player->playerNumber != peerIdentity->playerNumber) {
			if (player->peer) {
				sendProtocolData(removeData, sizeof(PlayerRemoveData), player->peer);
			} else {
				removeLocally = true;
			}
		}
	}
	if (removeLocally) removePlayerLocally(peerIdentity);
}

void Game::Network::ServerNetworkManager::broadcastGameEventData( Game::Event::GameEvent& gameEvent )
{
	for (int i = 0; i < MAX_PLAYERS; i++) {
		std::shared_ptr<PeerIdentity> player = players[i];
		if (player && player->peer) {
			sendGameEventData(gameEvent, player->peer);
		}
	}
}

Game::Network::ServerNetworkManager::PeerIdentity::PeerIdentity()
	: peer(nullptr)
	, playerNumber(0)
{
}
