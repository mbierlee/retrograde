#include "EngineMain.h"

#include "Engine/Framework/IGame.h"

//#define CL_UPDRATE 16u
#define CL_UPDRATE 0

int Engine::engineMain(std::shared_ptr<Hypodermic::IContainer> (*dependencyConfigFunc)(irr::SIrrlichtCreationParameters&))
{
	std::printf("Project Phantasy Shooter\n0.1.0 Alpha\nSHAREWARE EDITION\nCopyright 2012 Lostmoment Games\n\nRetroGrade Engine version 0.1\nLoading WIN/4GW...Done!\n\n");

	irr::SIrrlichtCreationParameters deviceParams;
	deviceParams.AntiAlias = 32U;
	deviceParams.Bits = 32U;
	deviceParams.Doublebuffer = true;
	deviceParams.DriverType = irr::video::EDT_OPENGL;   
	deviceParams.Fullscreen = false;
	deviceParams.Vsync = false;
	deviceParams.WindowSize = irr::core::dimension2du(1280,720);
	deviceParams.HandleSRGB = false;
	deviceParams.Stencilbuffer = true;
	// TODO: config-based log levels
	deviceParams.LoggingLevel = irr::ELL_INFORMATION;

	auto typeContainer = dependencyConfigFunc(deviceParams);
	std::shared_ptr<irr::IrrlichtDevice> device = typeContainer->resolve<irr::IrrlichtDevice>();

	if (!device) 
		return 1;

	auto game = typeContainer->resolve<Engine::Framework::IGame>();

	int lastTime = 0;

	//TODO: build in config-based frame limit for rendering.
	//TODO: on-screen fps and ups

	irr::u32 updateTime = CL_UPDRATE; // Force immediate update upon start
	irr::u32 updateRate = deviceParams.Vsync ? 0 : CL_UPDRATE;

	bool firstRun = true;

	while(device->run() && !game->exitRequested()) {
		//TODO: let game change updaterate

		if (firstRun) {
			lastTime = device->getTimer()->getTime();
			game->initialize();
			firstRun = false;
		}

		if (updateRate > 0) {
			irr::u32 currentTime = device->getTimer()->getTime();
			irr::u32 deltaTime = currentTime - lastTime;						
			updateTime += deltaTime;

			if (updateTime >= updateRate) {			
				game->update();
				updateTime = updateTime % updateRate;
			}

			lastTime = currentTime;
		} else {
			game->update();
		}

#if defined(DEBUG_HOST) || defined(DEBUG_CLIENT)
		game->draw();
#else
		if (device->isWindowActive()) {			 
			game->draw();
		} else {
			device->yield();
		}
#endif
	}

	return 0;
}
