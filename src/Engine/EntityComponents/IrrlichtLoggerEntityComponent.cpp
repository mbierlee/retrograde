#include "IrrlichtLoggerEntityComponent.h"

Engine::EntityComponents::IrrlichtLoggerEntityComponent::IrrlichtLoggerEntityComponent( irr::ILogger* logger )
	: logger(logger)
{
}

const irr::core::stringc Engine::EntityComponents::IrrlichtLoggerEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::IrrlichtLoggerEntityComponent::getFamilyType() const
{
	return familyType();
}

void Engine::EntityComponents::IrrlichtLoggerEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
}

const irr::core::stringc Engine::EntityComponents::IrrlichtLoggerEntityComponent::componentType()
{
	return "IrrlichtLoggerEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::IrrlichtLoggerEntityComponent::familyType()
{
	return "IrrlichtLoggerEntityComponent";
}

void Engine::EntityComponents::IrrlichtLoggerEntityComponent::log( const wchar_t* text, irr::ELOG_LEVEL logLevel /*= irr::ELL_INFORMATION*/ )
{
	if (logger)
		logger->log(text, logLevel);
}

void Engine::EntityComponents::IrrlichtLoggerEntityComponent::log( const irr::c8* text, irr::ELOG_LEVEL logLevel /*= irr::ELL_INFORMATION*/ )
{
	if (logger)
		logger->log(text, logLevel);
}