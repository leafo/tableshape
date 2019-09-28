.PHONY: local lint build

local: build
	luarocks make --local --lua-version=5.1 tableshape-dev-1.rockspec

build: 
	moonc tableshape
 
lint:
	moonc -l tableshape

