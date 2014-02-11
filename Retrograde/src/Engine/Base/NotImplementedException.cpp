#include "NotImplementedException.h"

namespace Engine {
namespace Base {

NotImplementedException::NotImplementedException() {

}

NotImplementedException::NotImplementedException(irr::core::stringc message) :
		EngineException(message) {
}

NotImplementedException::~NotImplementedException() {
}

}
}
