(local lgi (require :lgi))
(local inspect (require :inspect))

(local Gtk lgi.Gtk)
(local WebKit2 lgi.WebKit2)

(local cache-dir (.. (os.getenv "HOME") "/.cache/just"))

(local content-filter-store
       (WebKit2.UserContentFilterStore {:path cache-dir}))

(-> (WebKit2.WebContext:get_default)
    (: :get_website_data_manager)
    (: :get_cookie_manager)
    (: :set_persistent_storage
       (.. cache-dir "/cookies.db")
       WebKit2.CookiePersistentStorage.SQLITE))

(fn event-bus []
  (let [subscriptions {}
        vivify (fn [n v]
                 (or (. n v) (tset n v {}))
                 (. n v))]
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

(fn new-webview [bus]
  (let [webview (WebKit2.WebView {
                                  :on_notify
                                  #(handle-webview-properties $1 $2 bus)

                                  })]
    (load-adblocks webview.user_content_manager content-filter-store)
    webview))

(fn pane-cave [bus]
  (let [widget (Gtk.Notebook { :show_tabs false })
        tabs {}
        new-tab (fn []
                  (print "new tab")
                  (let [v (new-webview bus)
                        i (widget:append_page v)]
                    (tset tabs i v)
                    (v:show)
                    v))
        current #(. tabs widget.page)]
    (bus:subscribe :fetch  #(match (current) c (c:load_uri $1)))
    (bus:subscribe :stop-loading
                   #(match (current) c (c:stop_loading)))
    (bus:subscribe :reload
                   #(match (current) c (c:reload)))
    (bus:subscribe :go-back
                   #(match (current) c (and (c:can_go_back) (c:go_back))))
    (bus:subscribe :new-tab new-tab)
    {
     :new-tab new-tab
     :current-tab current
     :widget widget
     :next-tab (fn [self]
                 (let [n (+ 1 widget.page)]
                   (widget:set_current_page (if (. tabs n) n 0)))
                 (widget:get_current_page))
     }))

(let [current-url "https://terse.telent.net"
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
      url (Gtk.Entry {
                      :on_activate
                      (fn [self] (bus:publish :fetch self.text))
                      })
      stop (doto (Gtk.Button {
                             :on_clicked #(bus:publish :stop-loading)
                             })
                (: :set_image (named-image "process-stop")))
      new-tab (Gtk.Button {
                           :on_clicked #(bus:publish :new-tab)
                           :label "➕"
                           })
      refresh (doto (Gtk.Button {
                                 :on_clicked #(bus:publish :reload)
                                 })
                (: :set_image (named-image "view-refresh")))
      views (pane-cave bus)
      next-tab (Gtk.Button {
                            :label ">>"
                            :on_clicked  #(views:next-tab)
                            })

      back (doto
               (Gtk.Button {
                            :on_clicked #(bus:publish :go-back)
                            })
             (: :set_image (named-image "go-previous")))]

  (bus:subscribe :url-changed #(url:set_text $1))

  (bus:subscribe :title-changed #(window:set_title
                                  (.. $1 " - Just browsing")))

  (bus:subscribe :loading-progress #(tset progress-bar :fraction $1))
  (bus:subscribe :start-loading
                 (fn [] (stop:show) (refresh:hide)))
  (bus:subscribe :stop-loading
                 (fn [] (stop:hide) (refresh:show)))

  (views:new-tab)

  (nav-bar:pack_start back false false 2)
  (nav-bar:pack_start refresh false false 2)
  (nav-bar:pack_start stop false false 2)
  (nav-bar:pack_start url  true true 2)
  (nav-bar:pack_end next-tab false false 2)
  (nav-bar:pack_end new-tab false false 2)

  (container:pack_start nav-bar false false 5)
  (container:pack_start progress-bar false false 0)
  (container:pack_start views.widget true true 5)

  (window:add container)

  (window:show_all)
  (bus:publish :fetch current-url))


(Gtk.main)
