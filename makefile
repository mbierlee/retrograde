.PHONY: lib test-native rgmodelconv-release rgimageconv-release rgassetinfo-release tools

lib:
	dub build --config=library

test-native:
	dub test --config=unittest-native

rgmodelconv-release:
	cd tools/rgmodelconv && dub build --build=release

rgimageconv-release:
	cd tools/rgimageconv && dub build --build=release

rgassetinfo-release:
	cd tools/rgassetinfo && dub build --build=release

tools: rgmodelconv-release rgimageconv-release rgassetinfo-release