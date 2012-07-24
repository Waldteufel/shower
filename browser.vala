using GLib;

class BrowserWindow : Gtk.Window {
   construct { unique_app.watch_window(this); }

   private static Regex scheme_regex;
   private static Regex https_regex;
   private static Regex anchor_regex;

   private static string anchor_path;
   private static string adblock_path;

   private static string error_tpl = "<pre><span style='padding: .1em; background-color: red; color: white'>E%d</span> %s</pre>";

   static construct {
      anchor_path = Path.build_filename(Environment.get_user_config_dir(), "shower", "anchors");
      adblock_path = Path.build_filename(Environment.get_user_config_dir(), "shower", "adblock");

      try {
         scheme_regex = new Regex("^([^:]+)(:.*)");
         https_regex = new Regex("^https://");
         anchor_regex = new Regex("^#(\\S+)\\s*(.*)");
      } catch (RegexError err) {
         assert_not_reached();
      }
   }

   private WebKit.WebView web;
   private Gtk.Container statusbar;
   private Gtk.Label statuslabel;
   private Gtk.Entry cmdentry;

   private KeyFile anchors;
   private Regex adblock;

   public bool tainted = false;

   abstract class Mode : Object {
      public weak BrowserWindow browser { get; construct; }

      protected abstract void enter();
      construct { this.enter(); }

      public virtual bool key_pressed(Gdk.ModifierType modif, uint key) {
         switch (modif) {
            case Gdk.ModifierType.CONTROL_MASK:
               switch (key) {
                  case 'w':
                     browser.destroy();
                     return true;
                  case 0xff67: // GDK_KEY_Menu
                     browser.load_uri("file://" + Path.build_filename(Environment.get_user_config_dir(), "shower", "dashboard.html"));
                     return true;
               }
               break;
            case Gdk.ModifierType.MOD1_MASK:
               switch (key) {
                  case 0xff51: // GDK_KEY_Left
                     browser.web.go_back();
                     return true;
                  case 0xff53: // GDK_KEY_Right
                     browser.web.go_forward();
                     return true;
               }
               break;
         }
         return false;
      }
   }

   abstract class NonLoadMode : Mode {
      public override bool key_pressed(Gdk.ModifierType modif, uint key) {
         switch (modif) {
            case Gdk.ModifierType.CONTROL_MASK:
               switch (key) {
                  case 'l':
                     browser.mode = new CommandMode.start_with(browser, browser.get_current_uri());
                     return true;
                  case 'r':
                     browser.web.reload();
                     return true;
                  case 'k':
                     browser.mode = new CommandMode.prompt(browser, "#? ");
                     return true;
                  case 'f':
                     browser.mode = new CommandMode.prompt(browser, "/");
                     return true;
                  case '#':
                     browser.mode = new CommandMode.prompt(browser, "#");
                     return true;
                  case 'u':
                     browser.web.set_view_source_mode(!browser.web.get_view_source_mode());
                     browser.web.reload();
                     return true;
               }
               break;
            case 0:
               if (key == 0xff1b) { // GDK_KEY_Escape
                  browser.mode = new InteractMode(browser);
                  return true;
               }
               break;
         }
         return base.key_pressed(modif, key);
      }
   }

   class InteractMode : NonLoadMode {
      public InteractMode(BrowserWindow browser) {
         Object(browser: browser);
      }

      protected override void enter() {
         browser.web.grab_focus();
         browser.cmdentry.hide();
         browser.statusbar.show();
         browser.show_uri_and_title();

         browser.web.unmark_text_matches();
         browser.web.set_highlight_text_matches(false);
      }
   }

   class FindMode : InteractMode {
      public string search { get; construct; }

      public FindMode(BrowserWindow browser, string search) {
         Object(browser: browser, search: search);
      }

      protected override void enter() {
         base.enter();
         browser.web.mark_text_matches(search, false, 0);
         browser.web.set_highlight_text_matches(true);
         browser.web.search_text(search, false, true, true);
      }

