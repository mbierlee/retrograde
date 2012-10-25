#pragma once

#include "Engine/Framework/IEntityComponent.h"

#include "ICameraSceneNode.h"

namespace Engine { namespace EntityComponents {

	class CameraEntityComponent 
		: public Engine::Framework::IEntityComponent
	{
	private:
		irr::scene::ICameraSceneNode* cameraSceneNode;

	public:
		CameraEntityComponent(irr::scene::ICameraSceneNode* cameraSceneNode);

		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		virtual void update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime );

	};

}}