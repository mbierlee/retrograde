#pragma once

#include "Framework/IGameEvent.h"

#include "coreutil.h"

namespace Game { namespace Event {

enum GameEventType {
	// Movement and view
	EGET_WALK_STOP,
	EGET_WALK_FORWARD, 
	EGET_WALK_BACKWARD,
	EGET_STOP_WALK_FORWARD,
	EGET_STOP_WALK_BACKWARD,
	EGET_STRAFE_LEFT,
	EGET_STRAFE_RIGHT,
	EGET_STOP_STRAFE_LEFT,
	EGET_STOP_STRAFE_RIGHT,
	//EGET_TURN_LEFT,
	//EGET_TURN_RIGHT,
	EGET_TURN,
	EGET_STOP_TURN_LEFT,
	EGET_STOP_TURN_RIGHT,
	EGET_STOP_TURN,
	//EGET_LOOK_UP,
	//EGET_LOOK_DOWN,
	EGET_LOOK,
	EGET_STOP_LOOK_UP,
	EGET_STOP_LOOK_DOWN,
	EGET_STOP_LOOK,
	EGET_JUMP,
	EGET_STOP_JUMP,
	EGET_CRAWL,
	EGET_STAND,

	// Look and turn modes
	EGET_SWITCH_MOUSELOOK,
	EGET_SWITCH_KEYBOARDLOOK,

	// Item pickup
	EGET_ITEM_PICKED_UP,
	EGET_CHANGE_ATTRIBUTE,
	
	// Networking related
	EGET_REGISTER_LOCAL_PLAYER,
	EGET_ADD_PLAYER,
	EGET_REMOVE_PLAYER,
	EGET_PLAYER_SET_LOCAL_ID,

	// Misc
	EGET_QUIT_GAME
};

class GameEvent :
	public Framework::IGameEvent
{
public:
	GameEvent(GameEventType type, irr::u32 targetEntityId = 0, irr::u32 sourceEntityId = 0);
	~GameEvent(void);

	GameEventType type;
	irr::u32 sourceEntityId;
	irr::u32 targetEntityId;
};

class TurnGameEvent 
	: public GameEvent
{
public:
	enum Direction
	{
		ETGED_LEFT,
		ETGED_RIGHT
	};

	TurnGameEvent(Direction direction, irr::f32 magnitude, irr::u32 targetEntityId = 0, irr::u32 sourceEntityId = 0);	

	irr::f32 magnitude;
	Direction direction;
};

class LookGameEvent 
	: public GameEvent
{
public:
	enum Direction
	{
		ELGED_UP,
		ELGED_DOWN
	};

	LookGameEvent(Direction direction, irr::f32 magnitude, irr::u32 targetEntityId = 0, irr::u32 sourceEntityId = 0);

	irr::f32 magnitude;
	Direction direction;
};

class ChangeAttributeGameEvent 
	: public GameEvent
{
public:
	enum AttributeType
	{
		ECAGEAT_JUMPS
	};

	enum MutationType
	{
		ECAGEMT_ADD,
		ECAGEMT_SET
	};

	ChangeAttributeGameEvent(MutationType mutationType, AttributeType attributeType, irr::u32 amount, irr::u32 targetEntityId = 0, irr::u32 sourceEntityId = 0);

	MutationType mutationType;
	AttributeType attributeType;
	irr::u32 amount;
};

size_t eventDataSize(GameEventType eventType);

}}