#pragma once

#include "Engine/Base/BaseEntityComponent.h"

namespace Engine {
namespace EntityComponents {

class KeepUprightEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	bool uprightSet;

public:
	KeepUprightEntityComponent();

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	bool isUpright();

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;
};

}
}
