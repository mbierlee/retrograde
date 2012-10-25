#include "Game/Entities/PlayerEntity.h"

#include "Entities.h"
#include "Game/PShootGame.h"

#include "ISceneManager.h"
#include "ISceneNode.h"

#include <math.h>
#include <memory>

#define KEYBOARD_SPEED 200.f

#define JUMP_SPEED 200.f
#define MOVE_SPEED 120.f

Game::Entities::PlayerEntity::PlayerEntity(Game::PShootGame* game, irr::scene::ISceneNode* parent, irr::scene::ISceneManager* sceneManager, irr::s32 id, irr::gui::ICursorControl* cursor)
	: irr::scene::ISceneNode(parent, sceneManager, id)
	, cursor(cursor)
	, gravity(irr::core::vector3df(0, -100, 0))
	, game(game)
	, moveMode(EPMM_WALK)
{
	normalizedGravity = irr::core::vector3df(gravity).normalize();
	state.headRotation = getRotation();
	resetBoundingBox();
	eventBuffer.reserve(10);
}

Game::Entities::PlayerEntity::~PlayerEntity(void)  
{
}

void Game::Entities::PlayerEntity::initalize()
{
}

void Game::Entities::PlayerEntity::update(unsigned int deltaTime)
{     
	irr::f32 timeFactor = deltaTime * 0.001f;

	if (state.turnLeft || state.turnRight || state.lookUp || state.lookDown) {
		irr::core::vector3df rotation = getRotation();

		irr::f32 effectiveRotateSpeed = state.mouseLook ? state.rotateSpeed : state.rotateSpeed * timeFactor;

		if (state.turnLeft) {
			rotation.Y -= state.turnMagnitude * (effectiveRotateSpeed);
			state.headRotation.Y = rotation.Y;
		}
		if (state.turnRight) {
			rotation.Y += state.turnMagnitude * (effectiveRotateSpeed);
			state.headRotation.Y = rotation.Y;
		}

		if (state.lookUp) {
			state.headRotation.X -= state.lookMagnitude * (effectiveRotateSpeed);
			if (state.headRotation.X < -89.f) state.headRotation.X = -89.f;
		}
		if (state.lookDown) {
			state.headRotation.X += state.lookMagnitude * (effectiveRotateSpeed);
			if (state.headRotation.X > 89.f) state.headRotation.X = 89.f;
		}        

		rotation.Y = state.headRotation.Y = fmod(rotation.Y, 360.f);
		if (rotation.Y < 0) rotation.Y = 360 - (rotation.Y *-1);

		setRotation(rotation);
	}

	if (state.moveForward || state.moveBackward || state.strafeLeft || state.strafeRight) {
		irr::core::vector3df position = getPosition();
		irr::core::vector3df target = position + state.headRotation.rotationToDirection(irr::core::vector3df(0, 0, 10.f));
				
		irr::core::vector3df direction = target - position;
		direction.normalize();
		irr::core::vector3df resultDirection;

		if (state.moveForward)
			resultDirection += direction;
		if (state.moveBackward)
			resultDirection -= direction;
		if (state.strafeLeft)
			resultDirection += direction.crossProduct(irr::core::vector3df(0, 1, 0));
		if (state.strafeRight)
			resultDirection -= direction.crossProduct(irr::core::vector3df(0, 1, 0));

		if (moveMode != EPMM_FLY)
			resultDirection.Y = 0;

		resultDirection.normalize();
		position += resultDirection * (timeFactor * MOVE_SPEED);

		setPosition(position);
	}
	
	if (collidesWithGround()) {
		if (state.jumps <= 0)
			state.jumps = 1;
	}
	
	if (state.doJump && state.jumps > 0) {
		state.jumpMagnitude = 1.f;
		state.doJump = false;
		state.jumps--;
	}

	if (state.jumpMagnitude > 0) {	
		state.jumpMagnitude -= 2.f * timeFactor;
		irr::core::vector3df jumpForce = -normalizedGravity * JUMP_SPEED;

		irr::core::vector3df position = getPosition();
		position += (jumpForce * state.jumpMagnitude) * timeFactor;
		setPosition(position);		
	}

	handleMovementEvents();
}

void Game::Entities::PlayerEntity::render()
{	
}

const irr::core::aabbox3d<irr::f32>& Game::Entities::PlayerEntity::getBoundingBox() const
{
	return boundingBox;
}

