#pragma once

#include "Engine/Framework/IEntity.h"

#include "ICameraSceneNode.h"

#include <memory>

namespace Game {

	std::shared_ptr<Engine::Framework::IEntity> createFlyCameraEntity(irr::scene::ICameraSceneNode* cameraSceneNode);

}