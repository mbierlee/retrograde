#pragma once

#include "Engine/Framework/IEventManager.h"

#include "IEventReceiver.h"

namespace Game {
	class IrrEventReceiver
		: public irr::IEventReceiver
	{
	private:
		Engine::Framework::IEventManager* eventManager;

	public:
		IrrEventReceiver(Engine::Framework::IEventManager* eventManager); //TODO: Pass shared ptr instead

		virtual bool OnEvent( const irr::SEvent& event );
	};
}