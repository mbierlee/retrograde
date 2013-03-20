#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <ISceneNode.h>
#include <IrrlichtDevice.h>
#include <aabbox3d.h>

namespace Engine { namespace EntityComponents {
	class SceneNodeEntityComponent
		: public Engine::Base::BaseEntityComponent
		, public irr::scene::ISceneNode
	{
	private:
		bool registeredWithPosition, registeredWithRotation;
		irr::core::aabbox3df aabbox;

	public:
		SceneNodeEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device, irr::scene::ISceneNode* parent = nullptr);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);
		virtual void handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent );

		virtual void render();
		virtual const irr::core::aabbox3d<irr::f32>& getBoundingBox() const;
		virtual void OnRegisterSceneNode();
	};
}}