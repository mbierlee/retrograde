build-lib:
	dub build --config=library

build-runtime:
	dub build --config=runtime

test:
	dub test