      public override bool key_pressed(Gdk.ModifierType modif, uint key) {
         switch (modif) {
            case Gdk.ModifierType.SHIFT_MASK:
               switch (key) {
                  case 0xffc0: // GDK_KEY_F3
                     if (search != "")
                        browser.web.search_text(search, false, false, true);
                     return true;
               }
               break;
            case 0:
               switch (key) {
                  case 0xffc0: // GDK_KEY_F3
                     if (search != "")
                        browser.web.search_text(search, false, true, true);
                     return true;
               }
               break;
         }
         return base.key_pressed(modif, key);
      }
   }

   class LoadMode : Mode {
      public LoadMode(BrowserWindow browser) {
         Object(browser: browser);
      }

      protected override void enter() {
         browser.cmdentry.editable = false;
         browser.statusbar.hide();
         browser.cmdentry.text = browser.get_current_uri();
         browser.cmdentry.show();
         browser.web.grab_focus();
         browser.cmdentry.select_region(0, 0);
      }

      public override bool key_pressed(Gdk.ModifierType modif, uint key) {
         if (modif == 0 && key == 0xff1b) {
            browser.web.stop_loading();
            return true;
         }
         return base.key_pressed(modif, key);
      }
   }

   class DownloadMode : Mode {
      public WebKit.Download download { get; construct; }
      public DownloadMode(BrowserWindow browser, WebKit.Download dl) {
         Object(browser: browser, download: dl);
      }

      protected override void enter() {
         browser.cmdentry.editable = false;
         browser.statusbar.hide();
         browser.cmdentry.show();
         browser.cmdentry.select_region(0, 0);

         download.notify["progress"].connect(this.update_progress);
         download.error.connect(this.handle_error);
      }

      private bool handle_error(int code, int detail, string reason) {
         var dialog = new Gtk.MessageDialog(browser, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.OK, "%s", reason);
         dialog.title = "Download";
         dialog.run();
         dialog.destroy();
         browser.mode = new InteractMode(browser);
         return false;
      }

      private void update_progress() {
         browser.cmdentry.text = download.get_uri();
         browser.cmdentry.set_progress_fraction(download.progress);

         if (download.progress == 1)
            browser.mode = new InteractMode(browser);
      }

      public override bool key_pressed(Gdk.ModifierType modif, uint key) {
         if (modif == 0 && key == 0xff1b) {
            download.cancel();
            return true;
         }
         return base.key_pressed(modif, key);
      }
   }

   class CommandMode : NonLoadMode {
      public CommandMode(BrowserWindow browser) {
         Object(browser: browser);
      }

      protected override void enter() {
         browser.cmdentry.editable = true;
         browser.cmdentry.set_progress_fraction(0);
         browser.cmdentry.text = "";
         browser.statusbar.hide();
         browser.cmdentry.show();
         browser.cmdentry.grab_focus(); 
      }

      public CommandMode.start_with(BrowserWindow browser, string init) {
         Object(browser: browser);
         browser.cmdentry.text = init;
         browser.cmdentry.select_region(0, -1);
      }

      public CommandMode.prompt(BrowserWindow browser, string prompt) {
         Object(browser: browser);
         browser.cmdentry.text = prompt;
         browser.cmdentry.set_position(-1);
      }
   }

   private Mode mode;

