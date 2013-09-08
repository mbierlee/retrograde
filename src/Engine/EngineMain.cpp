#include "EngineMain.h"

#include "Engine/Framework/IGame.h"

int Engine::engineMain(std::shared_ptr<Hypodermic::IContainer> (*dependencyConfigFunc)(irr::SIrrlichtCreationParameters&))
{
	std::printf("Retrograde Test Game\nCopyright 2013 Lostmoment Games\n\nRetroGrade Engine version 0.1-indev\n\n");

	irr::SIrrlichtCreationParameters deviceParams;
	deviceParams.AntiAlias = 32U;
	deviceParams.Bits = 32U;
	deviceParams.Doublebuffer = true;
	deviceParams.DriverType = irr::video::EDT_OPENGL;
	deviceParams.Fullscreen = false;
	deviceParams.Vsync = true;
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
	if (!game) {
		return 1;
	}

	game->initialize();

	while(device->run() && !game->exitRequested()) {
		game->update();

		if (device->isWindowActive()) {
			game->draw();
		} else {
			device->yield();
		}
	}

	return 0;
}