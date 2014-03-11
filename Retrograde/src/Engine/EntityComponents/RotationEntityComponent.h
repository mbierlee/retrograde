#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <vector3d.h>
#include <quaternion.h>

namespace Engine {
namespace EntityComponents {

class RotationEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	irr::core::quaternion rotation;

public:
	RotationEntityComponent(const irr::core::vector3df& rotation);
	RotationEntityComponent(const irr::core::quaternion& rotation = irr::core::quaternion());

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;

	const irr::core::vector3df getEulerRotation() const;
	const irr::core::quaternion& getRotation() const;
	void setEulerRotation(const irr::core::vector3df& rotation);
	void setRotation(const irr::core::quaternion& rotation);
};

}
}
