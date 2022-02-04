(local lgi (require :lgi))
(local inspect (require :inspect))

(local Gtk lgi.Gtk)
(local WebKit2 lgi.WebKit2)

(let [current-url "about:blank"
      window (Gtk.Window {
                          :title "Just browsing"
                          :default_width 800
                          :default_height 600
                          :on_destroy Gtk.main_quit
                          })
      container (Gtk.Box {
                          :orientation Gtk.Orientation.VERTICAL
                          })
      nav-bar (Gtk.Box {
                        :orientation Gtk.Orientation.HORIZONTAL
                        })
      webview (WebKit2.WebView)
      back (Gtk.Button {
                        :label "<-"
                        })
      url (doto (Gtk.Entry) (: :set_text current-url))]

  (nav-bar:pack_start back false false 5)
  (nav-bar:pack_start url  true true 5)

  (container:pack_start nav-bar false false 5)
  (container:pack_start webview true true 5)


  (webview:load_uri current-url)

  (window:add container)

  (window:show_all))

(Gtk.main)
