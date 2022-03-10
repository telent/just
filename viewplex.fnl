(local { : Gtk : Gdk : WebKit2 : cairo } (require :lgi))

(local Listeners (require :listeners))

(local thumbnail-width 300)
(local thumbnail-height 200)

(fn on-fake-swipe [widget fun]
  ;; this is here for testing on desktop systems that don't
  ;; have touch support
  (Gtk.GestureLongPress {
                         :widget widget
                         :on_pressed fun
                         }))

(fn on-swipe [widget fun]
  (if (os.getenv "JUST_HACKING") (on-fake-swipe widget fun))

  (Gtk.GestureSwipe {
                     :widget widget
                     :on_update
                     (fn [self]
                       (self:set_state Gtk.EventSequenceState.CLAIMED))
                     :on_swipe
                     (fn [self x y]
                       (if (and (< 700 x) (< y 700))
                           (fun)
                           (self:set_state Gtk.EventSequenceState.DENIED))
                       true)
                     }))

(fn refresh-overview [self scrolledwindow views]
  (let [box (Gtk.Box {
                      :orientation Gtk.Orientation.VERTICAL
                      })]

    (each [_ w (ipairs (scrolledwindow:get_children))]
      (scrolledwindow:remove w))

    (each [i w (pairs views)]
      (box:pack_start
       (let [b (Gtk.Button {
                            :label w.properties.title
                            :width thumbnail-width
                            :height thumbnail-height
                            :image-position Gtk.PositionType.TOP
                            :on_clicked #(self:focus-view w)
                            })]
         (on-swipe b #(self:remove-view w))
         (w:thumbnail-image thumbnail-width thumbnail-height #(b:set_image $1))
         b)
       false false 5))

    (box:pack_start (Gtk.Button
                     {
                      :label " + "
                      :width 300
                      :height 200
                      ; :on_clicked #(bus:publish $1 :new-tab)
                      })
                    false false 5)

    (scrolledwindow:add box)
    (scrolledwindow:show_all)
    ))


{
 :new
 (fn []
   (var foreground-view nil)
   (let [listeners (Listeners.new)
         relay-events []
         widget (Gtk.Notebook {
                               :show_tabs false
                               })
         overview (Gtk.ScrolledWindow)
         overview-page-num (widget:append_page overview)
         relay-event (fn [source event-name]
                       (source:listen
                        event-name
                        #(if (= source foreground-view)
                             (listeners:notify event-name $1))))
         views {}]
     {
      :listen (fn [_ name fun]
                (if (not (. relay-events name))
                    (each [_ v (pairs views)]
                      (relay-event v name)))
                (table.insert relay-events name)
                (listeners:add name fun))

      :widget widget

      :add-view (fn [self webview]
                  (set foreground-view webview)
                  (webview.widget:show)
                  (each [_ event-name (ipairs relay-events)]
                    (relay-event webview event-name))
                  (let [page (widget:append_page webview.widget)]
                    (tset views page webview)
                    (tset self :properties webview.properties)
                    (set widget.page page)
                    page))

      :remove-view (fn [self view]
                     (let [page (widget:page_num view.widget)]
                       (tset views page nil)
                       (widget:remove_page page)
                       (self:show-overview)
                       ))

      :focus-view (fn [self view]
                    (when view
                      (set foreground-view view)
                      (each [_ prop (ipairs relay-events)]
                        (listeners:notify prop (. view.properties prop)))
                      (tset self :properties view.properties)
                      (set widget.page (widget:page_num view.widget))))

      :show-overview (fn [self]
                       (set foreground-view nil)
                       (set widget.page overview-page-num)
                       (refresh-overview self overview views))

      :visit #(and foreground-view (foreground-view:visit $2))
      :stop-loading #(and foreground-view
                          (foreground-view:stop-loading))
      :refresh #(and foreground-view (foreground-view:refresh))
      :go-back #(and foreground-view (foreground-view:go-back))
      }
     ))}
