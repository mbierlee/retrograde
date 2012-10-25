#include "SceneNodeAnimatorCameraPlayer.h"

Game::SceneNode::SceneNodeAnimatorCameraPlayer::SceneNodeAnimatorCameraPlayer(irr::scene::ISceneManager* sceneManager, std::shared_ptr<Entities::PlayerEntity> player)
    : sceneManager(sceneManager)
    , player(player)
{
    //TODO: Throw nasty vile stuff when player is null.
}


Game::SceneNode::SceneNodeAnimatorCameraPlayer::~SceneNodeAnimatorCameraPlayer(void)
{
}

void Game::SceneNode::SceneNodeAnimatorCameraPlayer::animateNode( irr::scene::ISceneNode* node, irr::u32 timeMs )
{
    if (!node || !player || node->getType() != irr::scene::ESNT_CAMERA)
        return;

    irr::scene::ICameraSceneNode* cameraNode = static_cast<irr::scene::ICameraSceneNode*>(node);

    irr::core::vector3df playerHeadRotation = player->getHeadRotation();

    irr::core::vector3df cameraHeightAdjustment = irr::core::vector3df(0, player->getHeight() - 1.f,0);

    cameraNode->setPosition(player->getPosition() + cameraHeightAdjustment);
    cameraNode->setRotation(playerHeadRotation);
    cameraNode->setTarget(player->getPosition() + cameraHeightAdjustment + playerHeadRotation.rotationToDirection(irr::core::vector3df(0, 0, 10.f)));
}

irr::scene::ISceneNodeAnimator* Game::SceneNode::SceneNodeAnimatorCameraPlayer::createClone( irr::scene::ISceneNode* node, irr::scene::ISceneManager* newManager/*=0 */ )
{
    if (!newManager) newManager = sceneManager;
    return new SceneNodeAnimatorCameraPlayer(newManager, player);
}
