#include "EngineException.h"

namespace Engine {
namespace Base {

EngineException::EngineException() {
}

EngineException::EngineException(irr::core::stringc message) {
	this->message = message;
}

EngineException::~EngineException() {
}

const char* EngineException::what() const _GLIBCXX_USE_NOEXCEPT {
	return message.c_str();
}

}
}
