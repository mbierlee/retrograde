#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <vector3d.h>

namespace Engine {
namespace EntityComponents {

class InertiaEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	irr::core::vector3df inertia;

public:
	InertiaEntityComponent(irr::core::vector3df inertia = irr::core::vector3df(0));

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;

	irr::core::vector3df getIntertia() const;
	void setInertia(irr::core::vector3df inertia);
};

}
}
