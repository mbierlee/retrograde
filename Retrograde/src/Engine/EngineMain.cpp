#include "EngineMain.h"

#include "Engine/Framework/IGame.h"
#include "Engine/EngineCompileConfig.h"

#include <boost/format.hpp>

int Engine::engineMain(std::shared_ptr<Hypodermic::IContainer> (*dependencyConfigFunc)(irr::SIrrlichtCreationParameters&),
		irr::core::stringw gameName) {
	std::wcout
			<< boost::wformat(
					L"%s\nCopyright %s Lostmoment\n\nRetroGrade Engine version %s\n\n") % gameName.c_str() % RETROGRADE_COPYRIGHT_YEAR % RETROGRADE_VERSION_STRING;

	irr::SIrrlichtCreationParameters deviceParams;
	deviceParams.AntiAlias = 32U;
	deviceParams.Bits = 32U;
	deviceParams.Doublebuffer = true;
	deviceParams.DriverType = irr::video::EDT_OPENGL;
	deviceParams.Fullscreen = false;
	deviceParams.Vsync = true;
	deviceParams.WindowSize = irr::core::dimension2du(1280, 720);
	deviceParams.HandleSRGB = false;
	deviceParams.Stencilbuffer = true;
	// TODO: config-based log levels
	deviceParams.LoggingLevel = irr::ELL_INFORMATION;

	auto typeContainer = dependencyConfigFunc(deviceParams);
	std::shared_ptr<irr::IrrlichtDevice> device = typeContainer->resolve<irr::IrrlichtDevice>();

	if (!device) {
		return 1; //TODO: debug log
	}

	device->setWindowCaption(gameName.c_str());

	auto game = typeContainer->resolve<Engine::Framework::IGame>();
	if (!game) {
		return 1; // TODO: debug log
	}

	game->initialize();

	while (device->run() && !game->exitRequested()) {
		game->update();

		if (device->isWindowActive()) {
			game->draw();
		} else {
			device->yield();
		}
	}

	return 0;
}
