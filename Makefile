PKGS = gtk+-2.0 webkit-1.0 unique-1.0
VALACFLAGS = --Xcc=-march=native --Xcc=-O9 --thread --disable-assert
VALACFLAGS += $(shell pkg-config libsoup-2.4 && echo "-D HAVE_SOUP24")

shower: browser.vala app.vala shower.vala
	valac $(VALACFLAGS) $(patsubst %,--pkg=%,$(PKGS)) -o $@ $^

.PHONY: clean

clean:
	rm shower
