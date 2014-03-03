#pragma once

#include "Engine/Framework/IGame.h"
#include "Engine/Framework/IEntityService.h"
#include "Engine/Framework/IEventService.h"
#include "Engine/Framework/IEntityFactoryService.h"
#include "Engine/Framework/IInputService.h"

#include "irrlicht.h"
#include "IVideoDriver.h"
#include "ISceneManager.h"

#include <memory>

namespace Engine { namespace Base {
	class BaseGame
		: public Engine::Framework::IGame
	{
	private:
		bool isExitRequested;

	protected:
		std::shared_ptr<irr::IrrlichtDevice> device;
		irr::video::IVideoDriver* driver;
		irr::scene::ISceneManager* sceneManager;
		std::shared_ptr<Engine::Framework::IEntityService> entityService;
		std::shared_ptr<Engine::Framework::IEventService> eventService;
		std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService;
		std::shared_ptr<Engine::Framework::IInputService> inputService;
		irr::u32 lastFrameTime, frameTime, deltaTime;

	public:
		BaseGame(std::shared_ptr<irr::IrrlichtDevice> device
			, std::shared_ptr<Engine::Framework::IEntityService> entityService
			, std::shared_ptr<Engine::Framework::IEventService> eventService
			, std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService
			, std::shared_ptr<Engine::Framework::IInputService> inputService);

		virtual ~BaseGame();

		virtual bool exitRequested();
		virtual void requestExit();
		virtual void update();
		virtual void initialize();
	};
}}
