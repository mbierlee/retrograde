#include "DependencyConfig.h"

#include "Game/SandboxGame.h"
#include "Game/GameEntityFactory.h"

#include "Breakout/BreakoutGame.h"

#include <Engine/PhysicsService.h>
#include <Engine/EntityService.h>
#include <Engine/EventService.h>
#include <Engine/EntityFactoryService.h>
#include <Engine/Bullet/IrrlichtPhysicsDebugDrawer.h>
#include <Engine/EntityFactories/DebugEntityFactory.h>
#include <Engine/EntityFactories/DefaultEntityFactory.h>
#include <Engine/InputService.h>

#include <Hypodermic/ContainerBuilder.h>
#include <Hypodermic/Helpers.h>

std::shared_ptr<Hypodermic::IContainer> SetupDependencies(irr::SIrrlichtCreationParameters& deviceParams)
{
	Hypodermic::ContainerBuilder builder;

	//Setup Irrlicht
	auto irrlichtDevice = std::shared_ptr<irr::IrrlichtDevice>(irr::createDeviceEx(deviceParams));
	builder.registerInstance(irrlichtDevice);

	//Setup Physics Debug Drawer
	builder.autowireType<Engine::Bullet::IrrlichtPhysicsDebugDrawer>()->as<btIDebugDraw>();

	//Setup Physics Service
	builder.autowireType<Engine::PhysicsService>()->as<Engine::Framework::IPhysicsService>()->singleInstance();

	//Setup Entity Service
	builder.registerType<Engine::EntityService>()->as<Engine::Framework::IEntityService>()->singleInstance();

	//Setup Event Service
	builder.registerType<Engine::EventService>()->as<Engine::Framework::IEventService>()->singleInstance();

	//Setup Factory Service
	builder.registerType<Engine::EntityFactoryService>()->as<Engine::Framework::IEntityFactoryService>()->singleInstance();

	//Setup default entity factory
	builder.autowireType<Engine::EntityFactories::DefaultEntityFactory>();

	//Setup debug entity factory
	builder.autowireType<Engine::EntityFactories::DebugEntityFactory>();

	//Setup game entity factory
	builder.autowireType<Game::GameEntityFactory>();

	//Setup Input Service
	builder.autowireType<Engine::InputService>()->as<Engine::Framework::IInputService>()->singleInstance();

	//Setup Game
//	builder.autowireType<Game::SandboxGame>()->as<Engine::Framework::IGame>()->singleInstance();
	builder.autowireType<Breakout::BreakoutGame>()->as<Engine::Framework::IGame>()->singleInstance();

	std::shared_ptr<Hypodermic::IContainer> typeContainer = builder.build();

	//Run-time dependencies
	std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService = typeContainer->resolve<Engine::Framework::IEntityFactoryService>();
	entityFactoryService->registerFactory(typeContainer->resolve<Engine::EntityFactories::DefaultEntityFactory>());
	entityFactoryService->registerFactory(typeContainer->resolve<Engine::EntityFactories::DebugEntityFactory>());
	entityFactoryService->registerFactory(typeContainer->resolve<Game::GameEntityFactory>());

	return typeContainer;
}
