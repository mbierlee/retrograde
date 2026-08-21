ifeq ($(OS),Windows_NT)
	RGMODELCONV := ..\tools\rgmodelconv\bin\rgmodelconv.exe
	RGIMAGECONV := ..\tools\rgimageconv\bin\rgimageconv.exe
	RM := del /Q
else
	RGMODELCONV := ../tools/rgmodelconv/bin/rgmodelconv
	RGIMAGECONV := ../tools/rgimageconv/bin/rgimageconv
	RM := rm -f
endif

.PHONY: all clean

all: cube-nomat.rgm cube-vertexcolors.rgm cube-unlit-textured.rgm cube-pbr.rgm cube-lambert.rgm test1024.rgi

cube-nomat.rgm: cube-nomat.gltf
	$(RGMODELCONV) -i cube-nomat.gltf -o cube-nomat.rgm

cube-vertexcolors.rgm: cube-vertexcolors.gltf
	$(RGMODELCONV) -i cube-vertexcolors.gltf -o cube-vertexcolors.rgm

cube-unlit-textured.rgm: cube-unlit-textured.gltf
	$(RGMODELCONV) -i cube-unlit-textured.gltf -o cube-unlit-textured.rgm

cube-pbr.rgm: cube-pbr.gltf
	$(RGMODELCONV) -i cube-pbr.gltf -o cube-pbr.rgm

cube-lambert.rgm: cube-lambert.gltf
	$(RGMODELCONV) -i cube-lambert.gltf -o cube-lambert.rgm

test1024.rgi: test1024.png
	$(RGIMAGECONV) -i test1024.png -o test1024.rgi

clean:
	$(RM) cube-nomat.rgm cube-vertexcolors.rgm cube-unlit-textured.rgm cube-pbr.rgm cube-lambert.rgm test1024.rgi
