#include "IrrEventReceiver.h"

#include "Engine/Event.h"
#include "Game/Event/Events.h"

bool Game::IrrEventReceiver::OnEvent( const irr::SEvent& event )
{
	if (eventManager) {
		switch(event.EventType) {
		case irr::EET_KEY_INPUT_EVENT:
			{
				switch (event.KeyInput.Key)
				{
				case irr::KEY_ESCAPE:
					eventManager->postEvent(Engine::Event(static_cast<irr::s32>(Game::Event::Events::QUIT_GAME_EVENT)), this);
					break;
				}
			}
			break;
		}
	}

	return false;
}

Game::IrrEventReceiver::IrrEventReceiver( Engine::Framework::IEventManager* eventManager )
	: eventManager(eventManager)
{
}