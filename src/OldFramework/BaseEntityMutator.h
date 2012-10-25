#pragma once

#include <memory>

#include "IEntityMutator.h"
#include "IEntity.h"

namespace Framework {

class BaseEntityMutator :
	public Framework::IEntityMutator,
	public std::enable_shared_from_this<BaseEntityMutator>
{
protected:
	std::weak_ptr<Framework::IEntity> entity;

public:
	BaseEntityMutator();
	~BaseEntityMutator(void);

	virtual void setEntity( std::weak_ptr<Framework::IEntity> entity );
};

}