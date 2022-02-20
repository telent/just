(local {: view} (require :fennel))

(fn concat [dest src]
  (table.move dest 1 (# dest) (# src) src))

(fn update [data self path value]
  (let [[first & rest] path]
    (if (next rest)
        (update (. data first) self rest value)
        (tset data first value))
    (if data._subscribers
        (each [_ f (pairs data._subscribers)] (f)))))

(fn get [data self path]
  (let [[first & rest] path]
    (if (not first) data
        (next rest) (get (. data first) self rest)
        (. data first))))

(fn observe [data self path fun]
  (let [el (get data self path)]
    (when el
      (if el._subscribers
          (el._subscribers:insert fun)
          (tset el :_subscribers [fun])))))

(fn new [data]
  {
   :observe (partial observe data)
   :update (partial update data)
   :get (partial get data)
   })

{: new }
