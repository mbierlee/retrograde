#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <Engine/EntityFactoryService.h>
#include <Engine/EntityFactories/DefaultEntityFactory.h>
#include <Engine/Entity.h>

using ::testing::Eq;
using ::testing::Return;

namespace RetrogradeTest {
class MockEntityFactory: public Engine::EntityFactories::DefaultEntityFactory {
public:
	MOCK_METHOD1(create, std::shared_ptr<Engine::Framework::IEntity>(irr::core::stringc entityType));

	MockEntityFactory(): Engine::EntityFactories::DefaultEntityFactory(nullptr) {
	}

};

TEST(EntityFactoryServiceTest, testRegisterFactory) {
	auto mockEntityFactory = std::make_shared<RetrogradeTest::MockEntityFactory>();
	Engine::EntityFactoryService entityFactoryService;
	entityFactoryService.registerFactory(mockEntityFactory);
}

TEST(EntityFactoryServiceTest, testClearRegistry) {
	Engine::EntityFactoryService entityFactoryService;
	entityFactoryService.clearRegistry();
}

TEST(EntityFactoryServiceTest, testCreateEntity) {
	auto mockEntityFactory = std::make_shared<RetrogradeTest::MockEntityFactory>();
	auto expectedEntity = std::make_shared<Engine::Entity>("TestEntity");
	EXPECT_CALL(*mockEntityFactory, create(Eq("TestEntity"))).WillOnce(Return(expectedEntity));
	Engine::EntityFactoryService entityFactoryService;
	entityFactoryService.registerFactory(mockEntityFactory);


	auto actualEntity = entityFactoryService.createEntity("TestEntity");

	EXPECT_EQ(expectedEntity, actualEntity);
}

}
