(local { : Gtk : Gdk : WebKit2 : cairo } (require :lgi))

(local Listeners (require :listeners))


{
 :new
 #(let [listeners (Listeners.new)
        props {}
        widget (WebKit2.WebView {
                                 :on_notify
                                 (fn [self pspec]
                                   (when (not (= pspec.name :parent))
                                     (let [val (. self pspec.name)]
                                       (tset props pspec.name val)
                                       (listeners:notify pspec.name val))))
                                 })]
    ;;(load-adblocks webview.user_content_manager content-filter-store)
    {
     :listen #(listeners:add $2 $3)
     :visit (fn [self url]
              (widget:load_uri url))
     :stop-loading #(widget:stop_loading)
     :refresh #(widget:reload)
     :go-back #(and (widget:can_go_back) (widget:go_back))

     :properties props
     :widget widget
     })
 }
