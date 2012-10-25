#include "Game/Network/Protocol.h"

bool Game::Network::isAllowedClientEvent( Game::Event::GameEventType gameEventType )
{
	switch (gameEventType)
	{
	case Game::Event::EGET_WALK_FORWARD:		
	case Game::Event::EGET_WALK_BACKWARD:
	case Game::Event::EGET_STOP_WALK_FORWARD:
	case Game::Event::EGET_STOP_WALK_BACKWARD:
	case Game::Event::EGET_STRAFE_LEFT:
	case Game::Event::EGET_STRAFE_RIGHT:
	case Game::Event::EGET_STOP_STRAFE_LEFT:
	case Game::Event::EGET_STOP_STRAFE_RIGHT:
	//case Game::Event::EGET_TURN_LEFT:
	//case Game::Event::EGET_TURN_RIGHT:
	case Game::Event::EGET_TURN:	
	case Game::Event::EGET_STOP_TURN_LEFT:
	case Game::Event::EGET_STOP_TURN_RIGHT:
	case Game::Event::EGET_STOP_TURN:
	case Game::Event::EGET_WALK_STOP:
	//case Game::Event::EGET_LOOK_UP:
	//case Game::Event::EGET_LOOK_DOWN:
	case Game::Event::EGET_LOOK:
	case Game::Event::EGET_STOP_LOOK_UP:
	case Game::Event::EGET_STOP_LOOK_DOWN:
	case Game::Event::EGET_STOP_LOOK:
	case Game::Event::EGET_JUMP:
	case Game::Event::EGET_STOP_JUMP:
	case Game::Event::EGET_CRAWL:
	case Game::Event::EGET_STAND:
	case Game::Event::EGET_SWITCH_MOUSELOOK:
	case Game::Event::EGET_SWITCH_KEYBOARDLOOK:
		return true;
	default:
		return false;
	}
}

Game::Network::IdentPacketData::IdentPacketData() 
	: PacketData(ENE_PLAYER_IDENT)
{
	for (int i = 0; i < PLAYER_NAME_SIZE; i++) {
		playerName[i] = L'\0';
	}
}

Game::Network::PlayerRemoveData::PlayerRemoveData() 
	: PacketData(ENE_REMOVE_PLAYER)
	, playerNumber(0)
{
}

Game::Network::PlayerAddData::PlayerAddData() 
	: PacketData(ENE_ADD_PLAYER)
	, playerNumber(0)
	, localPlayer(false)
{
}

Game::Network::PacketData::PacketData( NetEventType eventType ) 
	:eventType(eventType)
{
}
