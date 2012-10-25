#pragma once

#include "Framework/IEntity.h"
#include <memory>

namespace Framework {
	class IGame {
	protected:
		virtual void updateAllEntities(unsigned int deltaTime) =0;
		virtual void removeAllEntities() =0;

	public:
		virtual void initialize() =0;
		virtual void update() =0;
		virtual void draw() =0;

		virtual void addEntity(std::shared_ptr<Framework::IEntity> entity) =0;
		virtual void removeEntity(std::shared_ptr<Framework::IEntity> entity) =0;

		virtual void setWindowActive(bool isActive) =0;

		virtual bool exitRequested() =0;

		virtual ~IGame(){};
	};
}