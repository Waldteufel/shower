/***************************
 * Shower: Eine Web-Brause *
 * Benjamin Richter        *
 * <br@waldteufel.eu>      *
 ***************************/

using GLib;

class BrowserApplication : Application {

   public BrowserApplication() {
      base("eu.waldteufel.shower");
   }

   protected override void handle_cmd(string cmd) {
      var browser = new BrowserWindow(cmd);
      browser.show();
   }

   protected override void initialize() {
      Gtk.rc_parse_string("""
         style "Fixed8" {
            font_name = "Fixed 8"
         }

         style "NoSpace" {
            GtkScrolledWindow::scrollbar-spacing = 0
         }

         style "Border2" {
            GtkContainer::border-width = 2
         }

         class "GtkScrolledWindow" style "NoSpace"

         widget "*statusbox" style "Border2"

         widget "*cmdentry" style "Fixed8"
         widget "*statuslabel" style "Fixed8"
      """);

      var cookiefile = Path.build_filename(Environment.get_user_config_dir(), "shower", "cookies.txt");
      var cookiejar = new Soup.CookieJarText(cookiefile, true);
      cookiejar.accept_policy = Soup.CookieJarAcceptPolicy.NO_THIRD_PARTY;

      var session = WebKit.get_default_session();
      session.ssl_strict = false;
      session.ssl_use_system_ca_file = true;
      session.add_feature(cookiejar);

      var datadir = Path.build_filename(Environment.get_user_data_dir(), "webkit");
      DirUtils.create(datadir, 0000);
      FileUtils.chmod(datadir, 0000);
   }

}

BrowserApplication unique_app;

int main(string[] args) {
   Gtk.init(ref args);
   unique_app = new BrowserApplication();
   return unique_app.run(args);
}
