#include <gtest/gtest.h>

#include <Engine/Event.h>
#include <irrString.h>

TEST(EventTest, testSetGetName) {
	Engine::Event event("TestEvent");
	EXPECT_EQ(irr::core::stringc("TestEvent"), event.getName());
}

TEST(EventTest, testDifferentInstancesOfSameEventAreEqual) {
	Engine::Event event1("TestEvent");
	Engine::Event event2("TestEvent");
	EXPECT_EQ(event1, event2);

	Engine::Event* event3 = new Engine::Event("TestEvent");
	Engine::Event* event4 = new Engine::Event("TestEvent");
	EXPECT_NE(event3, event4);

	delete event3;
	delete event4;
}