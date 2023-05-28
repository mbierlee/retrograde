build-lib:
	dub build --config=library

build-runtime:
	dub build --config=runtime

test-native:
	dub test --config=unittest-native