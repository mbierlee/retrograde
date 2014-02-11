#pragma once

#include "Engine/Base/EngineException.h"

#include <irrString.h>

namespace Engine {
namespace Base {

class NotImplementedException: public Engine::Base::EngineException {
public:
	NotImplementedException();
	NotImplementedException(irr::core::stringc message);
	virtual ~NotImplementedException();
};

}
}
