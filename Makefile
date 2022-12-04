FENNEL?=$(fennel)
PREFIX?=/usr/local

PROGRAM_NAME=just

$(PROGRAM_NAME):

install:
	mkdir -p $(PREFIX)/bin $(PREFIX)/lib/$(PROGRAM_NAME)
	cp *.fnl $(PREFIX)/lib/$(PROGRAM_NAME)
#	cp interface.xml styles.css $(PREFIX)/lib/$(PROGRAM_NAME)

test:
	for i in *-test.fnl ; do lua $(fennel) $$i; done

easylist.txt:
	curl https://easylist.to/easylist/easylist.txt -O
