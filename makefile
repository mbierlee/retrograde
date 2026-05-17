build-lib:
	dub build --config=library

test-native:
	dub test --config=unittest-native

build-rgmodelconv-release:
	cd tools/rgmodelconv && dub build --build=release

build-rgimageconv-release:
	cd tools/rgimageconv && dub build --build=release

build-rgassetinfo-release:
	cd tools/rgassetinfo && dub build --build=release