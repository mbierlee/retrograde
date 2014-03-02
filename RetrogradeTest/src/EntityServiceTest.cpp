#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <Engine/EntityService.h>
#include <Engine/Entity.h>

using ::testing::Eq;

namespace RetrogradeTest {
	class MockEntity: public Engine::Entity {
	public:
		MOCK_METHOD2(update, void(irr::u32 frameTime, irr::u32 lastFrameTime));
	};
}

TEST(EntityServiceTest, testAddEntity) {
	Engine::EntityService entityService;
	auto entity = std::make_shared<Engine::Entity>();
	entityService.addEntity(entity);

	EXPECT_EQ(1, entityService.entityCount());
}

TEST(EntityServiceTest, testRemoveEntity) {
	Engine::EntityService entityService;
	auto entity = std::make_shared<Engine::Entity>();
	entityService.addEntity(entity);

	entityService.removeEntity(entity);

	EXPECT_EQ(0, entityService.entityCount());
}

TEST(EntityServiceTest, testClearEntities) {
	Engine::EntityService entityService;
	auto entity = std::make_shared<Engine::Entity>();
	entityService.addEntity(entity);

	entityService.clearEntities();

	EXPECT_EQ(0, entityService.entityCount());
}

TEST(EntityServiceTest, testGetEntityById) {
	Engine::EntityService entityService;
	auto expectedEntity = std::make_shared<Engine::Entity>();
	expectedEntity->setId(123);
	entityService.addEntity(expectedEntity);

	auto actualEntity = entityService.getEntity(123);

	EXPECT_EQ(expectedEntity, actualEntity);
}

TEST(EntityServiceTest, testGetEntityByType) {
	Engine::EntityService entityService;
	auto expectedEntity = std::make_shared<Engine::Entity>("TestEntity");
	entityService.addEntity(expectedEntity);

	auto actualEntity = entityService.getEntity("TestEntity");

	EXPECT_EQ(expectedEntity, actualEntity);
}

TEST(EntityServiceTest, testUpdateEntities) {
	Engine::EntityService entityService;
	auto entity = std::make_shared<RetrogradeTest::MockEntity>();
	EXPECT_CALL(*entity, update(Eq(1), Eq(2))).Times(1);
	entityService.addEntity(entity);

	entityService.updateEntities(1, 2);
}
