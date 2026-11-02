PREFIX ?= $(HOME)/.local

.PHONY: install test lint

install:
	mkdir -p $(PREFIX)/bin
	install -m 755 sweep $(PREFIX)/bin/sweep

test:
	bash test/test_sweep.sh

lint:
	shellcheck -s bash sweep install.sh
