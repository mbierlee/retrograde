#include <gtest/gtest.h>

#include <Engine/Event.h>
#include <irrString.h>

TEST(EventTest, testSetGetName) {
	Engine::Event event("TestEvent");
	EXPECT_EQ(irr::core::stringc("TestEvent"), event.getName());
}	