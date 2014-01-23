#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <ILogger.h>
#include <irrString.h>

#include <cstdarg>

namespace Engine { namespace EntityComponents {
	class IrrlichtLoggerEntityComponent
		: public Engine::Base::BaseEntityComponent
	{
	private:
		irr::ILogger* logger;

	public:
		IrrlichtLoggerEntityComponent(irr::ILogger* logger);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);

		void log(const wchar_t* text, irr::ELOG_LEVEL logLevel = irr::ELL_INFORMATION);
		void log(const irr::c8* text, irr::ELOG_LEVEL logLevel = irr::ELL_INFORMATION);
	};
}}