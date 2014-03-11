#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <ITexture.h>

namespace Engine {
namespace EntityComponents {

class TextureEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	irr::video::ITexture* texture;

public:
	TextureEntityComponent(irr::video::ITexture* texture);

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;
	irr::video::ITexture* getTexture() const;
};

}
}
