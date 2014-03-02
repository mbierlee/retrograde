#pragma once

#include "Engine/Framework/IGame.h"
#include "Engine/Framework/IEntityManager.h"
#include "Engine/Framework/IEventManager.h"
#include "Engine/Framework/IEntityFactoryService.h"
#include "Engine/Framework/IInputManager.h"

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
		std::shared_ptr<Engine::Framework::IEntityManager> entityManager;
		std::shared_ptr<Engine::Framework::IEventManager> eventManager;
		std::shared_ptr<Engine::Framework::IEntityFactoryService> factoryManager;
		std::shared_ptr<Engine::Framework::IInputManager> inputManager;
		irr::u32 lastFrameTime, frameTime, deltaTime;

	public:
		BaseGame(std::shared_ptr<irr::IrrlichtDevice> device
			, std::shared_ptr<Engine::Framework::IEntityManager> entityManager
			, std::shared_ptr<Engine::Framework::IEventManager> eventManager
			, std::shared_ptr<Engine::Framework::IEntityFactoryService> factoryManager
			, std::shared_ptr<Engine::Framework::IInputManager> inputManager);

		virtual ~BaseGame();

		virtual bool exitRequested();
		virtual void requestExit();
		virtual void update();
		virtual void initialize();
	};
}}
