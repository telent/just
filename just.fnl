(local lgi (require :lgi))
(local inspect (require :inspect))

(local Gtk lgi.Gtk)
(local WebKit2 lgi.WebKit2)

(local cache-dir (.. (os.getenv "HOME") "/.cache"))

(local content-filter-store
       (WebKit2.UserContentFilterStore {:path cache-dir}))

(fn named-image [name size]
  (Gtk.Image.new_from_icon_name
   name
   (or size Gtk.IconSize.LARGE_TOOLBAR)))

(fn load-easylist-json [store cb]
  (print "loading easylist from json")
  (with-open [f (io.open "easylist_min_content_blocker.json" "r")]
             (let [blocks (f:read "*a")]
               (store:save "easylist"
                           (lgi.GLib.Bytes blocks)
                           nil
                           (fn [self res]
                             (cb (store:save_finish res)))))))

(fn load-adblocks [content-manager store]
  (store:fetch_identifiers
   nil
   (fn [self res]
     (let [ids (store:fetch_identifiers_finish res)
           found (icollect [_ id (pairs ids)] (= id "easylist"))]
       (if (> (# found) 0)
           (store:load "easylist" nil
                       (fn [self res]
                         (content-manager:add_filter
                          (store:load_finish res))))
           (load-easylist-json
            store
            (fn [filter]
              (content-manager:add_filter filter))))))))


(let [current-url "https://terse.telent.net/admin/stream"
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
      url (doto (Gtk.Entry)
            (: :set_text current-url))
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
      back (doto
               (Gtk.Button {
                            :on_clicked (fn [s]
                                          (if (webview:can_go_back)
                                              (webview:go_back)))
                            })
             (: :set_image (named-image "go-previous")))]
  (load-adblocks webview.user_content_manager content-filter-store)

  (tset url :on_activate (fn [self]
                           (webview:load_uri self.text)))

  (nav-bar:pack_start back false false 2)
  (nav-bar:pack_start url  true true 2)

  (container:pack_start nav-bar false false 5)
  (container:pack_start webview true true 5)

  (webview:load_uri current-url)

  (window:add container)

  (window:show_all))

(Gtk.main)
