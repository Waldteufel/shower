using GLib;

class BrowserWindow : Gtk.Window {
   construct { unique_app.watch_window(this); }

   private static Regex scheme_regex;
   private static Regex https_regex;

   static construct {
      try {
         scheme_regex = new Regex("^([^:]+)(:.*)");
         https_regex = new Regex("^https://");
      } catch (RegexError err) {
         assert_not_reached();
      }
   }

   private WebKit.WebView web;

   private Gtk.Container statusbar;
   private Gtk.Label statuslabel;
   private Gtk.Entry cmdentry;
   
   private string last_search = "";

   private void ask_for_url_once_when_loaded() {
      if (web.load_status == WebKit.LoadStatus.FINISHED) {
         stdout.printf("%s\n", web.uri);
         accept_command("", true);
         web.notify["load-status"].disconnect(ask_for_url_once_when_loaded);
      }
   }

   public void load_empty() {
      this.title = "shower";
      this.statuslabel.label = "";
      web.load_string("", "text/plain", "UTF-8", "");
      web.notify["load-status"].connect(ask_for_url_once_when_loaded);
   }

   public BrowserWindow() {
      this.set_default_size(640, 480);

      var vbox = new Gtk.VBox(false, 0);
      web = new WebKit.WebView();
      var scr = new Gtk.ScrolledWindow(null, null);
      scr.add(web);
      vbox.pack_start(scr, true, true, 0);

      var statusbox = new Gtk.HBox(false, 0);
      statusbox.border_width = 2;
      statusbox.name = "statusbox";

      statuslabel = new Gtk.Label(null);
      statuslabel.name = "statuslabel";
      statuslabel.xalign = 0; // left aligned
      statuslabel.ellipsize = Pango.EllipsizeMode.END;
      statuslabel.selectable = true;
      statusbox.pack_end(statuslabel);

      statusbar = new Gtk.EventBox();
      statusbar.name = "statusbar";
      statusbar.add(statusbox);
      vbox.pack_start(statusbar, false, false, 0);

      cmdentry = new Gtk.Entry();
      cmdentry.name = "cmdentry";
      cmdentry.has_frame = false;
      cmdentry.editable = false;
      vbox.pack_start(cmdentry, false, false, 0);

      this.add(vbox);
      vbox.show_all();

      web.notify["title"].connect(() => { this.title = web.title ?? web.uri ?? "shower"; });
      web.notify["uri"].connect(() => { if (is_loading()) cmdentry.text = web.uri ?? ""; });
      web.notify["progress"].connect(() => { cmdentry.set_progress_fraction(web.progress); });
      
      web.notify["uri"].connect(this.show_current_uri);
      web.hovering_over_link.connect(this.show_hovered_link);

      web.notify["load-status"].connect(this.load_status_changed);

      web.create_web_view.connect(this.spawn_view);
      web.close_web_view.connect(() => { this.destroy(); return true; });
      web.console_message.connect(this.handle_console_message);

      web.mime_type_policy_decision_requested.connect(this.handle_mime_type);
      web.download_requested.connect((p0) => { return this.handle_download(p0 as WebKit.Download); });

      cmdentry.activate.connect(() => {
         cmdentry.select_region(0, 0);
         web.grab_focus();
         this.handle_command(cmdentry.text);
      });

      web.button_press_event.connect((press) => {
         if (press.button == 1 && (press.state & Gdk.ModifierType.MODIFIER_MASK) == Gdk.ModifierType.CONTROL_MASK) {
            var linkuri = web.get_hit_test_result(press).link_uri; 
            if (linkuri != null) {
               var new_window = new BrowserWindow();
               new_window.show();
               new_window.load_uri(linkuri);
               return true;
            }
         }
         return false;
      });

      // this.events = this.events | Gdk.EventMask.KEY_PRESS_MASK;
      this.key_press_event.connect(this.key_pressed);
   }

   private bool is_loading() {
      return (web.load_status != WebKit.LoadStatus.FINISHED) && (web.load_status != WebKit.LoadStatus.FAILED);
   }

   private void load_status_changed() {
      if (is_loading()) {
         cmdentry.editable = false;
         last_search = "";
         cmdentry.show();
         statusbar.hide();
      } else {
         cmdentry.hide();
         statusbar.show();
         cmdentry.editable = true;
         cmdentry.set_progress_fraction(0);
      }
   }

   private bool handle_download(WebKit.Download download) {
      var chooser = new Gtk.FileChooserDialog(null, this, Gtk.FileChooserAction.SAVE,
         Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
         Gtk.Stock.SAVE, Gtk.ResponseType.ACCEPT);
      chooser.do_overwrite_confirmation = true;
      chooser.set_current_folder("/tmp");
      chooser.set_current_name(download.suggested_filename);
      if (chooser.run() == Gtk.ResponseType.ACCEPT) {
         download.set_destination_uri(chooser.get_uri());
         chooser.destroy();
         return true;
      } else {
         chooser.destroy();
         return false;
      }
   }

