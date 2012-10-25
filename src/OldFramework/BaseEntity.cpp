#include "BaseEntity.h"


Framework::BaseEntity::BaseEntity(void)
	: mutators(nullptr)
	, entityId(0)
{
}


Framework::BaseEntity::~BaseEntity(void)
{
	if (hasMutators()) {
		mutators->clear();
	}
}

bool Framework::BaseEntity::hasMutators()
{
	return mutators != nullptr && mutators->size() > 0;
}

void Framework::BaseEntity::addMutator( std::shared_ptr<Framework::IEntityMutator> mutator )
{
	if (mutator != nullptr) {
		initMutators();
		mutator->setEntity(shared_from_this());
		mutators->push_back(mutator);
	}
}

void Framework::BaseEntity::removeMutator( std::shared_ptr<Framework::IEntityMutator> mutator )
{
	if (mutators != nullptr && mutator != nullptr) {
		for (unsigned int i = 0; i < mutators->size(); i++) {
			if (mutators->at(i) == mutator) {
				mutators->erase(mutators->begin() + i);
				break;
			}
		}
	}
}

void Framework::BaseEntity::initMutators()
{
	if (mutators == nullptr)
		mutators = new std::vector<std::shared_ptr<Framework::IEntityMutator>>();
}

void Framework::BaseEntity::preupdate( unsigned int deltaTime )
{
	if (hasMutators()) {
		for (unsigned int i = 0; i < mutators->size(); i++) {
			std::shared_ptr<Framework::IEntityMutator> mutator = mutators->at(i);
			mutator->preUpdate(deltaTime);
		}
	}
}

void Framework::BaseEntity::postupdate( unsigned int deltaTime )
{
	if (hasMutators()) {
		for (unsigned int i = 0; i < mutators->size(); i++) {
			std::shared_ptr<Framework::IEntityMutator> mutator = mutators->at(i);
			mutator->postUpdate(deltaTime);
		}
	}
}

void Framework::BaseEntity::clearMutators()
{
	if (hasMutators()) {
		mutators->clear();
	}
}

std::wstring Framework::BaseEntity::getEntityName() const
{
	return std::wstring(L"BaseGame");
}

unsigned int Framework::BaseEntity::getEntityId() const
{
	return entityId;
}

void Framework::BaseEntity::setEntityId( unsigned int id )
{
	this->entityId = id;
}
