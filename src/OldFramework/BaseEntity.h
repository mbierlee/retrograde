#pragma once
#include "IEntity.h"
#include "IEntityMutator.h"

#include <vector>

namespace Framework {

class BaseEntity :
	public Framework::IEntity,
	public std::enable_shared_from_this<BaseEntity>
{
private:
	unsigned int entityId;

	void initMutators();

protected:
	std::vector<std::shared_ptr<Framework::IEntityMutator>>* mutators;

public:
	BaseEntity(void);
	~BaseEntity(void);

	virtual bool hasMutators();

	virtual void addMutator( std::shared_ptr<Framework::IEntityMutator> mutator );

	virtual void removeMutator( std::shared_ptr<Framework::IEntityMutator> mutator );

	virtual void preupdate( unsigned int deltaTime );

	virtual void postupdate( unsigned int deltaTime );

	virtual void clearMutators();

	virtual std::wstring getEntityName() const;

	virtual unsigned int getEntityId() const;

	virtual void setEntityId( unsigned int id );

};

}