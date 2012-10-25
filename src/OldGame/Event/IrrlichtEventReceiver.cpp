#include "IrrlichtEventReceiver.h"

#include "Game/Event/GameEvent.h"

Game::Event::IrrlichtEventReceiver::IrrlichtEventReceiver(irr::IrrlichtDevice* device, Framework::IGameEventManager* eventManager) 
	: device(device)
	, eventManager(eventManager)
	, movedMouse(false)
	, localPlayerId(0)
{
	for (irr::u32 i = 0; i < irr::KEY_KEY_CODES_COUNT; i++) {
		keyIsDown[i] = false;
	}

	device->getCursorControl()->setPosition(irr::core::vector2df(0.5, 0.5));
}


Game::Event::IrrlichtEventReceiver::~IrrlichtEventReceiver(void)
{
}

bool Game::Event::IrrlichtEventReceiver::OnEvent( const irr::SEvent& event )
{
	//TODO: mapping
	if (event.EventType == irr::EET_KEY_INPUT_EVENT) {
		if (event.KeyInput.PressedDown && !keyIsDown[event.KeyInput.Key]) {
			switch(event.KeyInput.Key) {
			case irr::KEY_KEY_W:
				eventManager->postEvent(GameEvent(EGET_WALK_FORWARD, localPlayerId));
				break;
			case irr::KEY_KEY_S:
				eventManager->postEvent(GameEvent(EGET_WALK_BACKWARD, localPlayerId));
				break;
			case irr::KEY_KEY_A:
				eventManager->postEvent(GameEvent(EGET_STRAFE_LEFT, localPlayerId));
				break;
			case irr::KEY_KEY_D:
				eventManager->postEvent(GameEvent(EGET_STRAFE_RIGHT, localPlayerId));
				break;
			case irr::KEY_ESCAPE:
				eventManager->postEvent(GameEvent(EGET_QUIT_GAME));
				break;
			case irr::KEY_LEFT:
				{			
					eventManager->postEvent(GameEvent(EGET_SWITCH_KEYBOARDLOOK, localPlayerId));
					//GameEvent turnLeftEvent(EGET_TURN_LEFT, localPlayerId);
					//turnLeftEvent.turnLookEventData.magnitude = 1.f;
					TurnGameEvent turnLeftEvent(TurnGameEvent::ETGED_LEFT, 1.f, localPlayerId);
					eventManager->postEvent(turnLeftEvent);
					break;
				}				
			case irr::KEY_RIGHT:
				{			
					eventManager->postEvent(GameEvent(EGET_SWITCH_KEYBOARDLOOK, localPlayerId));
					//GameEvent turnRightEvent(EGET_TURN_RIGHT, localPlayerId);
					//turnRightEvent.turnLookEventData.magnitude = 1.f;
					TurnGameEvent turnRightEvent(TurnGameEvent::ETGED_RIGHT, 1.f, localPlayerId);
					eventManager->postEvent(turnRightEvent);
					break;
				}	
			case irr::KEY_UP:
				{			
					eventManager->postEvent(GameEvent(EGET_SWITCH_KEYBOARDLOOK, localPlayerId));
					//GameEvent lookUpEvent(EGET_LOOK_UP, localPlayerId);
					//lookUpEvent.turnLookEventData.magnitude = 1.f;
					LookGameEvent lookUpEvent(LookGameEvent::ELGED_UP, 1.f, localPlayerId);
					eventManager->postEvent(lookUpEvent);
					break;
				}				
			case irr::KEY_DOWN:
				{			
					eventManager->postEvent(GameEvent(EGET_SWITCH_KEYBOARDLOOK, localPlayerId));
					//GameEvent lookDownEvent(EGET_LOOK_DOWN, localPlayerId);
					//lookDownEvent.turnLookEventData.magnitude = 1.f;
					LookGameEvent lookDownEvent(LookGameEvent::ELGED_DOWN, 1.f, localPlayerId);
					eventManager->postEvent(lookDownEvent);
					break;
				}
			case irr::KEY_SPACE:
				eventManager->postEvent(GameEvent(EGET_JUMP, localPlayerId));
				break;
			case irr::KEY_LCONTROL:
				eventManager->postEvent(GameEvent(EGET_CRAWL, localPlayerId));
				break;
			}
		} else if (!event.KeyInput.PressedDown && keyIsDown[event.KeyInput.Key]) {
			switch(event.KeyInput.Key) {
			case irr::KEY_KEY_W:
				eventManager->postEvent(GameEvent(EGET_STOP_WALK_FORWARD, localPlayerId));
				break;
			case irr::KEY_KEY_S:
				eventManager->postEvent(GameEvent(EGET_STOP_WALK_BACKWARD, localPlayerId));
				break;
			case irr::KEY_KEY_A:
				eventManager->postEvent(GameEvent(EGET_STOP_STRAFE_LEFT, localPlayerId));
				break;
			case irr::KEY_KEY_D:
				eventManager->postEvent(GameEvent(EGET_STOP_STRAFE_RIGHT, localPlayerId));
				break;
			case irr::KEY_LEFT:
				eventManager->postEvent(GameEvent(EGET_STOP_TURN_LEFT, localPlayerId));
				break;
			case irr::KEY_RIGHT:
				eventManager->postEvent(GameEvent(EGET_STOP_TURN_RIGHT, localPlayerId));
				break;
			case irr::KEY_UP:
				eventManager->postEvent(GameEvent(EGET_STOP_LOOK_UP, localPlayerId));
				break;
			case irr::KEY_DOWN:
				eventManager->postEvent(GameEvent(EGET_STOP_LOOK_DOWN, localPlayerId));
				break;
			case irr::KEY_SPACE:
				eventManager->postEvent(GameEvent(EGET_STOP_JUMP, localPlayerId));
				break;
			case irr::KEY_LCONTROL:
				eventManager->postEvent(GameEvent(EGET_STAND, localPlayerId));
				break;
			}
		}
		
		keyIsDown[event.KeyInput.Key] = event.KeyInput.PressedDown;

		if (!keyIsDown[irr::KEY_KEY_W] && !keyIsDown[irr::KEY_KEY_S] && !keyIsDown[irr::KEY_KEY_A] && !keyIsDown[irr::KEY_KEY_D]) {
			eventManager->postEvent(GameEvent(EGET_WALK_STOP, localPlayerId));
		}          
	}

	return false;
}

void Game::Event::IrrlichtEventReceiver::handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject )
{
	Game::Event::GameEvent& gameEvent = static_cast<Game::Event::GameEvent&>(event);

	switch(gameEvent.type) {
	case Game::Event::EGET_PLAYER_SET_LOCAL_ID:
		localPlayerId = gameEvent.targetEntityId;
		break;
	}
}
