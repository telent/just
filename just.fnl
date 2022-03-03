(local lgi (require :lgi))
(local inspect (require :inspect))

(local { : Gtk : Gdk : WebKit2 : cairo } lgi)

(local {: view} (require :fennel))

(local cache-dir (.. (os.getenv "HOME") "/.cache/just"))

(local content-filter-store
       (WebKit2.UserContentFilterStore {:path cache-dir}))

(-> (WebKit2.WebContext:get_default)
    (: :get_website_data_manager)
    (: :get_cookie_manager)
    (: :set_persistent_storage
       (.. cache-dir "/cookies.db")
       WebKit2.CookiePersistentStorage.SQLITE))

(local
 Webview
 {
  :new
  #(let [listeners {}
         notify-listeners (fn [self pspec]
                            (let [n pspec.name
                                  funs (. listeners n)]
                              (when funs
                                (each [_ f (ipairs funs)]
                                  (f (. self n))))))
         widget (WebKit2.WebView {
                                  :on_notify
                                  #(notify-listeners $1 $2)
                                  })]
     ;;(load-adblocks webview.user_content_manager content-filter-store)
     {
      :listen (fn [self event-name fun]
                (let [funs (or (. listeners event-name) [])]
                  (table.insert funs fun)
                  (tset listeners event-name funs)))
      :visit (fn [self url]
               (widget:load_uri url))
      :stop-loading #(widget:stop_loading)
      :refresh #(widget:reload)
      :go-back #(and (widget:can_go_back) (widget:go_back))

      :widget widget
      })
  })

(fn named-image [name size]
  (Gtk.Image.new_from_icon_name
   name
   (or size Gtk.IconSize.LARGE_TOOLBAR)))

(local
 Navbar
 {
  :new
  (fn [webview]
    (let [url (Gtk.Entry {
                          ;; :completion (Gtk.EntryCompletion {:model completions :text_column 0 })
                          :on_activate
                          #(webview:visit $1.text)
                          })
          stop (doto (Gtk.Button {
                                  :on_clicked #(webview:stop-loading)
                                  })
                 (: :set_image (named-image "process-stop")))
          refresh (doto (Gtk.Button {
                                     :on_clicked #(webview:refresh)
                                     })
                    (: :set_image (named-image "view-refresh")))
          show-tabs (Gtk.Button {
                                 :label "><"
;                                 :on_clicked  #(views:show-tab-overview)
                                 })
          back (doto
                   (Gtk.Button {
                                :on_clicked #(webview:go-back)
                                })
                 (: :set_image (named-image "go-previous")))
          widget (Gtk.Box {
                           :orientation Gtk.Orientation.HORIZONTAL
                           })
          ]
      (widget:pack_start back false false 2)
      (widget:pack_start refresh false false 2)
      (widget:pack_start stop false false 2)
      (widget:pack_start url  true true 2)
      (widget:pack_end show-tabs false false 2)

      (webview:listen :uri #(url:set_text $1))

      {
       :widget widget
       }))
  })


(let [window (Gtk.Window {
                          :title "Just browsing"
                          :default_width 360
                          :default_height 720
                          :on_destroy Gtk.main_quit
                          })
      container (Gtk.Box {
                          :orientation Gtk.Orientation.VERTICAL
                          })
      webview (Webview.new)
      navbar (Navbar.new webview)
      ]

  (container:pack_start navbar.widget false false 0)
  (container:pack_start webview.widget true true 0)

  (window:add container)

  (webview:visit "https://terse.telent.net/")
  (window:show_all))

(Gtk.main)
