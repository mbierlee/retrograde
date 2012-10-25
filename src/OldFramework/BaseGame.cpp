#include "BaseGame.h"


Framework::BaseGame::BaseGame(void)
	: gameExitRequested(false)
	, windowActive(true)
{
}


Framework::BaseGame::~BaseGame(void)
{
}

void Framework::BaseGame::updateAllEntities(unsigned int deltaTime)
{
	for (unsigned int i = 0; i < entities.size(); i++ ){
		std::shared_ptr<Framework::IEntity> ent = entities[i];
		ent->preupdate(deltaTime);
		ent->update(deltaTime);
		ent->postupdate(deltaTime);
	}
}

void Framework::BaseGame::removeAllEntities()
{
	entities.clear();
}

void Framework::BaseGame::addEntity( std::shared_ptr<Framework::IEntity> entity )
{
	entities.push_back(entity);
}

void Framework::BaseGame::removeEntity( std::shared_ptr<Framework::IEntity> entity )
{
	for (unsigned int i = 0; i < entities.size(); i++) {
		if (entities[i] == entity) {
			entities.erase(entities.begin() + i);
			break;;
		}
	}
}

bool Framework::BaseGame::exitRequested()
{
	return gameExitRequested;
}

void Framework::BaseGame::setWindowActive( bool isActive )
{
	windowActive = isActive;
}
