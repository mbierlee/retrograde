#pragma once

#include "Engine/BindingProperties.h"

#include <irrString.h>

namespace Engine { namespace Framework {
	template <class inputIdentifierType>
	class IInputBinding {
	public:
		virtual ~IInputBinding() {}

		virtual void bind(const inputIdentifierType& inputIdentifier, const irr::core::stringc& eventName, bool isInverted = false) =0;
		virtual void unbind(const inputIdentifierType& inputIdentifier) =0;
		virtual const Engine::BindingProperties getBoundEvent(const inputIdentifierType& inputIdentifier) const =0;
		virtual void unbindAll() =0;
		virtual bool hasBinding(const inputIdentifierType& inputIdentifier) =0;
	};
}}