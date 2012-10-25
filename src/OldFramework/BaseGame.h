#pragma once
#include "IGame.h"
#include "IEntity.h"

#include <vector>

namespace Framework {

class BaseGame :
	public Framework::IGame
{
protected:
	std::vector<std::shared_ptr<Framework::IEntity>> entities;

	virtual void updateAllEntities(unsigned int deltaTime);
	virtual void removeAllEntities();

	bool gameExitRequested, windowActive;

public:
	BaseGame(void);
	~BaseGame(void);

	virtual void addEntity( std::shared_ptr<Framework::IEntity> entity );
	virtual void removeEntity( std::shared_ptr<Framework::IEntity> entity );
	virtual bool exitRequested();

	virtual void setWindowActive( bool isActive );

};

}