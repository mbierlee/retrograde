#include <gtest/gtest.h>

#include <Engine/Base/BaseContentLoader.h>

namespace RetrogradeTest {
	class DummyContent {
	private:
		static int timesInitilized;

	public:
		static bool disposed;

		DummyContent() {
			++timesInitilized;
		}

		virtual ~DummyContent() {
			disposed = true;
		}

		int getTimesInitialized() const {
			return timesInitilized;
		}
	};

	int DummyContent::timesInitilized = 0;
	bool DummyContent::disposed = false;

	class TestContentLoader
		: public Engine::Base::BaseContentLoader<DummyContent>
	{
	protected:
		virtual std::shared_ptr<DummyContent> loadContent( const irr::core::stringw& fileName ) override
		{
			return std::shared_ptr<DummyContent>(new DummyContent());
		}

	public:
		virtual bool canLoad(const irr::core::stringw& fileName) override
		{
			return true;
		}
	};

TEST(ContentLoaderTest, testRequestCachedContent) {
	RetrogradeTest::TestContentLoader loader;
	loader.requestContent("SomeFile");
	auto loadedContent = loader.requestContent("SomeFile");
	EXPECT_EQ(1, loadedContent->getTimesInitialized());
}

TEST(ContentLoaderTest, testReleaseContent) {
	RetrogradeTest::DummyContent::disposed = false;
	RetrogradeTest::TestContentLoader loader;
	loader.requestContent("SomeFile");
	EXPECT_FALSE(RetrogradeTest::DummyContent::disposed);
	loader.releaseContent("SomeFile");
	EXPECT_TRUE(RetrogradeTest::DummyContent::disposed);
}

TEST(ContentLoaderTest, testCacheSize) {
	RetrogradeTest::TestContentLoader loader;
	loader.requestContent("SomeFile");
	loader.requestContent("AnotherFile");
	loader.requestContent("YetAnotherFile");
	EXPECT_EQ(3, loader.cacheSize());
	loader.releaseContent("SomeFile");
	loader.releaseContent("AnotherFile");
	loader.releaseContent("YetAnotherFile");
	EXPECT_EQ(0, loader.cacheSize());
}

}
