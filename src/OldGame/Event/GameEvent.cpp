#include "Game/Event/GameEvent.h"

Game::Event::GameEvent::GameEvent( GameEventType type, irr::u32 targetEntityId /*= 0*/, irr::u32 sourceEntityId /*= 0*/ )
	: type(type)
	, targetEntityId(targetEntityId)
	, sourceEntityId(sourceEntityId)
{
}

Game::Event::GameEvent::~GameEvent(void)
{
}

Game::Event::TurnGameEvent::TurnGameEvent(Direction direction, irr::f32 magnitude, irr::u32 targetEntityId, irr::u32 sourceEntityId)
	: Game::Event::GameEvent(EGET_TURN, targetEntityId, sourceEntityId)
	, direction(direction)
	, magnitude(magnitude)
{
}

Game::Event::LookGameEvent::LookGameEvent( Direction direction, irr::f32 magnitude, irr::u32 targetEntityId /*= 0*/, irr::u32 sourceEntityId /*= 0*/ )
	: Game::Event::GameEvent(EGET_LOOK, targetEntityId, sourceEntityId)
	, direction(direction)
	, magnitude(magnitude)
{
}

size_t Game::Event::eventDataSize( GameEventType eventType )
{
	switch(eventType) {
	case EGET_LOOK:
		return sizeof(LookGameEvent);
	case EGET_TURN:
		return sizeof(TurnGameEvent);
	default:
		return sizeof(GameEvent);
	}
}

Game::Event::ChangeAttributeGameEvent::ChangeAttributeGameEvent( MutationType mutationType, AttributeType attributeType, irr::u32 amount, irr::u32 targetEntityId, irr::u32 sourceEntityId )
	: Game::Event::GameEvent(EGET_CHANGE_ATTRIBUTE, targetEntityId, sourceEntityId)
	, mutationType(mutationType)
	, attributeType(attributeType)
	, amount(amount)
{
}
