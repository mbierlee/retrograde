build-lib:
	dub build --config=library

build-runtime:
	dub build --config=runtime

build-wasm:
	dub build --config=wasm --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm --build-mode=allAtOnce --combined

run:
	dub run --config=runtime

copy-wasm:
	mkdir -p ./websource/wasm/; cp ./bin/retrograde.wasm ./websource/wasm/retrograde.wasm

build-wasm-demo: build-wasm copy-wasm