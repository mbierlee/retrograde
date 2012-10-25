#include "Core/Mutators/CollisionResponseMutator.h"

#include "vector3d.h"
#include "ISceneCollisionManager.h"
#include "ISceneManager.h"
#include "irrString.h"

Core::Mutators::CollisionResponseMutator::CollisionResponseMutator(irr::scene::ITriangleSelector* worldSelector, irr::ILogger* logger)
	: world(worldSelector)
	, logger(logger)
{
	if (worldSelector)
		worldSelector->grab();
}


Core::Mutators::CollisionResponseMutator::~CollisionResponseMutator(void)
{
	if (world)
		world->drop();
}

void Core::Mutators::CollisionResponseMutator::preUpdate( unsigned int deltaTime )
{	
	if (entity.expired())
		return;

	std::shared_ptr<Framework::IEntity> ent = entity.lock();
	irr::scene::ISceneNode* irrEntity = dynamic_cast<irr::scene::ISceneNode*>(ent.get());

	if (!irrEntity) {
		if (logger) {
			irr::core::stringw warnString(L"CollisionResponseMutator attached to non-irrlicht entity ");
			warnString.append(ent->getEntityName().c_str());
			warnString.append(L" Detaching mutator.");
			logger->log(warnString.c_str(), irr::ELL_WARNING);
		}
		ent->removeMutator(shared_from_this());
		return;
	}

	lastPosition = irrEntity->getPosition();
}

void Core::Mutators::CollisionResponseMutator::postUpdate( unsigned int deltaTime )
{
	if (entity.expired() || !world)
		return;

	irr::f32 timeFactor = deltaTime * 0.001f;

	std::shared_ptr<Framework::IEntity> ent = entity.lock();
	irr::scene::ISceneNode* irrEntity = dynamic_cast<irr::scene::ISceneNode*>(ent.get());

	if (!irrEntity) {
		std::wprintf(L"Warning: CollisionResponseMutator attached to non-irrlicht entity %s. Detaching.", ent->getEntityName().c_str());
		ent->removeMutator(shared_from_this());
		return;
	}

	irr::core::vector3df currentPosition = irrEntity->getPosition();
	irr::core::vector3df velocity = currentPosition - lastPosition;

	irr::scene::ISceneCollisionManager* collisionManager = irrEntity->getSceneManager()->getSceneCollisionManager();
		
	bool falling = false;
	irr::scene::ISceneNode* collidedNode;

	//TODO: fix sliding speed
	//TODO: adjustable gravity
	
	irr::core::aabbox3df entityAABB = irrEntity->getBoundingBox();
	irr::core::vector3df ellipsoidRadius = entityAABB.getExtent() / 2;

	irr::core::vector3df ellipsoidOffset(0);
	ellipsoidOffset.Y = entityAABB.getExtent().Y / 2;
	
	irr::core::vector3df collisionResult = collisionManager->getCollisionResultPosition(
		world, lastPosition + ellipsoidOffset, ellipsoidRadius, velocity,irr::core::triangle3df(), irr::core::vector3df(), falling, collidedNode, 0 * 0.0005f /* * timeFactor */, irr::core::vector3df(0, -100, 0) * timeFactor);

	irrEntity->setPosition(collisionResult - ellipsoidOffset);
}