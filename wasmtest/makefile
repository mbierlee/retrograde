copy-runtime:
	rm -f ./web/retrograde-runtime.js
	cp -r ../webruntime/retrograde-runtime.js ./web/retrograde-runtime.js

build-wasm: copy-runtime
	dub build --build=debug --compiler=ldc2 --arch=wasm32-unknown-unknown-wasm --build-mode=allAtOnce --combined

run-tests: build-wasm
	cd web && python -m http.server 8080