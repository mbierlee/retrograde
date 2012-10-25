#pragma once
#include "Framework/BaseEntityMutator.h"

#include "ISceneNode.h"
#include "IrrlichtDevice.h"
#include "vector3d.h"
#include "ILogger.h"

namespace Core { namespace Mutators {

class CollisionResponseMutator :
	public Framework::BaseEntityMutator
{
private:
	irr::core::vector3df lastPosition;
	irr::scene::ITriangleSelector* world;
	irr::ILogger* logger;

public:
	CollisionResponseMutator(irr::scene::ITriangleSelector* worldSelector, irr::ILogger* logger = nullptr);
	~CollisionResponseMutator(void);

	virtual void preUpdate( unsigned int deltaTime );

	virtual void postUpdate( unsigned int deltaTime );
};

}}