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
      var browser = new BrowserWindow();
      browser.show();
      if (cmd == " ")
         browser.load_empty();
      else
         browser.handle_command(cmd);
   }

   protected override void initialize() {
      Gtk.rc_parse_string("""
         style "WhiteOnBlack" {
            bg[NORMAL] = "black"
            base[NORMAL] = "black"
            fg[NORMAL] = "lightgray"
            text[NORMAL] = "lightgray"
         }

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

         widget "*cmdentry" style "WhiteOnBlack"
         widget "*statusbar" style "WhiteOnBlack"
         widget "*statuslabel" style "WhiteOnBlack"

         widget "*cmdentry" style "Fixed8"
         widget "*statuslabel" style "Fixed8"
      """);

      var cookiefile = Path.build_filename(Environment.get_user_config_dir(), "shower", "cookies.txt");
      var cookiejar = new Soup.CookieJarText(cookiefile, true);
      cookiejar.accept_policy = Soup.CookieJarAcceptPolicy.NO_THIRD_PARTY;
      WebKit.get_default_session().add_feature(cookiejar);
      WebKit.set_default_web_database_quota(0);
   }

}

Application unique_app;

int main(string[] args) {
   Gtk.init(ref args);
   unique_app = new BrowserApplication();
   return unique_app.run(args);
}
