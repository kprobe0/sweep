PREFIX ?= $(HOME)/.local

.PHONY: install test

install:
	mkdir -p $(PREFIX)/bin
	install -m 755 sweep $(PREFIX)/bin/sweep

test:
	bash test/test_sweep.sh
