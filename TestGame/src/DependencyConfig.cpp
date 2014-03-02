#include "DependencyConfig.h"

#include "Game/TestGame.h"
#include "Game/GameEntityFactory.h"

#include <Engine/PhysicsService.h>
#include <Engine/EntityService.h>
#include <Engine/EventManager.h>
#include <Engine/EntityFactoryService.h>
#include <Engine/Bullet/IrrlichtPhysicsDebugDrawer.h>
#include <Engine/EntityFactories/DebugEntityFactory.h>
#include <Engine/EntityFactories/DefaultEntityFactory.h>
#include <Engine/InputManager.h>

#include <Hypodermic/ContainerBuilder.h>
#include <Hypodermic/Helpers.h>

std::shared_ptr<Hypodermic::IContainer> SetupDependencies(irr::SIrrlichtCreationParameters& deviceParams)
{
	Hypodermic::ContainerBuilder builder;

	//Setup Irrlicht
	auto irrlichtDevice = std::shared_ptr<irr::IrrlichtDevice>(irr::createDeviceEx(deviceParams));
	builder.registerInstance(irrlichtDevice);

	//Setup Physics Debug Drawer
	builder.registerType<Engine::Bullet::IrrlichtPhysicsDebugDrawer>(CREATE(new Engine::Bullet::IrrlichtPhysicsDebugDrawer(INJECT(irr::IrrlichtDevice))))->as<btIDebugDraw>();

	//Setup Physics Manager
	builder.registerType<Engine::PhysicsService>(CREATE(new Engine::PhysicsService(INJECT(btIDebugDraw))))->as<Engine::Framework::IPhysicsService>()->singleInstance();

	//Setup Entity Manager
	builder.registerType<Engine::EntityService>()->as<Engine::Framework::IEntityService>()->singleInstance();

	//Setup Event Manager
	builder.registerType<Engine::EventManager>()->as<Engine::Framework::IEventManager>()->singleInstance();

	//Setup Factory Manager
	builder.registerType<Engine::EntityFactoryService>()->as<Engine::Framework::IEntityFactoryService>()->singleInstance();

	//Setup default entity factory
	builder.registerType<Engine::EntityFactories::DefaultEntityFactory>(CREATE(new Engine::EntityFactories::DefaultEntityFactory(INJECT(irr::IrrlichtDevice))));

	//Setup debug entity factory
	builder.registerType<Engine::EntityFactories::DebugEntityFactory>(CREATE(new Engine::EntityFactories::DebugEntityFactory(INJECT(irr::IrrlichtDevice), INJECT(Engine::Framework::IPhysicsService))));

	//Setup game entity factory
	builder.registerType<Game::GameEntityFactory>(CREATE(new Game::GameEntityFactory(INJECT(irr::IrrlichtDevice), INJECT(Engine::Framework::IPhysicsService), INJECT(Engine::Framework::IEventManager))));

	//Setup Input Manager
	builder.registerType<Engine::InputManager>(CREATE(new Engine::InputManager(INJECT(irr::IrrlichtDevice), INJECT(Engine::Framework::IEventManager))))->as<Engine::Framework::IInputManager>()->singleInstance();

	//Setup Game
	builder.registerType<Game::TestGame>(CREATE(new Game::TestGame(
		INJECT(irr::IrrlichtDevice)
		, INJECT(Engine::Framework::IPhysicsService)
		, INJECT(Engine::Framework::IEntityService)
		, INJECT(Engine::Framework::IEventManager)
		, INJECT(Engine::Framework::IEntityFactoryService)
		, INJECT(Engine::Framework::IInputManager)
		)))->as<Engine::Framework::IGame>()->singleInstance();

	std::shared_ptr<Hypodermic::IContainer> typeContainer = builder.build();

	//Run-time dependencies
	std::shared_ptr<Engine::Framework::IEntityFactoryService> entityFactoryService = typeContainer->resolve<Engine::Framework::IEntityFactoryService>();
	entityFactoryService->registerFactory(typeContainer->resolve<Engine::EntityFactories::DefaultEntityFactory>());
	entityFactoryService->registerFactory(typeContainer->resolve<Engine::EntityFactories::DebugEntityFactory>());
	entityFactoryService->registerFactory(typeContainer->resolve<Game::GameEntityFactory>());

	return typeContainer;
}
