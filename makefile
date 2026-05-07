build-lib:
	dub build --config=library

test-native:
	dub test --config=unittest-native

build-rgmodelconv-release:
	cd tools/rgmodelconv && dub build --build=release