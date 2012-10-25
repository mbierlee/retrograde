#include "Entities.h"

#include "Engine/Entity.h"
#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"
#include "Engine/EntityComponents/CameraEntityComponent.h"

std::shared_ptr<Engine::Framework::IEntity> Game::createFlyCameraEntity( irr::scene::ICameraSceneNode* cameraSceneNode )
{
	std::shared_ptr<Engine::Entity> entity = std::make_shared<Engine::Entity>();
	entity->addComponent(std::make_shared<Engine::EntityComponents::PositionEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::RotationEntityComponent>());
	entity->addComponent(std::make_shared<Engine::EntityComponents::CameraEntityComponent>(cameraSceneNode));
	return entity;
}
