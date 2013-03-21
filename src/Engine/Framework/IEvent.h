#pragma once

#include <irrString.h>

namespace Engine { namespace Framework {
	class IEvent {
	public:
		virtual ~IEvent() {}
		virtual const irr::core::stringc& getName() const =0;
	};
}}