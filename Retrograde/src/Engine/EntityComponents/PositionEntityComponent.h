#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include "vector3d.h"

namespace Engine {
namespace EntityComponents {

class PositionEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	irr::core::vector3df position;

public:
	PositionEntityComponent(const irr::core::vector3df& position = irr::core::vector3df(0));

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;

	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	const irr::core::vector3df& getPosition() const;
	void setPosition(const irr::core::vector3df& position);
};

}
}
