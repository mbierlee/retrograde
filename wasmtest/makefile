copy-runtime:
	rm -rf ./web/lib/*
	cp -r ../webruntime/src/* ./web/lib

build-wasm: copy-runtime
	dub build --build=debug --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm --build-mode=allAtOnce --combined

run-tests: build-wasm
	cd web && python -m http.server 8080