   public BrowserWindow(string initial_cmd = " ") {
      // read anchors file

      anchors = new KeyFile();
      try {
         anchors.load_from_file(anchor_path, KeyFileFlags.NONE);
      } catch (FileError err) {
         stderr.printf("Could not open anchor file at %s\n", anchor_path);
      } catch (KeyFileError err) {
         stderr.printf("Malformed anchor file at %s\n", anchor_path);
      }


      // read blocklist

      try {
         string text;
         FileUtils.get_contents(adblock_path, out text);
         adblock = new Regex(text, RegexCompileFlags.EXTENDED | RegexCompileFlags.OPTIMIZE | RegexCompileFlags.NO_AUTO_CAPTURE);
      } catch (FileError err) {
         stderr.printf("Could not open adblock file at %s\n", adblock_path);
      } catch (RegexError err) {
         stderr.printf("Malformed adblock file at %s\n", adblock_path);
      }


      // create GUI

      this.set_default_size(640, 480);
      this.set_icon_name("applications-internet");

      var vbox = new Gtk.VBox(false, 0);

      web = new WebKit.WebView();

      var st = web.get_settings();
      st.enable_dns_prefetching = false;
      st.user_stylesheet_uri = "file://" + Path.build_filename(Environment.get_user_config_dir(), "shower", "style.css");

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

      web.notify["title"].connect(this.show_uri_and_title);
      web.notify["uri"].connect(this.show_uri_and_title);

      web.notify["progress"].connect(() => { cmdentry.set_progress_fraction(web.progress); });

      web.notify["uri"].connect(this.show_uri_and_title);
      web.hovering_over_link.connect(this.show_hovered_link);

      web.notify["load-status"].connect(this.load_status_changed);

      web.create_web_view.connect(this.spawn_view);
      web.console_message.connect(this.handle_console_message);

      web.mime_type_policy_decision_requested.connect(this.handle_mime_type);
      web.download_requested.connect((p0) => { return this.handle_download(p0 as WebKit.Download); });

      web.resource_request_starting.connect(this.filter_requests);

      cmdentry.activate.connect(() => { this.handle_command(cmdentry.text); });

      statusbar.enter_notify_event.connect(() => {
         this.show_uri_and_title();
         return true;
      });

      web.button_press_event.connect(this.handle_click);
      web.load_error.connect(this.load_error);

      this.key_press_event.connect((press) => {
         return mode.key_pressed((press.state & Gtk.accelerator_get_default_mod_mask()), press.keyval);
      });

      if (initial_cmd == " ")
         this.mode = new CommandMode(this);
      else
         this.handle_command(initial_cmd);
   }

   public string get_current_uri() {
      if (web.load_status == WebKit.LoadStatus.FAILED) {
         string uri = web.get_main_frame().get_data_source().get_unreachable_uri();
         if (uri != null) return uri;
      }

      if (web.load_status != WebKit.LoadStatus.FINISHED) {
         var ds = web.get_main_frame().get_provisional_data_source();
         if (ds != null)
            return ds.get_request().uri;
      }

      return web.uri ?? "";
   }

   private bool handle_click(Gdk.EventButton press) {
      var modif = press.state & Gtk.accelerator_get_default_mod_mask();
      if (modif == Gdk.ModifierType.CONTROL_MASK && press.button == 1) {
         var linkuri = web.get_hit_test_result(press).link_uri;
         if (linkuri != null && !linkuri.has_prefix("javascript:")) {
            var win = new BrowserWindow(linkuri);
            win.show();
            return true;
         }
      }
      return false;
   }

   private bool load_error(WebKit.WebView view, WebKit.WebFrame frame, string uri, Error err) {
      if (err.code == WebKit.PluginError.WILL_HANDLE_LOAD) {
         return false;
      } else {
         frame.load_alternate_string(Markup.printf_escaped(error_tpl, err.code, err.message), uri, uri);
         return true;
      }
   }

   private void filter_requests(WebKit.WebFrame frame, WebKit.WebResource resource, WebKit.NetworkRequest req, WebKit.NetworkResponse? resp) {
      if (req.message == null) return;

      req.message.request_headers.append("DNT", "1");

      if (adblock != null && adblock.match(req.message.uri.to_string(false)))
         req.message.uri = new Soup.URI("about:blank");

      var referer = req.message.request_headers.get_one("Referer");
      if (referer != null) {
         var referer_uri = new Soup.URI(referer);
         if (referer_uri.host != null && req.message.uri.host != null && !req.message.uri.host_equal(referer_uri))
            req.message.request_headers.remove("Referer");
      }
   }

