#pragma once

#include "Engine/Base/BaseEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"

#include <quaternion.h>

namespace Engine {
namespace EntityComponents {

class HeadRotationEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	irr::core::quaternion headRotation;

public:
	HeadRotationEntityComponent(const irr::core::quaternion& headRotation = irr::core::quaternion());

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	void setRotation(const irr::core::quaternion& rotation);
	const irr::core::quaternion& getRotation() const;

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;
};

}
}
