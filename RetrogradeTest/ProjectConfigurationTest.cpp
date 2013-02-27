#include <gtest/gtest.h>
#include <gmock/gmock.h>

using ::testing::Return;

namespace RetrogradeTest {
	class IFoo {
	public:
		virtual bool worldDominationIsGuaranteed() =0;
	};

	class MockFoo 
		: public IFoo
	{
	public:
		MOCK_METHOD0(worldDominationIsGuaranteed, bool());
	};
}

TEST(ProjectConfigurationTest, testGoogleTestWorks) {
	SUCCEED();
}

TEST(ProjectConfigurationTest, testGoogleMockWorks) {
	RetrogradeTest::MockFoo mockFoo;

	EXPECT_CALL(mockFoo, worldDominationIsGuaranteed())
		.WillRepeatedly(Return(true));

	EXPECT_TRUE(mockFoo.worldDominationIsGuaranteed());
	EXPECT_TRUE(mockFoo.worldDominationIsGuaranteed());
	EXPECT_TRUE(mockFoo.worldDominationIsGuaranteed());
	EXPECT_TRUE(mockFoo.worldDominationIsGuaranteed());
}