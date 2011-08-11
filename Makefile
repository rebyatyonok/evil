SHELL = /bin/bash
EMACS = emacs
FILES = $(filter-out evil-tests.el,$(filter-out evil-pkg.el,$(wildcard evil*.el)))
ELPAPKG = evil-`sed -n '3s/.*"\(.*\)".*/\1/p' evil-pkg.el`
TAG =

ELCFILES = $(FILES:.el=.elc)

.PHONY: all compile compile-batch clean tests test emacs term terminal indent elpa version

# Byte-compile Evil.
all: compile
compile: $(ELCFILES)


.depend: $(FILES)
	@echo Compute dependencies
	@rm -f .depend
	@for f in $(FILES); do \
	    sed -n "s/(require '\(evil-.*\))/$${f}c: \1.elc/p" $$f >> .depend;\
	done

-include .depend

$(ELCFILES): %.elc: %.el
	$(EMACS) --batch -Q -L . -L lib -f batch-byte-compile $<

# Byte-compile all files in one batch. This is faster than
# compiling each file in isolation, but also less stringent.
compile-batch: clean
	$(EMACS) --batch -Q -L . -L lib -f batch-byte-compile ${FILES}

# Delete byte-compiled files etc.
clean:
	rm -f *~
	rm -f \#*\#
	rm -f *.elc
	rm -f .depend

# Run tests.
# The TAG variable may specify a test tag or a test name:
#       make test TAG=repeat
# This will only run tests pertaining to the repeat system.
test: clean
	$(EMACS) --batch -Q -L . -L lib -l evil-tests.el \
--eval "(evil-tests-run '(${TAG}))"

# Byte-compile Evil and run all tests.
tests: compile-batch
	$(EMACS) --batch -Q -L . -L lib -l evil-tests.el \
--eval "(evil-tests-run '(${TAG}))"
	rm -f *.elc

# Load Evil in a fresh instance of Emacs and run all tests.
emacs:
	$(EMACS) -Q -L . -L lib -l evil-tests.el --eval "(evil-mode 1)" \
--eval "(if (y-or-n-p-with-timeout \"Run tests? \" 2 t) \
(evil-tests-run '(${TAG}) t) \
(message \"You can run the tests at any time with \`M-x evil-tests-run\'\"))" &

# Load Evil in a terminal Emacs and run all tests.
term: terminal
terminal:
	$(EMACS) -nw -Q -L . -L lib -l evil-tests.el --eval "(evil-mode 1)" \
--eval "(if (y-or-n-p-with-timeout \"Run tests? \" 2 t) \
(evil-tests-run '(${TAG}) t) \
(message \"You can run the tests at any time with \`M-x evil-tests-run\'\"))"

# Re-indent all Evil code.
# Loads Evil into memory in order to indent macros properly.
# Also removes trailing whitespace, tabs and extraneous blank lines.
indent: clean
	$(EMACS) --batch ${FILES} -Q -L . -L lib -l evil-tests.el \
--eval "(dolist (buffer (reverse (buffer-list))) \
(when (buffer-file-name buffer) \
(set-buffer buffer) \
(message \"Indenting %s\" (current-buffer)) \
(setq-default indent-tabs-mode nil) \
(untabify (point-min) (point-max)) \
(indent-region (point-min) (point-max)) \
(delete-trailing-whitespace) \
(untabify (point-min) (point-max)) \
(goto-char (point-min)) \
(while (re-search-forward \"\\n\\\\{3,\\\\}\" nil t) \
(replace-match \"\\n\\n\")) \
(when (buffer-modified-p) (save-buffer 0))))"

# Create an ELPA package.
elpa:
	rm -rf ${ELPAPKG}
	mkdir ${ELPAPKG}
	cp $(FILES) evil-pkg.el ${ELPAPKG}
	tar cf ${ELPAPKG}.tar ${ELPAPKG}
	rm -rf ${ELPAPKG}

# Change the version using make VERSION=x.y.z
version:
	cat evil-pkg.el | sed "3s/\".*\"/\"${VERSION}\"/" > evil-pkg.el

