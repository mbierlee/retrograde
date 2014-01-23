#pragma once

/**
* Macros for getting and adding components without having to deal with the syntax bombardment of STL
*/
#define COMPONENT(_COMPTYPE) std::static_pointer_cast<Engine::EntityComponents::_COMPTYPE>(entity->getComponent(Engine::EntityComponents::_COMPTYPE::familyType()))
#define ADD_COMPONENT(_COMTYPE, ...) entity->addComponent(std::make_shared<Engine::EntityComponents::_COMTYPE>(__VA_ARGS__))

#include <irrString.h>

#include <memory>

namespace Engine { namespace Framework {
	class IEntityComponent;

	class IEntity {
	public:
		virtual ~IEntity() {};

		virtual irr::u32 getId() const =0;
		virtual void setId(const int entityId) =0;

		virtual const irr::core::stringc& getType() const =0;
		virtual void setType(const irr::core::stringc& typeName) =0;

		virtual const irr::core::stringc& getName() const =0;
		virtual void setName(const irr::core::stringc& name) =0;

		virtual void addComponent(std::shared_ptr<Engine::Framework::IEntityComponent> component) =0;
		virtual std::shared_ptr<Engine::Framework::IEntityComponent> getComponent(const irr::core::stringc familyType) =0;
		virtual void removeComponent(const irr::core::stringc familyType) =0;
		virtual void clearComponents() =0;
		virtual bool hasComponent(const irr::core::stringc familyType) =0;

		virtual void subscribeToEvents(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent) =0;

		virtual void update(irr::u32 frameTime, irr::u32 lastFrameTime) =0;
	};
}}
