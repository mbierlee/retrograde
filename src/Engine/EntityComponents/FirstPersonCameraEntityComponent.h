#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <IrrlichtDevice.h>
#include <ICameraSceneNode.h>

namespace Engine { namespace EntityComponents {
	class FirstPersonCameraEntityComponent
		: public Engine::Base::BaseEntityComponent
	{
	private:
		std::shared_ptr<irr::IrrlichtDevice> device;
		irr::scene::ICameraSceneNode* cameraSceneNode;
		irr::scene::ISceneNode* targetSceneNode;
		irr::f32 eyeHeightOffset;
		bool syncedWithHeight, syncedWithHeadRotation;

		void setEyeHeight( irr::f32 param1 );
		void setCameraRotation(const irr::core::quaternion& headRotation);

	public:
		FirstPersonCameraEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device, irr::f32 eyeHeightOffset = 0.);

		virtual const irr::core::stringc getComponentType() const;
		virtual const irr::core::stringc getFamilyType() const;
		static const irr::core::stringc componentType();
		static const irr::core::stringc familyType();

		void initialize(Engine::Framework::IEntity* entity);

		irr::f32 getEyeHeightOffset() const;
		void setEyeHeightOffset(irr::f32 eyeHeightOffset);

		virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime);
		virtual void handleNotification( std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent );
	};
}}