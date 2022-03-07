(local lgi (require :lgi))
(local inspect (require :inspect))

(local { : Gtk : Gdk : WebKit2 : cairo } lgi)

(local {: view} (require :fennel))

(local Listeners (require :listeners))
(local Webview (require :webview))
(local Viewplex (require :viewplex))

(local cache-dir (.. (os.getenv "HOME") "/.cache/just"))

(local content-filter-store
       (WebKit2.UserContentFilterStore {:path cache-dir}))

(-> (WebKit2.WebContext:get_default)
    (: :get_website_data_manager)
    (: :get_cookie_manager)
    (: :set_persistent_storage
       (.. cache-dir "/cookies.db")
       WebKit2.CookiePersistentStorage.SQLITE))

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
          show-overview (Gtk.Button {
                                     :label "><"
                                     :on_clicked #(webview:show-overview)
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
      (widget:pack_end show-overview false false 2)

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
      viewplex (Viewplex.new)
      navbar (Navbar.new viewplex)
      ]

  (viewplex:listen :title #(window:set_title (..  $1 " - Just browsing")))

  (container:pack_start navbar.widget false false 0)
  (container:pack_start viewplex.widget true true 0)

  (each [_ url (ipairs arg)]
    (let [v (Webview.new)]
      (v:visit url)
      (viewplex:add-view v)))

  (window:add container)
  (window:show_all))

(Gtk.main)
