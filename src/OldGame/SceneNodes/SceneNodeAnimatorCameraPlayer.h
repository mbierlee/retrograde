#pragma once

#include "ISceneNodeAnimator.h"
#include "Game/Entities/PlayerEntity.h"

#include <memory>

namespace Game { namespace SceneNode {

class SceneNodeAnimatorCameraPlayer :
    public irr::scene::ISceneNodeAnimator
{
private:
    irr::scene::ISceneManager* sceneManager;
    std::shared_ptr<Game::Entities::PlayerEntity> player;

public:
    SceneNodeAnimatorCameraPlayer(irr::scene::ISceneManager* sceneManager, std::shared_ptr<Game::Entities::PlayerEntity> player);
    ~SceneNodeAnimatorCameraPlayer(void);

    virtual void animateNode( irr::scene::ISceneNode* node, irr::u32 timeMs );

    virtual irr::scene::ISceneNodeAnimator* createClone( irr::scene::ISceneNode* node, irr::scene::ISceneManager* newManager=0 );

};

}}