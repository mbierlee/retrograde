#include "CollectableItemEntity.h"

#include "Entities.h"
#include "Game/PShootGame.h"

#include "IMeshSceneNode.h"
#include "IVideoDriver.h"

Game::Entities::CollectableItemEntity::CollectableItemEntity(Game::PShootGame* game, irr::scene::ISceneNode* parent, irr::scene::ISceneManager* sceneManager)
	: irr::scene::ISceneNode(parent, sceneManager)
	, game(game)
	, itemMeshNode(nullptr)
	, sceneManager(sceneManager)
	, collected(false)
{	
	sceneManager->grab();
}


Game::Entities::CollectableItemEntity::~CollectableItemEntity(void)
{
	if (sceneManager) sceneManager->drop();
}

void Game::Entities::CollectableItemEntity::initalize()
{
	setPosition(irr::core::vector3df(-30, 15, 55));
	setScale(irr::core::vector3df(5,5,5));

	itemMeshNode = sceneManager->addMeshSceneNode(sceneManager->getMesh("data/monkey.obj"),this);

	//irr::video::IVideoDriver* driver = sceneManager->getVideoDriver();

	if (itemMeshNode) {
		itemMeshNode->getMaterial(0).Lighting = false;
	
		irr::scene::ISceneNodeAnimator* animator = sceneManager->createRotationAnimator(irr::core::vector3df(0, 1.f, 0));
		itemMeshNode->addAnimator(animator);
		animator->drop();
	}
}

void Game::Entities::CollectableItemEntity::update( unsigned int deltaTime )
{
}

std::wstring Game::Entities::CollectableItemEntity::getEntityName() const
{
	return std::wstring(ENTITY_COLLECTABLEITEMENTITY);
}

void Game::Entities::CollectableItemEntity::render()
{
}

const irr::core::aabbox3d<irr::f32>& Game::Entities::CollectableItemEntity::getBoundingBox() const
{
	return itemMeshNode ? itemMeshNode->getBoundingBox() : aabb;
}

bool Game::Entities::CollectableItemEntity::isCollected() const
{
	return collected;
}

void Game::Entities::CollectableItemEntity::setCollected( bool collected )
{
	this->collected = collected;
	setVisible(!collected);
}

int Game::Entities::CollectableItemEntity::getEntityType()
{
	return EET_COLLECTABLEITEMENTITY;
}

void Game::Entities::CollectableItemEntity::handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject )
{
	if (sourceObject == this)
		return;

	Game::Event::GameEvent& gameEvent = static_cast<Game::Event::GameEvent&>(event);

	switch(gameEvent.type) {
	case Game::Event::EGET_ITEM_PICKED_UP:
		{
			if (gameEvent.targetEntityId == getEntityId()) {
				//Game::Event::GameEvent attributeChangeEvent(Game::Event::EGET_CHANGE_ATTRIBUTE);
				Game::Event::ChangeAttributeGameEvent attributeChangeEvent(
					Game::Event::ChangeAttributeGameEvent::ECAGEMT_ADD, 
					Game::Event::ChangeAttributeGameEvent::ECAGEAT_JUMPS, 
					10u,
					gameEvent.sourceEntityId,
					getEntityId());

				//attributeChangeEvent.sourceEntityId = getEntityId();
				//attributeChangeEvent.targetEntityId =  gameEvent.sourceEntityId;
				//attributeChangeEvent.attributeChangeData.amount = 10U;
				manager->postEvent(attributeChangeEvent, this);
				setCollected(true);
			}
		}
		break;
	}
}
