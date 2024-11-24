.PHONY: all test_subtype test_typeof test_parsing test_all test_properties

all: test_all

# Testing

JULIA_CMD=julia

test_subtype:
	$(JULIA_CMD) tests/test_subtype.jl

test_properties:
	$(JULIA_CMD) tests/test_properties.jl

test_typeof:
	$(JULIA_CMD) tests/test_typeof.jl

test_parsing:
	$(JULIA_CMD) tests/test_parsing.jl

test_all:
	$(JULIA_CMD) tests/test_all.jl
