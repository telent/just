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
 Listeners
 {
  :new
  #(let [listeners {}]
     {
      :notify (fn [_ name value]
                (let [funs (. listeners name)]
                  (when funs
                    (each [_ f (ipairs funs)]
                      (f value)))))
      :add (fn [_ event-name fun]
             (let [funs (or (. listeners event-name) [])]
               (table.insert funs fun)
               (tset listeners event-name funs)))
      })})

(local
 Webview
 {
  :new
  #(let [listeners (Listeners.new)
         widget (WebKit2.WebView {
                                  :on_notify
                                  (fn [self pspec]
                                    (when (not (= pspec.name :parent))
                                            (listeners:notify pspec.name (. self pspec.name))))
                                  })]
     ;;(load-adblocks webview.user_content_manager content-filter-store)
     {
      :listen #(listeners:add $2 $3)
      :visit (fn [self url]
               (widget:load_uri url))
      :stop-loading #(widget:stop_loading)
      :refresh #(widget:reload)
      :go-back #(and (widget:can_go_back) (widget:go_back))

      :widget widget
      })
  })

(local
 Viewplex
 (let [relay-events []]
   {
    :new
    #(let [listeners (Listeners.new)
           widget (Gtk.Notebook {
                                 :show_tabs false
                                 ;;# :on_switch_page
                                 })
           views []]
       (var foreground-view nil)
       {
        :listen (fn [_ name fun]
                  (if (not (. relay-events name))
                      (each [_ v (ipairs views)]
                        (v:listen name #(listeners:notify name $1))))
                  (table.insert relay-events name)
                  (listeners:add name fun))
        :widget widget
        :add-view (fn [self webview]
                    (set foreground-view webview)
                    (webview.widget:show)
                    (table.insert views webview)
                    (each [_ event-name (ipairs relay-events)]
                      (webview:listen event-name
                                      #(listeners:notify event-name $1)))
                    (set widget.page
                         (widget:append_page webview.widget)))
        :visit #(and foreground-view (foreground-view:visit $2))
        :stop-loading #(and foreground-view
                            (foreground-view:stop-loading))
        :refresh #(and foreground-view (foreground-view:refresh))
        :go-back #(and foreground-view (foreground-view:go-back))
        }
       )}))





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
      viewplex (Viewplex.new)
      navbar (Navbar.new viewplex)
      ]

  (container:pack_start navbar.widget false false 0)
  (container:pack_start viewplex.widget true true 0)
  (viewplex:add-view webview)

  (window:add container)

  (viewplex:visit "https://terse.telent.net/")
  (window:show_all))

(Gtk.main)
