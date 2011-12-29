using GLib;

abstract class Application : Unique.App {

   public Application(string name) {
      Object(name: name);
      
      this.message_received.connect((cmd, data, time) => {
         this.handle_cmd(data.get_text());
         return Unique.Response.OK;
      });
   }

   private int nwindows = 0;

   public new void watch_window(Gtk.Window window) {
      base.watch_window(window);
      ++nwindows;
      window.destroy.connect(() => {
         --nwindows;
         if (nwindows == 0)
            Gtk.main_quit();
      });
   }

   protected abstract void handle_cmd(string cmd);

   public int run(string[] args) {
      var cmd = args.length > 1 ? args[1] : " ";

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
