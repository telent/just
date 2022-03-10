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

(let [css "
progress, trough {
  max-height: 6px;
  color: #ff44bb;
}
"
      style_provider (Gtk.CssProvider)]
  (style_provider:load_from_data css)
  (Gtk.StyleContext.add_provider_for_screen
   (Gdk.Screen.get_default)
   style_provider
   Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
   ))

(fn named-image [name size]
  (Gtk.Image.new_from_icon_name
   name
   (or size Gtk.IconSize.LARGE_TOOLBAR)))

(fn urlencode [url]
  (-> url
      (: :gsub "([^%w ])" (fn [c] (string.format "%%%02X" (string.byte c))))
      (: :gsub " " "+")))

(local default-search-provider "ddg")

(fn search-term-to-uri [provider text]
  (match provider
    "ebay"  (.. "https://www.ebay.co.uk/sch/i.html?_nkw=" (urlencode text))
    "lua" (.. "https://pgl.yoyo.org/luai/i/" (urlencode text))
    "ddg" (.. "https://duckduckgo.com/?q=" (urlencode text))))

(fn to-uri [text]
  (if (text:find " ")
      (let [(_ _ provider term)  (text:find "^@(%g+) *(.*)")]
        (if provider
            (search-term-to-uri provider term)
            (search-term-to-uri default-search-provider text)))
      (text:find "^http") text
      (.. "https://" text)))

(local completions
       (doto (Gtk.ListStore)
         (: :set_column_types [lgi.GObject.Type.STRING])))

(fn add-autocomplete-suggestion [url]
  (completions:append [url]))

(local keysyms {
                :Escape 0xff1b
                })

(local
 Navbar
 {
  :new
  (fn [webview]
    (let [url (Gtk.Entry {
                          :completion (Gtk.EntryCompletion {:model completions :text_column 0 })
                          :on_activate
                          (fn [event]
                            (add-autocomplete-suggestion event.text)
                            (webview:visit (to-uri event.text)))
                          :on_key_release_event
                          #(if (= $2.keyval keysyms.Escape)
                               (tset $1 :text webview.properties.uri))
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
      (webview:listen :estimated-load-progress
                      (fn [fraction]
                        (tset stop :visible (< fraction 1))
                        (tset refresh :visible (>= fraction 1))))
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
      progress-bar (Gtk.ProgressBar {
                                     :orientation Gtk.Orientation.HORIZONTAL
                                     :fraction 1.0
                                         :margin 0
                                     })
      ]

  (viewplex:listen :title #(window:set_title (..  $1 " - Just browsing")))
  (viewplex:listen :estimated-load-progress #(tset progress-bar :fraction $1))

  (container:pack_start navbar.widget false false 0)
  (container:pack_start progress-bar false false 0)
  (container:pack_start viewplex.widget true true 0)

  (if (. arg 1)
      (each [_ url (ipairs arg)]
        (let [v (Webview.new)]
          (v:visit url)
          (viewplex:add-view v)))
      (viewplex:add-view
       (doto (Webview.new) (: :visit "about:blank"))))

  (window:add container)
  (window:show_all))

(Gtk.main)
