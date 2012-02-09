using GLib;

abstract class Application : Unique.App {

   public Application(string name) {
      Object(name: name);

      if (!this.is_running) this.initialize();
      
      this.message_received.connect((cmd, data, time) => {
         this.handle_cmd(data.get_text());
         return Unique.Response.OK;
      });
   }

   private int nwindows = 0;

   public new void watch_window(Gtk.Window window) {
      base.watch_window(window);
      ++nwindows;
      window.destroy.connect(this.window_destroyed);
   }

   public void window_destroyed() {
      --nwindows;
      if (nwindows == 0)
         Gtk.main_quit();
   }

   protected abstract void handle_cmd(string cmd);
   protected abstract void initialize();

   public int run(string[] args) {
      var cmd = args.length > 1 ? args[1] : " ";

      if (FileUtils.test(cmd, FileTest.EXISTS)) {
         if (!Path.is_absolute(cmd))
            cmd = Path.build_filename(Environment.get_current_dir(), cmd);
         cmd = "file://" + Uri.escape_string(cmd, "/", true);
      }

      if (!unique_app.is_running) {
         this.handle_cmd(cmd);
         Gtk.main();
         return 0;
      } else {
         var data = new Unique.MessageData();
         data.set_text(cmd, cmd.length);
         if (unique_app.send_message(Unique.Command.OPEN, data) == Unique.Response.OK)
            return 0;
         else
            return 1;
      }
   }
   
}
