#pragma once

#include <exception>

namespace RetrogradeTest {

class NotPartOfTestException: public std::exception {

public:
	NotPartOfTestException();
	virtual ~NotPartOfTestException();

	virtual const char* what() const _GLIBCXX_USE_NOEXCEPT {
		return "This code path is not part of the test. Calling it is a mistake in the test";
	}
};

}
