#pragma once

#include <memory>

#include <Hypodermic/ContainerBuilder.h>

#include <irrlicht.h>

namespace Engine {
	int engineMain( std::shared_ptr<Hypodermic::IContainer> (*dependencyConfigFunc)(irr::SIrrlichtCreationParameters&), irr::core::stringw gameName = "Unnamed Game" );
}
