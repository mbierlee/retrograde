#pragma once

#include <Engine/Framework/IEntityFactory.h>

#include <Hypodermic/AutowiredConstructor.h>

#include <IrrlichtDevice.h>

namespace Breakout {

class BreakoutEntityFactory: public Engine::Framework::IEntityFactory {
private:
	std::shared_ptr<Engine::Framework::IEntity> createBorderEntity();
	std::shared_ptr<irr::IrrlichtDevice> device;

public:
	typedef Hypodermic::AutowiredConstructor<BreakoutEntityFactory(irr::IrrlichtDevice*)> AutowiredSignature;

	BreakoutEntityFactory(std::shared_ptr<irr::IrrlichtDevice> device);
	virtual ~BreakoutEntityFactory();

	virtual std::shared_ptr<Engine::Framework::IEntity> create(irr::core::stringc entityType);
	virtual void clearPool();
};

}

