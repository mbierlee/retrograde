#include "IrrEventReceiver.h"

#include "Engine/Event.h"
#include "Game/EventConstants.h"

bool Game::IrrEventReceiver::OnEvent( const irr::SEvent& event )
{
	if (eventManager) {
		switch(event.EventType) {
		case irr::EET_KEY_INPUT_EVENT:
			{
				switch (event.KeyInput.Key)
				{
				case irr::KEY_ESCAPE:
					eventManager->postEvent(Engine::Event(EV_QUIT), this);
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