#pragma once

#include <memory>

namespace Framework {
	class IEntity;

	class IEntityMutator {
	public:
		virtual void preUpdate(unsigned int deltaTime) = 0;
		virtual void postUpdate(unsigned int deltaTime) = 0;

		virtual void setEntity(std::weak_ptr<Framework::IEntity> entity) =0;

		virtual ~IEntityMutator(){};
	};

}