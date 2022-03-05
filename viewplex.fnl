(local { : Gtk : Gdk : WebKit2 : cairo } (require :lgi))

(local Listeners (require :listeners))

{
 :new
 #(let [listeners (Listeners.new)
        relay-events []
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
    )}
