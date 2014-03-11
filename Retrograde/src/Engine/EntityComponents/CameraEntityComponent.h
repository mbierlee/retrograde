#pragma once

#include "Engine/Base/BaseEntityComponent.h"

#include <IrrlichtDevice.h>
#include <ICameraSceneNode.h>

namespace Engine {
namespace EntityComponents {

class CameraEntityComponent: public Engine::Base::BaseEntityComponent {
private:
	std::shared_ptr<irr::IrrlichtDevice> device;
	irr::scene::ICameraSceneNode* cameraSceneNode;
	bool registeredWithTargetPosition;

	void initialize(Engine::Framework::IEntity* entity);

public:
	CameraEntityComponent(std::shared_ptr<irr::IrrlichtDevice> device);

	static const irr::core::stringc componentType();
	static const irr::core::stringc familyType();

	virtual const irr::core::stringc getComponentType() const override;
	virtual const irr::core::stringc getFamilyType() const override;
	virtual void update(Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime) override;

	virtual void handleNotification(std::shared_ptr<Engine::Framework::IEntityComponent> entityComponent) override;
};

}
}
