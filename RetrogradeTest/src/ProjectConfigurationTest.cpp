#include <gtest/gtest.h>
#include <gmock/gmock.h>

using ::testing::Return;

namespace RetrogradeTest {
	class IFoo {
	public:
		virtual bool worldDominationIsGuaranteed() =0;
		virtual ~IFoo() {}
	};

	class MockFoo
		: public IFoo
	{
	public:
		MOCK_METHOD0(worldDominationIsGuaranteed, bool());
		virtual ~MockFoo() {}
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
