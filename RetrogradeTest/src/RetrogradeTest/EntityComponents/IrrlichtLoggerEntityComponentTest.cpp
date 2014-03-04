#include "RetrogradeTest/NotPartOfTestException.h"

#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <Engine/EntityComponents/IrrlichtLoggerEntityComponent.h>

#include <ILogger.h>

using ::testing::Return;

namespace RetrogradeTest {
	class LoggerMock
		: public irr::ILogger
	{
	public:
		MOCK_METHOD2(log, void(const wchar_t* text, irr::ELOG_LEVEL logLevel));
		MOCK_METHOD2(log, void(const irr::c8* text, irr::ELOG_LEVEL logLevel));

		virtual void log( const irr::c8* text, const irr::c8* hint, irr::ELOG_LEVEL ll=irr::ELL_INFORMATION )
		{
			throw NotPartOfTestException();
		}

		virtual void log( const irr::c8* text, const wchar_t* hint, irr::ELOG_LEVEL ll=irr::ELL_INFORMATION )
		{
			throw NotPartOfTestException();
		}

		virtual void log( const wchar_t* text, const wchar_t* hint, irr::ELOG_LEVEL ll=irr::ELL_INFORMATION )
		{
			throw NotPartOfTestException();
		}

		virtual irr::ELOG_LEVEL getLogLevel() const
		{
			throw NotPartOfTestException();
		}

		virtual void setLogLevel( irr::ELOG_LEVEL ll )
		{
			throw NotPartOfTestException();
		}
	};

namespace EntityComponents {

TEST(IrrlichtLoggerEntityComponentTest, testComponentFamilyType) {
	Engine::EntityComponents::IrrlichtLoggerEntityComponent irrlichtLoggerEntityComponent(nullptr);
	EXPECT_STREQ("IrrlichtLoggerEntityComponent", Engine::EntityComponents::IrrlichtLoggerEntityComponent::componentType().c_str());
	EXPECT_STREQ("IrrlichtLoggerEntityComponent", Engine::EntityComponents::IrrlichtLoggerEntityComponent::familyType().c_str());
	EXPECT_STREQ("IrrlichtLoggerEntityComponent", irrlichtLoggerEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("IrrlichtLoggerEntityComponent", irrlichtLoggerEntityComponent.getFamilyType().c_str());
}

TEST(IrrlichtLoggerEntityComponentTest, testLogging) {
	RetrogradeTest::LoggerMock logger;

	const irr::c8* testLogInfoSingleByte = "Test Info";
	const wchar_t* testLogErrorWide = L"Test Info";
	const wchar_t* testLogWarningWide = L"Test Warning";

	EXPECT_CALL(logger, log(testLogInfoSingleByte, irr::ELL_INFORMATION))
		.WillOnce(Return());
	EXPECT_CALL(logger, log(testLogErrorWide, irr::ELL_ERROR))
		.WillOnce(Return());
	EXPECT_CALL(logger, log(testLogWarningWide, irr::ELL_WARNING))
		.WillOnce(Return());

	Engine::EntityComponents::IrrlichtLoggerEntityComponent irrlichtLoggerEntityComponent(&logger);
	irrlichtLoggerEntityComponent.log(testLogInfoSingleByte, irr::ELL_INFORMATION);
	irrlichtLoggerEntityComponent.log(testLogErrorWide, irr::ELL_ERROR);
	irrlichtLoggerEntityComponent.log(testLogWarningWide, irr::ELL_WARNING);
}

}}

