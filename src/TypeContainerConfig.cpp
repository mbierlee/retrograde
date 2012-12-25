#include "Engine/TypeContainerConfig.h"

#include <Hypodermic/ContainerBuilder.h>
#include <Hypodermic/Helpers.h>

#include "Game/TestGame.h"
#include "Engine/PhysicsManager.h"
#include "Engine/EntityManager.h"
#include "Engine/EventManager.h"
#include "Engine/DefaultEntityFactory.h"

std::shared_ptr<Hypodermic::IContainer> typeContainer;

void SetupTypeContainer(irr::SIrrlichtCreationParameters& deviceParams)
{
	Hypodermic::ContainerBuilder builder;

	//Setup Irrlicht
	auto irrlichtDevice = std::shared_ptr<irr::IrrlichtDevice>(irr::createDeviceEx(deviceParams));
	builder.registerInstance(irrlichtDevice)->singleInstance();

	//Setup Physics Manager
	builder.registerType<Engine::PhysicsManager>()->as<Engine::Framework::IPhysicsManager>()->singleInstance();

	//Setup Entity Manager
	builder.registerType<Engine::EntityManager>()->as<Engine::Framework::IEntityManager>()->singleInstance();

	//Setup Event Manager
	builder.registerType<Engine::EventManager>()->as<Engine::Framework::IEventManager>()->singleInstance();

	//Setup Entity Factory
	builder.registerType<Engine::DefaultEntityFactory>(CREATE(new Engine::DefaultEntityFactory(INJECT(irr::IrrlichtDevice))))->as<Engine::Framework::IEntityFactory>();

	//Setup Game
	builder.registerType<Game::TestGame>(CREATE(new Game::TestGame(
		INJECT(irr::IrrlichtDevice)
		, INJECT(Engine::Framework::IPhysicsManager)
		, INJECT(Engine::Framework::IEntityManager)
		, INJECT(Engine::Framework::IEventManager)
		, INJECT(Engine::Framework::IEntityFactory)
		)))->as<Engine::Framework::IGame>()->singleInstance();

	typeContainer = builder.build();
}