void Game::Entities::PlayerEntity::handleGameEvent( Framework::IGameEvent& event, Framework::IGameEventManager* manager, void* sourceObject )
{
	//Event::GameEvent& gameEvent = (Event::GameEvent&)event;
	Event::GameEvent& gameEvent = static_cast<Event::GameEvent&>(event);

	if (gameEvent.targetEntityId == getEntityId()) {
		switch(gameEvent.type) {
		case Event::EGET_TURN:
			{
				Event::TurnGameEvent& turnGameEvent = static_cast<Event::TurnGameEvent&>(gameEvent);
				eventBuffer.push_back(std::make_shared<Event::TurnGameEvent>(turnGameEvent));
			}
			break;
		case Event::EGET_LOOK:
			{
				Event::LookGameEvent& lookGameEvent = static_cast<Event::LookGameEvent&>(gameEvent);
				eventBuffer.push_back(std::make_shared<Event::LookGameEvent>(lookGameEvent));
			}
			break;
		case Event::EGET_WALK_FORWARD:		
		case Event::EGET_WALK_BACKWARD:
		case Event::EGET_STOP_WALK_FORWARD:
		case Event::EGET_STOP_WALK_BACKWARD:
		case Event::EGET_STRAFE_LEFT:
		case Event::EGET_STRAFE_RIGHT:
		case Event::EGET_STOP_STRAFE_LEFT:
		case Event::EGET_STOP_STRAFE_RIGHT:
		//case Event::EGET_TURN_LEFT:
		//case Event::EGET_TURN_RIGHT:		
		case Event::EGET_STOP_TURN_LEFT:
		case Event::EGET_STOP_TURN_RIGHT:
		case Event::EGET_STOP_TURN:
		case Event::EGET_WALK_STOP:
		//case Event::EGET_LOOK_UP:
		//case Event::EGET_LOOK_DOWN:
		case Event::EGET_STOP_LOOK_UP:
		case Event::EGET_STOP_LOOK_DOWN:
		case Event::EGET_STOP_LOOK:
		case Event::EGET_JUMP:
		case Event::EGET_STOP_JUMP:
		case Event::EGET_CRAWL:
		case Event::EGET_STAND:
			//eventBuffer.push_back(Game::Event::GameEvent((Game::Event::GameEvent&)event));
			eventBuffer.push_back(std::make_shared<Game::Event::GameEvent>(gameEvent));
			break;
		case Event::EGET_SWITCH_MOUSELOOK:
			state.rotateSpeed = MOUSE_SPEED;
			state.mouseLook = true;
			break;
		case Event::EGET_SWITCH_KEYBOARDLOOK:
			state.rotateSpeed = KEYBOARD_SPEED;
			state.mouseLook = false;
			break;
		case Event::EGET_CHANGE_ATTRIBUTE:
			{			
				if (gameEvent.targetEntityId == getEntityId()) {
					//state.jumps += gameEvent.attributeChangeData.amount;
					Game::Event::ChangeAttributeGameEvent& attributeEvent = static_cast<Game::Event::ChangeAttributeGameEvent&>(gameEvent);
					handleAttributeChangeEvent(attributeEvent);
				}
			}
			break;
		}
	}
}

void Game::Entities::PlayerEntity::OnRegisterSceneNode()
{
	irr::scene::ISceneNode::OnRegisterSceneNode();
}

irr::core::vector3df Game::Entities::PlayerEntity::getHeadRotation()
{
	return state.headRotation;
}

void Game::Entities::PlayerEntity::setModeMode( Entities::PlayerMoveMode moveMode )
{
	this->moveMode = moveMode;
}

Game::Entities::PlayerMoveMode Game::Entities::PlayerEntity::getMoveMode()
{
	return moveMode;
}

bool Game::Entities::PlayerEntity::collidesWithGround()
{
	//TODO: TIGHTEN, somehow allows you to double jump when CL_RATE is unbound
	irr::scene::ISceneCollisionManager* collisionManager = SceneManager->getSceneCollisionManager();
	irr::scene::ITriangleSelector* worldSelector = game->getWorldTriangleSelector();

	if (!worldSelector) return false;

	collisionManager->grab();
	worldSelector->grab();
	irr::core::vector3df position = getPosition() + -normalizedGravity;
	irr::core::vector3df rayEnd = position + (normalizedGravity * 1.5);

	irr::scene::ISceneNode* outNode;
	irr::core::vector3df outCollisionPoint;
	irr::core::triangle3df outTriangle;

	bool collisionDetected = collisionManager->getCollisionPoint(irr::core::line3df(position, rayEnd), worldSelector, outCollisionPoint, outTriangle, outNode);
	
	worldSelector->drop();
	collisionManager->drop();

	return collisionDetected;
}

irr::f32 Game::Entities::PlayerEntity::getHeight()
{
	return state.crawl ? 6.f : 17.f;
}

void Game::Entities::PlayerEntity::resetBoundingBox()
{
	boundingBox = irr::core::aabbox3df(0, 0, 0, 9, getHeight(), 9);
}

