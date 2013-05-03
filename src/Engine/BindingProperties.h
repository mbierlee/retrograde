#pragma once

#include <irrString.h>

namespace Engine {
	struct BindingProperties {
	public:
		BindingProperties(const irr::core::stringc& eventName, bool isInverted = false);

		irr::core::stringc EventName;
		bool IsInverted;
	};
}