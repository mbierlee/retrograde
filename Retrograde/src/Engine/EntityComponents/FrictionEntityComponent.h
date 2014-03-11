#pragma once

#include "Engine/Base/BaseEntityComponent.h"

namespace Engine {
namespace EntityComponents {

class FrictionEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	irr::f32 friction;

public:
	FrictionEntityComponent(irr::f32 friction = 0.f);

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;

	void setFriction(const irr::f32& friction);
	irr::f32 getFriction() const;
};

}
}
