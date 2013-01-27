#pragma once

#include "Engine/Framework/IEntityComponent.h"

#include "vector3d.h"

namespace Engine { namespace EntityComponents {

class PositionEntityComponent :
	public Engine::Framework::IEntityComponent
{
private:
	irr::core::vector3df position;

public:
	PositionEntityComponent(irr::core::vector3df& position = irr::core::vector3df(0));

	virtual const irr::core::stringc getComponentType() const;
	virtual const irr::core::stringc getFamilyType() const;
	virtual void update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime );

	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	const irr::core::vector3df& getPosition() const;
	void setPosition(const irr::core::vector3df& position);
};

}}