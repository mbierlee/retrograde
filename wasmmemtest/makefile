build-wasm:
	dub build --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm --build-mode=allAtOnce --combined --build=release

run-tests: build-wasm
	cd web && python -m http.server 8080