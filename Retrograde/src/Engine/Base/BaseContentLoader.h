#pragma once

#include "Engine/Framework/IContentLoader.h"
#include "Engine/Base/NotImplementedException.h"

namespace Engine { namespace Base {
	template<class T>
	class BaseContentLoader
		: public Engine::Framework::IContentLoader<T>
	{
	private:
		typedef typename std::map<irr::core::stringw, Engine::Loadable<T>>::iterator LoadedContentIterator;
		std::map<irr::core::stringw, Engine::Loadable<T>> loadedContent;

	protected:
		virtual std::shared_ptr<T> loadContent(const irr::core::stringw& fileName) {
			throw Engine::Base::NotImplementedException("Content loader provides no implementation for loading its content.");
		}

	public:
		virtual ~BaseContentLoader(){};

		virtual std::shared_ptr<T> requestContent(const irr::core::stringw& fileName) {
			LoadedContentIterator it;
			it = loadedContent.find(fileName);
			if (it != loadedContent.end()) {
				auto loadable = it->second;
				loadable.increaseLoadCount();
				return loadable.getContent();
			} else {
				Loadable<T> loadable(loadContent(fileName));
				loadable.increaseLoadCount();
				loadedContent.insert(std::pair<irr::core::stringw, Engine::Loadable<T>>(fileName, loadable));
				return loadable.getContent();
			}
		}

		virtual void releaseContent(const irr::core::stringw& fileName) {
			LoadedContentIterator it;
			it = loadedContent.find(fileName);
			if (it != loadedContent.end()) {
				Engine::Loadable<T> loadable = it->second;
				loadable.decreaseLoadCount();

				if (loadable.getLoadCount() <= 0) {
					loadedContent.erase(fileName);
				}
			}
		}

		virtual irr::u32 cacheSize()
		{
			return loadedContent.size();
		}
	};
}}
