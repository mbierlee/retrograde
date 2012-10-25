#include "TestComponent.h"

#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/IrrlichtLoggerEntityComponent.h"

Game::Test::TestComponent::TestComponent() 
{	
}

const irr::core::stringc Game::Test::TestComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Game::Test::TestComponent::getFamilyType() const
{
	return componentFamilyType();
}

void Game::Test::TestComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	auto positionComponent = 
		std::static_pointer_cast<Engine::EntityComponents::PositionEntityComponent>(
			entity->getComponent(Engine::EntityComponents::PositionEntityComponent::familyType()));

	if (positionComponent) {
		positionComponent->setPosition(irr::core::vector3df(1, 2, 3));

		auto logger = 
			std::static_pointer_cast<Engine::EntityComponents::IrrlichtLoggerEntityComponent>(
				entity->getComponent(Engine::EntityComponents::IrrlichtLoggerEntityComponent::familyType()));

		if (logger) {
			logger->log("Position set, I'm out!");
		}

		entity->removeComponent(getFamilyType());
	}
}

irr::core::stringc Game::Test::TestComponent::componentFamilyType()
{
	return componentType();
}

irr::core::stringc Game::Test::TestComponent::componentType()
{
	return irr::core::stringc("TestComponent");
}
