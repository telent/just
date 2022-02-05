(local lgi (require :lgi))
(local inspect (require :inspect))

(local Gtk lgi.Gtk)
(local WebKit2 lgi.WebKit2)

(let [current-url "https://terse.telent.net"
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
      url (doto (Gtk.Entry) (: :set_text current-url))
      webview (WebKit2.WebView {
                                :on_notify
                                (fn [self pspec c]
                                  (if (= pspec.name "uri")
                                      (url:set_text self.uri)
                                      (and (= pspec.name "title")
                                           (> (# self.title) 0))
                                      (window:set_title
                                       (.. self.title " - Just browsing"))
                                      ))
                                })
      back (Gtk.Button {
                        :label "<-"
                        :on_clicked (fn [s]
                                      (if (webview:can_go_back)
                                          (webview:go_back)))
                        })]


  (nav-bar:pack_start back false false 5)
  (nav-bar:pack_start url  true true 5)

  (container:pack_start nav-bar false false 5)
  (container:pack_start webview true true 5)

  (webview:load_uri current-url)

  (window:add container)

  (window:show_all))

(Gtk.main)
