#include "stdafx.h"
#include "CppUnitTest.h"

#include "Engine/EntityManager.h"
#include "Engine/Entity.h"

#include <memory>

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace PShootTest
{		
	TEST_CLASS(EntityManagerTest)
	{
	public:
		TEST_METHOD(AddEntityTest)
		{
			std::shared_ptr<Engine::Entity> entity = std::make_shared<Engine::Entity>();
			Engine::EntityManager manager;

			manager.addEntity(entity);
		}

		TEST_METHOD(CountEntityiesTest) {
			std::shared_ptr<Engine::Entity> entity = std::make_shared<Engine::Entity>();
			Engine::EntityManager manager;

			manager.addEntity(entity);
			Assert::AreEqual(1u, manager.entityCount());
		}

		TEST_METHOD(AssignEntityIdTest) {
			std::shared_ptr<Engine::Entity> entity = std::make_shared<Engine::Entity>();
			Engine::EntityManager manager;
			Assert::AreEqual(0u, entity->getId());

			manager.addEntity(entity);
			Assert::AreEqual(1u, entity->getId());
		}

		TEST_METHOD(RecyleEntityIdTest) {
			std::shared_ptr<Engine::Entity> entityOne = std::make_shared<Engine::Entity>();
			std::shared_ptr<Engine::Entity> entityTwo = std::make_shared<Engine::Entity>();
			std::shared_ptr<Engine::Entity> entityThree = std::make_shared<Engine::Entity>();
			Engine::EntityManager manager;

			manager.addEntity(entityOne);
			manager.addEntity(entityTwo);

			manager.removeEntity(entityOne);
			manager.addEntity(entityThree);
			Assert::AreEqual(0u, entityOne->getId());
			Assert::AreEqual(2u, entityTwo->getId());
			Assert::AreEqual(1u, entityThree->getId());
		}
	};
}