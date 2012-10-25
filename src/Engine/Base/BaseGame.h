#pragma once

#include "Engine/Framework/IGame.h"
#include "Engine/Framework/IEntityManager.h"
#include "Engine/Framework/IEventManager.h"

#include "irrlicht.h"
#include "IVideoDriver.h"
#include "ISceneManager.h"

namespace Engine { namespace Base {

	class BaseGame 
		: public Engine::Framework::IGame
	{
	private:
		bool isExitRequested;

	protected:
		irr::IrrlichtDevice* device;
		irr::video::IVideoDriver* driver;
		irr::scene::ISceneManager* sceneManager;
		Engine::Framework::IEntityManager* entityManager;
		Engine::Framework::IEventManager* eventManager;
		irr::u32 lastFrameTime;

	public:
		BaseGame(irr::IrrlichtDevice* device);
		virtual ~BaseGame();
			
		virtual bool exitRequested();
		virtual void requestExit();
		virtual void update();

	};

}}