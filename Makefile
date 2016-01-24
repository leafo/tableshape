.PHONY: lint build

build: 
	moonc tableshape
 
lint:
	moonc -l tableshape

