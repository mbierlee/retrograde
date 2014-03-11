#pragma once

#include "Engine/Base/BaseEntityComponent.h"

namespace Engine {
namespace EntityComponents {

class KillRotationEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	bool killedRotation;

public:
	KillRotationEntityComponent();

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;
};

}
}
