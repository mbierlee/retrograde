#pragma once

#include "Engine/Framework/IEntityComponent.h"
#include "Engine/Framework/IEventObserver.h"
#include "Engine/Framework/IEvent.h"

#include "IrrlichtDevice.h"
#include "ICameraSceneNode.h"

#include <queue>

namespace Engine { namespace EntityComponents {

	class FreeflightCameraEntityComponent 
		: public Engine::Framework::IEntityComponent
	{		
	private:
		std::shared_ptr<irr::IrrlichtDevice> device;
		irr::scene::ICameraSceneNode* cameraSceneNode;

	public:
		FreeflightCameraEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);
	};

}}