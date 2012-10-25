#pragma once

#include "irrTypes.h"

namespace Engine { namespace Framework {

	class IEvent {
	public:
		virtual ~IEvent() {}

		virtual irr::u32 getType() const =0;
	};

}}