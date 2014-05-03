# browser.py - Browser Main Window
# Benjamin Richter <br@waldteufel.eu>

from gi.repository import GObject, GLib, Gio, Gdk, Gtk, WebKit2, Soup

class BrowserWindow(Gtk.Window):

    def __init__(self):
        Gtk.Window.__init__(self, type=Gtk.WindowType.TOPLEVEL)
        box = Gtk.Box(False, 0)
        box.set_orientation(Gtk.Orientation.VERTICAL)

        self.web = WebKit2.WebView()
        box.pack_start(self.web, True, True, 0)

        self.entry = Gtk.Entry()
        self.entry.set_name('entry')
        self.entry.get_style_context().add_class('small-bar')
        self.entry.connect('activate', self.on_entry_activate)
        self.entry.connect('key-press-event', self.on_entry_keypress)
        box.pack_end(self.entry, False, True, 0)

        self.add(box)
        box.show_all()

        self.web.connect('notify::title', self.on_title)
        self.web.connect('notify::uri', self.on_title)
        self.web.connect('notify::estimated-load-progress', self.on_progress)
        self.web.connect('load-changed', self.on_load_changed)
        self.web.connect('resource-load-started', self.on_resource_load_started)
        self.web.connect('mouse-target-changed', self.on_mouse_target_changed)
        self.web.connect('mouse-target-changed', self.on_mouse_target_changed)
        self.web.connect('button-press-event', self.on_click)
        self.connect('key-press-event', self.on_keypress)

        self.mouse_target = None

    def markup_uri(self):
        uri = self.web.get_uri()
        is_tls, cert, flags = self.web.get_tls_info()
        self.entry.set_text(uri)
        if is_tls:
            assert uri.startswith('https:')
            if flags != 0:
                self.entry.get_layout().set_markup('<span weight="bold" foreground="red" strikethrough="true">https:</span>' + GLib.markup_escape_text(uri[6:]))
            else:
                self.entry.get_layout().set_markup('<span weight="bold" foreground="green" underline="single">https:</span>' + GLib.markup_escape_text(uri[6:]))

    def on_entry_keypress(self, entry, ev):
        if ev.type != Gdk.EventType.KEY_PRESS: return False

        key = ev.keyval
        mod = ev.state & Gtk.accelerator_get_default_mod_mask()

        if key == 0xff1b and mod == 0: # Escape
            self.markup_uri()
            self.web.grab_focus()
            return True

        return False

    def on_entry_activate(self, entry):
        self.web.load_uri(self.entry.get_text())
        self.web.grab_focus()

    def on_load_changed(self, web, ev):
        if not self.entry.has_focus() and ev in (WebKit2.LoadEvent.COMMITTED, WebKit2.LoadEvent.FINISHED):
            self.markup_uri()
        if ev == WebKit2.LoadEvent.FINISHED:
            self.entry.set_progress_fraction(0.0)

    def on_progress(self, web, prop):
        uri = web.get_uri()
        if uri is None or uri == 'about:blank': return
        self.entry.set_progress_fraction(web.get_estimated_load_progress())

    def on_keypress(self, web, ev):
        if ev.type != Gdk.EventType.KEY_PRESS: return False

        key = ev.keyval
        mod = ev.state & Gtk.accelerator_get_default_mod_mask()

        if mod == Gdk.ModifierType.MOD1_MASK: # "Alt"
            if key == 0xff51:
                self.web.go_back()
                return True
            elif key == 0xff53:
                self.web.go_forward()
                return True
        elif mod == Gdk.ModifierType.CONTROL_MASK:
            if key == ord('w'):
                self.destroy()
                return True
            elif key == ord('l'):
                self.entry.grab_focus()
                return True
            elif key == ord('u'):
                if self.web.get_view_mode() == WebKit2.ViewMode.WEB:
                    self.web.set_view_mode(WebKit2.ViewMode.SOURCE)
                else:
                    self.web.set_view_mode(WebKit2.ViewMode.WEB)
                self.web.reload()
                return True
            elif key == ord('r'):
                self.web.reload()
                return True
        return False

    def on_click(self, web, ev):
        if ev.type != Gdk.EventType.BUTTON_PRESS: return False

        if ev.button == 2 and self.mouse_target.context_is_link():
            uri = self.mouse_target.get_link_uri()
            if not uri.startswith('javascript:'):
                window = BrowserWindow()
                window.set_application(self.get_application())
                window.web.load_uri(self.mouse_target.get_link_uri())
                window.show()
                return True
        return False

    def on_title(self, web, prop):
        if web.get_uri() == 'about:blank':
            self.set_title('<blank>')
        else:
            self.set_title(web.get_title() or web.get_uri())

    def on_resource_load_started(self, web, res, req):
        # TODO: adblock here

        hdr = req.get_http_headers()
        if hdr is None: return
        hdr.append('DNT', '1')

        referrer = hdr.get_one('Referer')
        if referrer is not None:
            referrer_uri = Soup.URI(referrer)
            if referrer_uri.get_host() is not None and req.get_uri().get_host() is not None and not req.get_uri().host_equal(referer_uri):
                hdr.remove('Referer')

    def on_mouse_target_changed(self, web, tgt, mod):
        self.mouse_target = tgt
