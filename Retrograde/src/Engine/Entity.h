#pragma once

#include "Engine/Framework/IEntity.h"
#include "Engine/Framework/IEntityComponent.h"
#include "Engine/Framework/IEventObserver.h"

#include "irrString.h"

#include <map>
#include <list>
#include <memory>
#include <vector>

namespace Engine {

class Entity: public Engine::Framework::IEntity, public Engine::Framework::IEventObserver {
private:
	int entityId;
	std::map<irr::core::stringc, std::shared_ptr<Engine::Framework::IEntityComponent>> components;
	std::list<irr::core::stringc> componentRemovalSchedule;
	bool componentRemovalLocked;
	irr::core::stringc entityType, entityName;
	std::vector<std::shared_ptr<Engine::Framework::IEntityComponent>> eventSubscribers;

	void removeScheduledComponents();

public:
	Entity(const irr::core::stringc typeName = "Undefined");

	virtual irr::u32 getId() const override;
	virtual void setId(const int entityId) override;

	virtual const irr::core::stringc& getType() const override;
	virtual void setType(const irr::core::stringc& typeName) override;

	virtual void addComponent(std::shared_ptr<Engine::Framework::IEntityComponent> component) override;
	virtual std::shared_ptr<Engine::Framework::IEntityComponent> getComponent(const irr::core::stringc familyType) override;
	virtual void removeComponent(const irr::core::stringc familyType) override;
	virtual void clearComponents() override;
	virtual void update(irr::u32 frameTime, irr::u32 lastFrameTime) override;
	virtual bool hasComponent(const irr::core::stringc familyType) override;

	virtual void handleEvent(const Engine::Framework::IEvent& event, void* source) override;
	virtual void subscribeToEvents(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent);

	virtual const irr::core::stringc& getName() const;

	virtual void setName(const irr::core::stringc& name);
};

}
