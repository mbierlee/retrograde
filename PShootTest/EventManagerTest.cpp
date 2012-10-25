#include "stdafx.h"
#include "CppUnitTest.h"

#include "Engine/EventManager.h"
#include "Engine/Framework/IEventObserver.h"

#include <memory>

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace PShootTest
{
	class TestObserver 
		: public Engine::Framework::IEventObserver
	{
	public:
		virtual void handleEvent( Engine::Framework::IEvent& event, void* source ) {}
	};


	TEST_CLASS(EventManagerTest) 
	{
	public:
		TEST_METHOD(RegisterObserverTest) {
			std::shared_ptr<TestObserver> testObserver = std::make_shared<TestObserver>();
			Engine::EventManager eventManager;

			eventManager.registerObserver(testObserver);
			Assert::IsTrue(eventManager.hasObserver(testObserver));
		}

		TEST_METHOD(UnregisterObserverTest) {
			std::shared_ptr<TestObserver> testObserver = std::make_shared<TestObserver>();
			Engine::EventManager eventManager;

			eventManager.registerObserver(testObserver);
			eventManager.unregisterObserver(testObserver);
			Assert::IsFalse(eventManager.hasObserver(testObserver));
		}
	};

}