#include "DependencyConfig.h"

#include "Game/TestGame.h"
#include "Engine/PhysicsManager.h"
#include "Engine/EntityManager.h"
#include "Engine/EventManager.h"
#include "Engine/FactoryManager.h"
#include "Engine/Bullet/IrrlichtPhysicsDebugDrawer.h"
#include "Engine/EntityFactories/DebugEntityFactory.h"
#include "Engine/EntityFactories/DefaultEntityFactory.h"

#include <Hypodermic/ContainerBuilder.h>
#include <Hypodermic/Helpers.h>

std::shared_ptr<Hypodermic::IContainer> SetupDependencies(irr::SIrrlichtCreationParameters& deviceParams)
{
	Hypodermic::ContainerBuilder builder;

	//Setup Irrlicht
	auto irrlichtDevice = std::shared_ptr<irr::IrrlichtDevice>(irr::createDeviceEx(deviceParams));
	builder.registerInstance(irrlichtDevice);//->singleInstance();

	//Setup Physics Debug Drawer
	builder.registerType<Engine::Bullet::IrrlichtPhysicsDebugDrawer>(CREATE(new Engine::Bullet::IrrlichtPhysicsDebugDrawer(INJECT(irr::IrrlichtDevice))))->as<btIDebugDraw>();

	//Setup Physics Manager
	builder.registerType<Engine::PhysicsManager>(CREATE(new Engine::PhysicsManager(INJECT(btIDebugDraw))))->as<Engine::Framework::IPhysicsManager>()->singleInstance();

	//Setup Entity Manager
	builder.registerType<Engine::EntityManager>()->as<Engine::Framework::IEntityManager>()->singleInstance();

	//Setup Event Manager
	builder.registerType<Engine::EventManager>()->as<Engine::Framework::IEventManager>()->singleInstance();

	//Setup Factory Manager
	builder.registerType<Engine::FactoryManager>()->as<Engine::Framework::IFactoryManager>()->singleInstance();

	//Setup default entity factory
	builder.registerType<Engine::EntityFactories::DefaultEntityFactory>(CREATE(new Engine::EntityFactories::DefaultEntityFactory(INJECT(irr::IrrlichtDevice))));

	//Setup debug entity factory
	builder.registerType<Engine::EntityFactories::DebugEntityFactory>(CREATE(new Engine::EntityFactories::DebugEntityFactory(INJECT(irr::IrrlichtDevice), INJECT(Engine::Framework::IPhysicsManager))));

	//Setup Game
	builder.registerType<Game::TestGame>(CREATE(new Game::TestGame(
		INJECT(irr::IrrlichtDevice)
		, INJECT(Engine::Framework::IPhysicsManager)
		, INJECT(Engine::Framework::IEntityManager)
		, INJECT(Engine::Framework::IEventManager)
		, INJECT(Engine::Framework::IFactoryManager)
		)))->as<Engine::Framework::IGame>()->singleInstance();

	std::shared_ptr<Hypodermic::IContainer> typeContainer = builder.build();

	//Run-time dependencies
	std::shared_ptr<Engine::Framework::IFactoryManager> factoryManager = typeContainer->resolve<Engine::Framework::IFactoryManager>();
	factoryManager->registerFactory(typeContainer->resolve<Engine::EntityFactories::DefaultEntityFactory>());
	factoryManager->registerFactory(typeContainer->resolve<Engine::EntityFactories::DebugEntityFactory>());

	return typeContainer;
}