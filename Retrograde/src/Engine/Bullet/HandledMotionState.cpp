#include "HandledMotionState.h"

Engine::Bullet::HandledMotionState::HandledMotionState( const btTransform& startTrans /*= btTransform::getIdentity()*/,const btTransform& centerOfMassOffset /*= btTransform::getIdentity()*/ )
	: btDefaultMotionState(startTrans, centerOfMassOffset)
	, changed(false)
{
}

void Engine::Bullet::HandledMotionState::getWorldTransform( btTransform& centerOfMassWorldTrans ) const
{
	btDefaultMotionState::getWorldTransform(centerOfMassWorldTrans);
}

void Engine::Bullet::HandledMotionState::setWorldTransform( const btTransform& centerOfMassWorldTrans )
{
	btDefaultMotionState::setWorldTransform(centerOfMassWorldTrans);
	changed = true;
}

bool Engine::Bullet::HandledMotionState::isChanged() const
{
	return changed;
}

void Engine::Bullet::HandledMotionState::resetChanged()
{
	changed = false;
}