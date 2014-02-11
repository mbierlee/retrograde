#pragma once

#include <exception>

#include <irrString.h>

namespace Engine {
namespace Base {

class EngineException: public std::exception {
private:
	irr::core::stringc message;

public:
	EngineException();
	EngineException(irr::core::stringc message);
	virtual ~EngineException();
	virtual const char* what() const _GLIBCXX_USE_NOEXCEPT;
};

}
}
