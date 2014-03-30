#pragma once

#include <Engine/Framework/IEntityFactory.h>

#include <Hypodermic/AutowiredConstructor.h>

namespace Breakout {

class BreakoutEntityFactory: public Engine::Framework::IEntityFactory {
public:
	typedef Hypodermic::AutowiredConstructor<BreakoutEntityFactory()> AutowiredSignature;

	virtual ~BreakoutEntityFactory();

	virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType);
	virtual void clearPool();
};

}

