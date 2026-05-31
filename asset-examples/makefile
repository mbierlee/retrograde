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

all: cube.rgm cube-nomat.rgm cube-vertexcolors.rgm test1024.rgi

cube.rgm: cube.glb
	$(RGMODELCONV) -i cube.glb -o cube.rgm

cube-nomat.rgm: cube-nomat.glb
	$(RGMODELCONV) -i cube-nomat.glb -o cube-nomat.rgm

cube-vertexcolors.rgm: cube-vertexcolors.glb
	$(RGMODELCONV) -i cube-vertexcolors.glb -o cube-vertexcolors.rgm

test1024.rgi: test1024.bmp
	$(RGIMAGECONV) -i test1024.bmp -o test1024.rgi

clean:
	$(RM) cube.rgm cube-nomat.rgm cube-vertexcolors.rgm test1024.rgi
