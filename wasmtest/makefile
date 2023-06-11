build-wasm:
	dub build --build=debug --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm --build-mode=allAtOnce --combined

run-tests: build-wasm
	cd web && python -m http.server 8080