   private void load_status_changed() {
      if (mode is DownloadMode)
         return;

      switch (web.load_status) {
         case WebKit.LoadStatus.PROVISIONAL:
            mode = new LoadMode(this);
            if (tainted) {
               stdout.printf("TAINTED: %s\n", get_current_uri());
               if (adblock != null && adblock.match(get_current_uri()))
                  this.destroy();
            }
            break;

         case WebKit.LoadStatus.COMMITTED:
            if (get_current_uri() != "about:blank") {
               tainted = false;
               this.show();
            }
            break;

         case WebKit.LoadStatus.FINISHED:
         case WebKit.LoadStatus.FAILED:
            mode = new InteractMode(this);
            break;

         default:
            /* nothing */
            break;
      }
   }

   private bool handle_download(WebKit.Download download) {
      var filename = Path.get_basename(download.suggested_filename);
      var dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO, "%s", filename);
      dialog.title = "Download?";
      if (dialog.run() == Gtk.ResponseType.YES) {
         dialog.destroy();
         download.set_destination_uri("file://" + Path.build_filename("/tmp", filename));
         mode = new DownloadMode(this, download);
         return true;
      } else {
         dialog.destroy();
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
      return true;
   }

   public void follow_anchor(string name, string arg) {
      try {
         string subst = anchors.get_string("Anchors", name);
         this.load_uri(subst.printf(Uri.escape_string(arg, "", true)));
      } catch (KeyFileError err) {
         this.load_uri(arg);
      }
   }

   public void handle_command(string cmd) {
      if (cmd == "") {
         this.mode = new InteractMode(this);
      } else if (cmd[0] == '/') {
         this.mode = new FindMode(this, cmd[1:cmd.length]);
      } else if (cmd[0] == '#') {
         MatchInfo match;
         anchor_regex.match(cmd, 0, out match);
         follow_anchor(match.fetch(1), match.fetch(2));
      } else if (cmd.contains(" ")) {
         follow_anchor("?", cmd);
      } else {
         this.load_uri(normalize_uri(cmd));
      }
   }

   private void show_hovered_link(string? title, string? uri) {
      if (uri == null)
         show_uri_and_title();
      else
         statuslabel.set_markup(Markup.printf_escaped("<span color='cyan'>%s</span>", uri));
   }

   private bool? is_trusted() {
      var request = web.get_main_frame().get_data_source().get_request();

      if (request == null)
         return null;

      var msg = request.get_message();

      if (msg == null)
         return null;

      return (msg.flags & Soup.MessageFlags.CERTIFICATE_TRUSTED) != 0;
   }

   private void show_uri_and_title() {
      string current_uri = get_current_uri();

      if (https_regex.match(current_uri)) {
         MatchInfo match;
         scheme_regex.match(current_uri, 0, out match);

         string color, underline;
         var trust = is_trusted();

         if (trust == null) {
            color = "darkgray";
            underline = "error";
         } else if (trust) {
            color = "green";
            underline = "single";
         } else {
            color = "red";
            underline = "error";
         }

         statuslabel.set_markup(Markup.printf_escaped("<span color='%s' underline='%s'>%s</span>%s", color, underline, match.fetch(1), match.fetch(2)));
      } else {
         statuslabel.set_markup(Markup.escape_text(current_uri));
      }

      this.title = web.title ?? current_uri;
   }

   private WebKit.WebView spawn_view() {   
      var win = new BrowserWindow();
      win.tainted = true;
      return win.web;
   }

   private string normalize_uri(string uri) {
      if (!scheme_regex.match(uri))
         return "http://" + uri;
      else return uri;
   }

   public void load_uri(string uri) {
      this.web.load_uri(uri);
   }

}