   private bool handle_mime_type(WebKit.WebFrame frame, WebKit.NetworkRequest request, string mimetype, WebKit.WebPolicyDecision decision) {
      if (web.can_show_mime_type(mimetype))
         decision.use();
      else decision.download();
      return true;
   }

   private bool handle_console_message(string msg, int line, string source) {
      stdout.printf("%s:%d: %s\n", source, line, msg);
      return false;
   }

   public void accept_command(string prompt, bool mark) {
      cmdentry.editable = true;
      cmdentry.text = prompt;
      cmdentry.set_progress_fraction(0);
      cmdentry.show();
      statusbar.hide();
      cmdentry.grab_focus();
      if (!mark) cmdentry.set_position(-1);
   }

   public void handle_command(string cmd) {
      if (cmd == "") return;

      if (cmd[0] == '?') {
         this.load_uri("http://www.google.de/search?q=%s".printf(cmd[1:cmd.length]));
      } else if (cmd[0] == '/') {
         last_search = cmd[1:cmd.length];
         web.unmark_text_matches();
         if (last_search == "") {
            web.set_highlight_text_matches(false);
            cmdentry.hide();
            statusbar.show();
         } else {
            web.mark_text_matches(last_search, false, 0);
            web.set_highlight_text_matches(true);
            web.search_text(last_search, false, true, true);
         }
      } else {         
         this.load_uri(cmd);
      }
   }

   private bool key_pressed(Gdk.EventKey press) {
      if (is_loading()) {
         if (press.keyval == 0xff1b) { // GDK_KEY_Escape
            web.stop_loading();
            load_empty();
            return true;
         }
         return false;
      }

      switch (press.state & Gdk.ModifierType.MODIFIER_MASK) {
         case Gdk.ModifierType.CONTROL_MASK:
            switch (press.keyval) {
               case 'l':
                  accept_command(web.uri ?? "", true);
                  return true;
               case 'k':
                  accept_command("?", false);
                  return true;
               case 'f':
                  accept_command("/", false);
                  return true;
               case 'u':
                  web.set_view_source_mode(!web.get_view_source_mode());
                  web.reload();
                  return true;
            }
            break;
         case Gdk.ModifierType.MOD1_MASK:
            switch (press.keyval) {
               case 0xff51: // GDK_KEY_Left
                  web.go_back();
                  return true;
               case 0xff53: // GDK_KEY_Right
                  web.go_forward();
                  return true;
            }
            break;
         case Gdk.ModifierType.SHIFT_MASK:
            switch (press.keyval) {
               case 0xffc0: // GDK_KEY_F3
                  if (last_search != "")
                     web.search_text(last_search, false, false, true);
                  return true;
            }
            break;
         case 0:
            switch (press.keyval) {
               case 0xffc0: // GDK_KEY_F3
                  if (last_search != "")
                     web.search_text(last_search, false, true, true);
                  return true;
            }
            break;
      }
       
      return false;
   }

   private void show_hovered_link(string? title, string? uri) {
      if (uri == null) {
         show_current_uri();
      } else {
         statuslabel.set_markup(Markup.printf_escaped("<span color='cyan'>%s</span>", uri));
      }
   }

   private bool? is_trusted() {
      if (web.uri == null) return null;
      if (!https_regex.match(web.uri)) return null;
      return (web.get_main_frame().get_data_source().get_request().get_message().flags & Soup.MessageFlags.CERTIFICATE_TRUSTED) != 0;
   }

   private void show_current_uri() {
      var uri = web.uri ?? "";
      var trust = is_trusted();

      if (trust != null) {
         MatchInfo match;
         scheme_regex.match(uri, 0, out match);
         
         string color, underline;
         if (trust) {
            color = "green";
            underline = "single";
         } else {
            color = "red";
            underline = "error";
         }

         statuslabel.set_markup(Markup.printf_escaped("<span color='%s' underline='%s'>%s</span>%s", color, underline, match.fetch(1), match.fetch(2)));
      } else {
         statuslabel.set_markup(Markup.escape_text(uri));
      }
   }
   
   private WebKit.WebView spawn_view() {   
      var win = new BrowserWindow();
      win.web.web_view_ready.connect(() => {
         win.show();
         return false;
      });
      return win.web;
   }

   private string normalize_uri(string uri) {
      if (!scheme_regex.match(uri))
         return "http://" + uri;
      else return uri;
   }

   public void load_uri(string uri) {
      this.web.load_uri(normalize_uri(uri));
   }

}
