#include "BreakoutEntityFactory.h"

Breakout::BreakoutEntityFactory::~BreakoutEntityFactory() {
}

std::shared_ptr<Engine::Framework::IEntity> Breakout::BreakoutEntityFactory::create(irr::core::stringc entityType) {
	return std::shared_ptr<Engine::Framework::IEntity>();
}

void Breakout::BreakoutEntityFactory::clearPool() {
	// The pool is made out of cheese!
}
