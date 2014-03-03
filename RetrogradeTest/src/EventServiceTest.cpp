#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <Engine/EventService.h>
#include <Engine/Framework/IEventObserver.h>
#include <Engine/Event.h>

using ::testing::Eq;

namespace RetrogradeTest {
	class MockObserver: public Engine::Framework::IEventObserver {
	public:
		MOCK_METHOD2(handleEvent, void(const Engine::Framework::IEvent& event, void* source));
	};
}

TEST(EventServiceTest, testRegisterObserver) {
	Engine::EventService eventService;
	auto observer = std::make_shared<RetrogradeTest::MockObserver>();
	eventService.registerObserver(observer);
}

TEST(EventServiceTest, testUnregisterObserver) {
	Engine::EventService eventService;
	auto observer = std::make_shared<RetrogradeTest::MockObserver>();
	eventService.registerObserver(observer);

	eventService.unregisterObserver(observer);
}

TEST(EventServiceTest, testClearObserver) {
	Engine::EventService eventService;
	eventService.clearObservers();
}

TEST(EventServiceTest, testHasObserver) {
	Engine::EventService eventService;
	auto observer = std::make_shared<RetrogradeTest::MockObserver>();
	eventService.registerObserver(observer);

	EXPECT_TRUE(eventService.hasObserver(observer));
}

TEST(EventServiceTest, testHasObserverUsingUnregisteredObserver) {
	Engine::EventService eventService;
	auto observer = std::make_shared<RetrogradeTest::MockObserver>();

	EXPECT_FALSE(eventService.hasObserver(observer));
}

TEST(EventServiceTest, testPostEvent) {
	Engine::EventService eventService;
	auto observer = std::make_shared<RetrogradeTest::MockObserver>();
	eventService.registerObserver(observer);
	Engine::Event testEvent("TestEvent");
	EXPECT_CALL(*observer, handleEvent(Eq(testEvent), Eq(nullptr))).Times(1);

	eventService.postEvent(testEvent, nullptr);
}
