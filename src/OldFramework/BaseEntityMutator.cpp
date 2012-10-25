#include "BaseEntityMutator.h"


Framework::BaseEntityMutator::BaseEntityMutator() 
{
}


Framework::BaseEntityMutator::~BaseEntityMutator(void)
{
}

void Framework::BaseEntityMutator::setEntity( std::weak_ptr<Framework::IEntity> entity )
{
	if (!this->entity.expired()) {
		std::shared_ptr<Framework::IEntity> ent = this->entity.lock();
		ent->removeMutator(shared_from_this());
	}

	this->entity = entity;
}
