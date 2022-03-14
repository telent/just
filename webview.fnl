(local { : Gtk : Gdk : WebKit2 : cairo  : GLib } (require :lgi))

(local Listeners (require :listeners))

(fn load-easylist-json [store cb]
  (print "loading easylist from json")
  (with-open [f (io.open "easylist_min_content_blocker.json" "r")]
    (let [blocks (f:read "*a")]
      (store:save "easylist"
                  (GLib.Bytes blocks)
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

(fn scale-surface [source image-width image-height]
  (let [scaled (cairo.ImageSurface.create
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

(fn thumbnail-image [widget width height fun]
  ;; underlying call is async, so use callback
  (widget:get_snapshot
   WebKit2.SnapshotRegion.VISIBLE
   WebKit2.SnapshotOptions.NONE
   nil
   (fn [self res]
     (let [surface (widget:get_snapshot_finish res)
           scaled (scale-surface surface width height)
           img (doto (Gtk.Image) (: :set_from_surface scaled))]
       (fun img)))))


{
 :new
 (fn [{: content-filter-store}]
   (let [listeners (Listeners.new)
         props {}
         widget (WebKit2.WebView {
                                  :on_notify
                                  (fn [self pspec]
                                    (when (not (= pspec.name :parent))
                                      (let [val (. self pspec.name)]
                                        (tset props pspec.name val)
                                        (listeners:notify pspec.name val))))
                                  })]
     (when content-filter-store
       (load-adblocks widget.user_content_manager content-filter-store))
     {
      :listen #(listeners:add $2 $3)
      :visit (fn [self url]
               (widget:load_uri url))
      :stop-loading #(widget:stop_loading)
      :refresh #(widget:reload)
      :go-back #(and (widget:can_go_back) (widget:go_back))

      :thumbnail-image (fn [self width height fun]
                         (thumbnail-image widget width height fun))

      :properties props
      :widget widget
      }))
 }
