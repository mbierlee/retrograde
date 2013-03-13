#pragma once

#include <irrTypes.h>
#include <memory>

namespace Engine {

	template<class T>
	class Loadable {
	private:
		std::shared_ptr<T> content;
		irr::u32 loadCount;

	public:
		Loadable(std::shared_ptr<T> content) 
			: content(content)
			, loadCount(0)
		{
		}

		void increaseLoadCount() {
			++loadCount;
		}

		void decreaseLoadCount() {
			--loadCount;
		}

		const irr::u32& getLoadCount() const {
			return loadCount;
		}

		std::shared_ptr<T> getContent() const {
			return content;
		}
	};

}