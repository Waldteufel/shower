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
         browser.accept_command("", true);
      else
         browser.handle_command(cmd);
   }

}

void init_style() {
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

      class "GtkScrolledWindow" style "NoSpace"

      widget "*cmdentry" style "WhiteOnBlack"
      widget "*statusbar" style "WhiteOnBlack"
      widget "*status_left" style "WhiteOnBlack"
      widget "*status_right" style "WhiteOnBlack"

      widget "*cmdentry" style "Fixed8"
      widget "*status_left" style "Fixed8"
      widget "*status_right" style "Fixed8"
   """);
}

Application unique_app;

int main(string[] args) {
   Gtk.init(ref args);
   init_style();

   unique_app = new BrowserApplication();
   return unique_app.run(args);
}
