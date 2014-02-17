#pragma once

#include "Engine/Loadable.h"

#include <irrString.h>
#include <irrTypes.h>
#include <memory>
#include <map>

namespace Engine { namespace Framework {
	template<class T>
	class IContentLoader {
	protected:
		virtual std::shared_ptr<T> loadContent(const irr::core::stringw& fileName) =0;

	public:
		virtual ~IContentLoader() {}

		virtual bool canLoad(const irr::core::stringw& fileName) =0;
		virtual std::shared_ptr<T> requestContent(const irr::core::stringw& fileName) =0;
		virtual void releaseContent(const irr::core::stringw& fileName) =0;
		virtual irr::u32 cacheSize() =0;
	};
}}
