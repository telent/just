(local lgi (require :lgi))
(local inspect (require :inspect))

(local Gtk lgi.Gtk)
(local Gdk lgi.Gdk)
(local WebKit2 lgi.WebKit2)
(local cairo lgi.cairo)

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
                 (tset n v (or (. n v) []))
                 (. n v))]
    {
     :subscriptions subscriptions
     :subscribe (fn [self event-name handler]
                  (table.insert (vivify subscriptions event-name) handler))
     :publish (fn [self sender event-name payload]
                (each [_ handler (pairs (. subscriptions event-name))]
                  (handler sender payload)))
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
    (bus:publish self :url-changed self.uri)

    "title"
    (if (> (self.title:len) 0)
        (bus:publish self :title-changed self.title))

    "estimated-load-progress"
    (bus:publish self :loading-progress self.estimated_load_progress)

    "is-loading"
    (bus:publish self  (if self.is_loading :start-loading :stop-loading))
    ))

(fn new-webview [bus]
  (let [webview (WebKit2.WebView {
                                  :on_notify
                                  #(handle-webview-properties $1 $2 bus)
                                  })]
    (load-adblocks webview.user_content_manager content-filter-store)
    webview))

(fn scale-surface [source]
  (let [image-width 300
        image-height 200
        scaled (cairo.ImageSurface.create
                cairo.Format.ARGB32
                image-width image-height)
        ctx (cairo.Context.create scaled)
        source-width (cairo.ImageSurface.get_width source)
        source-height (cairo.ImageSurface.get_height source)
        scale (/ image-width source-width)]
    ;; XXX do we need to destroy this context? the example
    ;; in C called cairo_destroy(cr), but I haven't found a
    ;; gi equivalent
    (doto ctx
      (: :scale scale scale)
      (: :set_source_surface source 0 0)
      (: :paint))
    scaled))

(fn load-webview-thumbnail [button webview]
  (webview:get_snapshot
   WebKit2.SnapshotRegion.VISIBLE
   WebKit2.SnapshotOptions.NONE
   nil
   (fn [self res]
     (let [surface (webview:get_snapshot_finish res)
           scaled (scale-surface surface)
           img (doto (Gtk.Image) (: :set_from_surface scaled))]
       (button:set_image img)))))

(fn connect-swipe-gesture [widget bus index]
  (Gtk.GestureSwipe {
                     :widget widget
                     :on_update
                     (fn [self]
                       (self:set_state Gtk.EventSequenceState.CLAIMED))
                     :on_swipe
                     (fn [self x y]
                       (if (and (< 700 x) (< y 700))
                           (bus:publish self :close-tab index)
                           (self:set_state Gtk.EventSequenceState.DENIED))
                       true)
                     }))


(fn update-tab-overview [bus tabs scrolledwindow]
  (let [box (Gtk.Box {
                      :orientation Gtk.Orientation.VERTICAL
                      })]

    (each [_ w (ipairs (scrolledwindow:get_children))]
      (scrolledwindow:remove w))

    (box:add (Gtk.Label { :label "Open tabs" }))


    (each [i w (pairs tabs)]
      (when (> i 0)
        (box:pack_start
         (doto (Gtk.Button {
                            :image-position Gtk.PositionType.TOP
                            :on_clicked
                            #(bus:publish $1 :switch-tab i)
                            })
           (connect-swipe-gesture bus i)
           (load-webview-thumbnail w))
         false false 5)))

    (scrolledwindow:add box)
    (scrolledwindow:show_all)
    ))


(fn pane-cave [bus]
  (let [tabs {}
        widget (Gtk.Notebook {
                              :show_tabs false
                              :on_switch_page
                              (fn [self page num]
                                (when (= num 0)
                                  (update-tab-overview bus tabs page)))
                              })
        new-tab (fn [self child]
                  (let [v (or child (new-webview bus))
                        i (widget:append_page v)]
                    (tset tabs i v)
                    (v:show)
                    (set widget.page i)
                    v))
        tab-overview (Gtk.ScrolledWindow)
        current #(. tabs widget.page)]
    (bus:subscribe :fetch  #(match (current) c (c:load_uri $2)))
    (bus:subscribe :stop-loading
                   #(match (current) c (c:stop_loading)))
    (bus:subscribe :reload
                   #(match (current) c (c:reload)))
    (bus:subscribe :go-back
                   #(match (current) c (and (c:can_go_back) (c:go_back))))

    (bus:subscribe :new-tab new-tab)
    (bus:subscribe :switch-tab
                   (fn [sender index]
                     (widget:set_current_page index)
                     (let [tab (. tabs index)]
                       (when (and tab tab.uri tab.title)
                         (bus:publish tab :url-changed tab.uri)
                         (bus:publish tab :title-changed tab.title)
                         ))))

    (bus:subscribe :close-tab
                   (fn [sender i]
                     (tset tabs i nil)
                     (update-tab-overview bus tabs tab-overview)
                     (widget:set_current_page 0)))
    (new-tab nil tab-overview)

    {
     :new-tab new-tab
     :current-tab current
     :widget widget
     :show-tab-overview #(widget:set_current_page 0)
     }))

(let [current-url "https://terse.telent.net"
      bus (event-bus)
      window (Gtk.Window {
                          :title "Just browsing"
                          :default_width 360
                          :default_height 720
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
                      (fn [self] (bus:publish self :fetch self.text))
                      })
      stop (doto (Gtk.Button {
                             :on_clicked #(bus:publish $1 :stop-loading)
                             })
                (: :set_image (named-image "process-stop")))
      new-tab (Gtk.Button {
                           :on_clicked #(bus:publish $1 :new-tab)
                           :label "➕"
                           })
      refresh (doto (Gtk.Button {
                                 :on_clicked #(bus:publish $1 :reload)
                                 })
                (: :set_image (named-image "view-refresh")))
      views (pane-cave bus)
      show-tabs (Gtk.Button {
                            :label "><"
                            :on_clicked  #(views:show-tab-overview)
                            })
      back (doto
               (Gtk.Button {
                            :on_clicked #(bus:publish $1 :go-back)
                            })
             (: :set_image (named-image "go-previous")))
      visible? (fn [tab]
                 (= (views:current-tab) tab))]

  (bus:subscribe :url-changed
                 #(when (visible? $1) (url:set_text $2)))

  (bus:subscribe :title-changed
                 #(when (visible? $1)
                    (window:set_title
                     (.. $2 " - Just browsing"))))

  (bus:subscribe :loading-progress
                 #(when (visible? $1)
                    (tset progress-bar :fraction $2)))
  (bus:subscribe :start-loading
                 #(when (visible? $1)
                    (stop:show) (refresh:hide)))
  (bus:subscribe :stop-loading
                 #(when (visible? $1)
                    (stop:hide) (refresh:show)))

  (each [_ url (ipairs arg)]
    (views:new-tab))

  (nav-bar:pack_start back false false 2)
  (nav-bar:pack_start refresh false false 2)
  (nav-bar:pack_start stop false false 2)
  (nav-bar:pack_start url  true true 2)
  (nav-bar:pack_end show-tabs false false 2)
  (nav-bar:pack_end new-tab false false 2)

  (container:pack_start nav-bar false false 5)
  (container:pack_start progress-bar false false 0)
  (container:pack_start views.widget true true 5)

  (window:add container)

  (window:show_all)

  (each [i url (ipairs arg)]
    (lgi.GLib.timeout_add_seconds
     0
     (* 2 i)
     (fn []
       (bus:publish window :switch-tab i)
       (bus:publish window :fetch url)
       false))))

(Gtk.main)
