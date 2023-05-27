build-lib:
	dub build --config=library

build-runtime:
	dub build --config=runtime

run:
	dub run --config=runtime