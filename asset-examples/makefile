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

all: cube.rgm test1024.rgi

cube.rgm: cube.glb
	$(RGMODELCONV) -i cube.glb -o cube.rgm

test1024.rgi: test1024.bmp
	$(RGIMAGECONV) -i test1024.bmp -o test1024.rgi

clean:
	$(RM) cube.rgm test1024.rgi
