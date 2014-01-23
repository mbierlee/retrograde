#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <IMesh.h>
#include <IMeshSceneNode.h>
#include <IrrlichtDevice.h>
#include <SMaterial.h>

namespace Engine { namespace EntityComponents {
	class VisualModelEntityComponent
		: public Engine::Base::BaseEntityComponent
	{
	private:
		irr::scene::IMesh* mesh;
		irr::scene::IMeshSceneNode* meshSceneNode;
		std::shared_ptr<irr::IrrlichtDevice> device;
		bool usingMaterialComponent;

	public:
		VisualModelEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device, irr::scene::IMesh* mesh);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);

		void initialize(Engine::Framework::IEntity* entity);
		virtual bool isInitialized() const;
		virtual void handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent );
	};
}}