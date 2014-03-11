#pragma once

#include "Engine/Base/BaseEntityComponent.h"

namespace Engine {
namespace EntityComponents {

class HeightEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	irr::f32 height;

public:
	HeightEntityComponent(irr::f32 height = 0);

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	irr::f32 getHeight() const;
	void setHeight(irr::f32 height);

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;
};

}
}
