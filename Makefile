DESTDIR    ?= $(HOME)/.vim
EDITOR_BIN ?= vim
VADER      ?= .deps/vader.vim

DIRS = plugin autoload autoload/cmakeproject ftplugin syntax doc

.PHONY: all install uninstall helptags test lint

all:
	@echo 'targets: install uninstall helptags test lint'

install:
	@for d in $(DIRS); do mkdir -p "$(DESTDIR)/$$d"; done
	cp plugin/cmake-project.vim    "$(DESTDIR)/plugin/"
	cp autoload/cmakeproject.vim   "$(DESTDIR)/autoload/"
	cp autoload/cmakeproject/*.vim "$(DESTDIR)/autoload/cmakeproject/"
	cp ftplugin/cmakeproject.vim   "$(DESTDIR)/ftplugin/"
	cp syntax/cmakeproject.vim     "$(DESTDIR)/syntax/"
	cp doc/cmake-project.txt       "$(DESTDIR)/doc/"
	$(MAKE) helptags

helptags:
	$(EDITOR_BIN) -Nu NONE -c 'helptags $(DESTDIR)/doc' -c q

uninstall:
	rm -f  "$(DESTDIR)/plugin/cmake-project.vim" \
	       "$(DESTDIR)/ftplugin/cmakeproject.vim" \
	       "$(DESTDIR)/syntax/cmakeproject.vim" \
	       "$(DESTDIR)/autoload/cmakeproject.vim" \
	       "$(DESTDIR)/doc/cmake-project.txt" \
	       "$(DESTDIR)/doc/tags"
	rm -rf "$(DESTDIR)/autoload/cmakeproject"

$(VADER):
	git clone --depth 1 https://github.com/junegunn/vader.vim $(VADER)

test: $(VADER)
	@if [ "$(EDITOR_BIN)" = "nvim" ]; then \
	    $(EDITOR_BIN) --headless -Nu test/vimrc -c 'Vader! test/*.vader'; \
	else \
	    $(EDITOR_BIN) -Nu test/vimrc -i NONE --not-a-term -es -c 'Vader! test/*.vader'; \
	fi

lint:
	vint --style-problem plugin autoload ftplugin syntax
