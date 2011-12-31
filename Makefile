PKGS = gtk+-2.0 webkit-1.0 unique-1.0 libsoup-2.4
VALACFLAGS = --Xcc=-march=native --Xcc=-O9 --thread

shower: browser.vala app.vala shower.vala
	valac $(VALACFLAGS) $(patsubst %,--pkg=%,$(PKGS)) -o $@ $^

.PHONY: clean

clean:
	rm shower
