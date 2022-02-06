(local lgi (require :lgi))
(local inspect (require :inspect))

(local Gtk lgi.Gtk)
(local WebKit2 lgi.WebKit2)

(local cache-dir (.. (os.getenv "HOME") "/.cache"))

(local content-filter-store
       (WebKit2.UserContentFilterStore {:path cache-dir}))

(fn event-bus []
  (let [subscriptions {}
        vivify (fn [n v]
                 (or (. n v)
                     (do (tset n v {}) (. n v))))]
    {
     :subscriptions subscriptions
     :subscribe (fn [self event-name handler]
                  (table.insert (vivify subscriptions event-name) handler))
     :publish (fn [self event-name payload]
                (each [_ handler (pairs (. subscriptions event-name))]
                  (handler payload)))
     :unsubscribe (fn [self event-name handler]
                    (table.remove (. subscriptions event-name) handler))
     }))


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

(let [css "
progress, trough {
  max-height: 6px;
  color: #4444bb;
}
"
      style_provider (Gtk.CssProvider)]
  (style_provider:load_from_data css)
  (Gtk.StyleContext.add_provider_for_screen
   (lgi.Gdk.Screen.get_default)
   style_provider
   Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
   ))


(fn handle-webview-properties [self pspec bus]
  (match pspec.name
    "uri"
    (bus:publish :url-changed self.uri)

    "title"
    (if (> (self.title:len) 0)
        (bus:publish :title-changed self.title))

    "estimated-load-progress"
    (bus:publish :loading-progress self.estimated_load_progress)

    "is-loading"
    (bus:publish (if self.is_loading :start-loading :stop-loading))
    ))

(let [current-url "https://terse.telent.net/admin/stream"
      bus (event-bus)
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
      progress-bar (Gtk.ProgressBar {
                                     :orientation Gtk.Orientation.HORIZONTAL
                                     :fraction 1.0
                                     :margin 0
                                     })
      url (doto (Gtk.Entry {
                            :on_activate
                            (fn [self]
                              (bus:publish :fetch self.text))
                            })
            (: :set_text current-url))
      stop (doto (Gtk.Button {
                             :on_clicked #(bus:publish :stop-loading)
                             })
                (: :set_image (named-image "process-stop")))
      refresh (doto (Gtk.Button {
                                 :on_clicked #(bus:publish :reload)
                                 })
                (: :set_image (named-image "view-refresh")))
      webview (WebKit2.WebView {
                                :on_notify
                                #(handle-webview-properties $1 $2 bus)
                                })
      back (doto
               (Gtk.Button {
                            :on_clicked (fn [s]
                                          (if (webview:can_go_back)
                                              (webview:go_back)))
                            })
             (: :set_image (named-image "go-previous")))]

  (bus:subscribe :fetch #(webview:load_uri $1))
  (bus:subscribe :stop-loading #(webview:stop_loading))
  (bus:subscribe :reload #(webview:reload))
  (bus:subscribe :url-changed #(url:set_text $1))

  (bus:subscribe :url-changed #(print (.. "visiting " $1)))
  (bus:subscribe :title-changed #(window:set_title
                                  (.. $1 " - Just browsing")))

  (bus:subscribe :loading-progress #(tset progress-bar :fraction $1))
  (bus:subscribe :start-loading
                 (fn [] (stop:show) (refresh:hide)))
  (bus:subscribe :stop-loading
                 (fn [] (stop:hide) (refresh:show)))

  (load-adblocks webview.user_content_manager content-filter-store)

  (nav-bar:pack_start back false false 2)
  (nav-bar:pack_start url  true true 2)
  (nav-bar:pack_end refresh false false 2)
  (nav-bar:pack_end stop false false 2)

  (container:pack_start nav-bar false false 5)
  (container:pack_start progress-bar false false 0)
  (container:pack_start webview true true 5)

  (webview:load_uri current-url)

  (window:add container)

  (window:show_all))

(Gtk.main)
