#pragma once

#include "Engine/Framework/IInputBinding.h"

#include <map>
#include <vector>

namespace Engine {
namespace Base {

template<class inputIdentifierType>
class BaseInputBinding: public Engine::Framework::IInputBinding<inputIdentifierType> {
private:
	std::map<inputIdentifierType, Engine::BindingProperties> bindings;

public:
	virtual ~BaseInputBinding() {
	}

	virtual void bind(const inputIdentifierType& inputIdentifier, const irr::core::stringc& eventName, bool isInverted = false) override {
		Engine::BindingProperties properties(eventName, isInverted);
		bindings.insert(std::pair<inputIdentifierType, Engine::BindingProperties>(inputIdentifier, properties));
	}

	virtual void unbind(const inputIdentifierType& inputIdentifier) override {
		bindings.erase(inputIdentifier);
	}

	virtual void unbindAll() override {
		bindings.clear();
	}

	virtual const Engine::BindingProperties getBoundEvent(const inputIdentifierType& inputIdentifier) const override {
		return bindings.at(inputIdentifier);
	}

	virtual bool hasBinding(const inputIdentifierType& inputIdentifier) override {
		return bindings.count(inputIdentifier) == 1;
	}
};

}
}
