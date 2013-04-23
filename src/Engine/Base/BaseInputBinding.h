#pragma once

#include "Engine/Framework/IInputBinding.h"

#include <map>

namespace Engine { namespace Base {
	template <class inputIdentifierType>
	class BaseInputBinding
		: public Engine::Framework::IInputBinding<inputIdentifierType>
	{
	private:
		std::map<inputIdentifierType, irr::core::stringc> bindings;

	public:
		virtual void bind(const inputIdentifierType& inputIdentifier, const irr::core::stringc& eventName)
		{
			bindings.insert(std::pair<inputIdentifierType, irr::core::stringc>(inputIdentifier, eventName));
		}

		virtual void unbind(const inputIdentifierType& inputIdentifier)
		{
			bindings.erase(inputIdentifier);
		}

		virtual void unbindAll()
		{
			bindings.clear();
		}

		virtual const irr::core::stringc getBoundEvent(const inputIdentifierType& inputIdentifier) const
		{
			return bindings.at(inputIdentifier);
		}

		virtual bool hasBinding(const inputIdentifierType& inputIdentifier)
		{
			return bindings.count(inputIdentifier) == 1;
		}
	};
}}