.PHONY: local lint build

local: build
	luarocks make --local tableshape-dev-1.rockspec

build: 
	moonc tableshape
 
lint:
	moonc -l tableshape