std::wstring Game::Entities::PlayerEntity::getEntityName() const
{
	return std::wstring(ENTITY_PLAYERENTITY);
}

int Game::Entities::PlayerEntity::getEntityType()
{
	return EET_PLAYERENTITY;
}

void Game::Entities::PlayerEntity::handleMovementEvents()
{
	if (!eventBuffer.empty()) {
		for (unsigned int i = 0; i < eventBuffer.size(); i++) {
			std::shared_ptr<Game::Event::GameEvent> event = eventBuffer[i];

			switch(event->type) {
			case Event::EGET_WALK_FORWARD:
				state.moveForward = true;
				break;
			case Event::EGET_WALK_BACKWARD:
				state.moveBackward = true;
				break;
			case Event::EGET_STOP_WALK_FORWARD:
				state.moveForward = false;
				break;
			case Event::EGET_STOP_WALK_BACKWARD:
				state.moveBackward = false;
				break;
			case Event::EGET_STRAFE_LEFT:
				state.strafeLeft = true;
				break;
			case Event::EGET_STRAFE_RIGHT:
				state.strafeRight = true;
				break;
			case Event::EGET_STOP_STRAFE_LEFT:
				state.strafeLeft = false;
				break;
			case Event::EGET_STOP_STRAFE_RIGHT:
				state.strafeRight = false;
				break;
			/*case Event::EGET_TURN_LEFT:
				state.turnLeft = true;
				state.turnMagnitude = event->turnLookEventData.magnitude;
				break;
			case Event::EGET_TURN_RIGHT:
				state.turnRight = true;
				state.turnMagnitude = event->turnLookEventData.magnitude;
				break;*/
			case Event::EGET_TURN:
				{
					//Game::Event::TurnGameEvent* turnEvent = static_cast<Game::Event::TurnGameEvent*>(event);
					std::shared_ptr<Game::Event::TurnGameEvent> turnEvent = std::static_pointer_cast<Game::Event::TurnGameEvent>(event);
					if (turnEvent->direction == Game::Event::TurnGameEvent::ETGED_LEFT)
						state.turnLeft = true;

					if (turnEvent->direction == Game::Event::TurnGameEvent::ETGED_RIGHT)
						state.turnRight = true;

					state.turnMagnitude = turnEvent->magnitude;
				}
				break;
			case Event::EGET_STOP_TURN_LEFT:
				state.turnLeft = false;
				break;
			case Event::EGET_STOP_TURN_RIGHT:
				state.turnRight = false;
				break;
			case Event::EGET_STOP_TURN:
				state.turnLeft = false;
				state.turnRight = false;
				state.turnMagnitude = 0;
				break;
			case Event::EGET_WALK_STOP:
				state.moveForward = false;
				state.moveBackward = false;
				break;
			/*case Event::EGET_LOOK_UP:
				state.lookUp = true;
				state.lookMagnitude = event->turnLookEventData.magnitude;
				break;
			case Event::EGET_LOOK_DOWN:
				state.lookDown = true;
				state.lookMagnitude = event->turnLookEventData.magnitude;
				break;*/
			case Event::EGET_LOOK:
				{
					std::shared_ptr<Game::Event::LookGameEvent> lookEvent = std::static_pointer_cast<Game::Event::LookGameEvent>(event);
					if (lookEvent->direction == Game::Event::LookGameEvent::ELGED_UP)
						state.lookUp = true;

					if (lookEvent->direction == Game::Event::LookGameEvent::ELGED_DOWN)
						state.lookDown = true;

					state.lookMagnitude = lookEvent->magnitude;
				}
				break;
			case Event::EGET_STOP_LOOK_UP:
				state.lookUp = false;
				break;
			case Event::EGET_STOP_LOOK_DOWN:
				state.lookDown = false;
				break;
			case Event::EGET_STOP_LOOK:
				state.lookUp = false;
				state.lookDown = false;
				break;
			case Event::EGET_JUMP:
				state.doJump = true;
				break;
			case Event::EGET_STOP_JUMP:
				state.doJump = false;
				break;
			case Event::EGET_CRAWL:
				state.crawl = true;
				resetBoundingBox();
				break;
			case Event::EGET_STAND:
				state.crawl = false;
				resetBoundingBox();
				break;
			}
		}

		eventBuffer.clear();
	}
}

void Game::Entities::PlayerEntity::handleAttributeChangeEvent( Game::Event::ChangeAttributeGameEvent& attributeEvent )
{
	switch (attributeEvent.attributeType)
	{
	case Game::Event::ChangeAttributeGameEvent::ECAGEAT_JUMPS:
		if (attributeEvent.mutationType == Game::Event::ChangeAttributeGameEvent::ECAGEMT_ADD) {
			state.jumps += attributeEvent.amount;
		}
		break;
	}
}
