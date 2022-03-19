FENNEL?=$(fennel)
PREFIX?=/usr/local

PROGRAM_NAME=just
MAIN=$(PROGRAM_NAME).fnl
SOURCES=$(MAIN) listeners.fnl viewplex.fnl webview.fnl

$(PROGRAM_NAME): $(SOURCES) Makefile
	(echo -e "#!/usr/bin/env lua\n" ; \
	: we reset package.path so that --require-as-include cannot find ; \
	: and inline third-party modules ; \
	lua -e 'package.path="./?.lua"' $(FENNEL) --require-as-include --compile $(MAIN) ) > $@
	chmod +x $@

install:
	mkdir -p $(PREFIX)/bin $(PREFIX)/lib/$(PROGRAM_NAME)
	cp $(PROGRAM_NAME) $(PREFIX)/bin
#	cp interface.xml styles.css $(PREFIX)/lib/$(PROGRAM_NAME)

test:
	for i in *-test.fnl ; do lua $(fennel) $$i; done

easylist.txt:
	curl https://easylist.to/easylist/easylist.txt -O
