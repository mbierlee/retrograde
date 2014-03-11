#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <SMaterial.h>

namespace Engine {
namespace EntityComponents {

class VisualMaterialEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	irr::video::SMaterial visualMaterial;
	bool usingTextureComponent;

public:
	VisualMaterialEntityComponent(irr::video::SMaterial& visualMaterial);

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;
	const irr::video::SMaterial& getVisualMaterial() const;
	void setVisualMaterial(const irr::video::SMaterial& material);
};

}
}
