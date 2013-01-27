#pragma once

#include <LinearMath/btDefaultMotionState.h>

namespace Engine { namespace Bullet {

ATTRIBUTE_ALIGNED16(struct) HandledMotionState
	: btDefaultMotionState
{
private:
	bool changed;

public:
	BT_DECLARE_ALIGNED_ALLOCATOR();

	HandledMotionState(const btTransform& startTrans = btTransform::getIdentity(),const btTransform& centerOfMassOffset = btTransform::getIdentity());
	virtual void getWorldTransform( btTransform& centerOfMassWorldTrans ) const;
	virtual void setWorldTransform( const btTransform& centerOfMassWorldTrans );

	bool isChanged() const;
	void resetChanged();
};

}}