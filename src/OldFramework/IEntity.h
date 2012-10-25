#pragma once

#include "IEntityMutator.h"

#include <memory>
#include <string>

namespace Framework {

	class IEntity {
	public:
		virtual void initalize() =0;
		virtual void update(unsigned int deltaTime) =0;
		virtual bool hasMutators () =0;
		virtual void addMutator (std::shared_ptr<Framework::IEntityMutator> mutator) =0;
		virtual void removeMutator (std::shared_ptr<Framework::IEntityMutator> mutator) =0;
		virtual void clearMutators() =0;

		virtual void preupdate(unsigned int deltaTime) =0;
		virtual void postupdate(unsigned int deltaTime) =0;

		virtual std::wstring getEntityName() const =0;
		virtual int getEntityType() =0;
		virtual unsigned int getEntityId() const =0;
		virtual void setEntityId(unsigned int id) =0;

		virtual ~IEntity(){};
	};

}