(local {: view} (require :fennel))

(fn concat [dest src]
  (table.move dest 1 (# dest) (# src) src))

(fn update [data path value vivify?]
  (let [[first & rest] path]
    (if (next rest)
        (do
          (if (and vivify? (not (. data first)))
              (tset data first {}))
          (update (. data first) rest value))
        (tset data first value))))

(fn new [data]
  (let [observers {}
        key [:obs]]
    (fn get [data path]
      (let [[first & rest] path]
        (if (not first) data
            (next rest) (get (. data first) rest)
            (. (or data {}) first))))

    (fn publish [observers path]
      (let [[first & rest] path
            os (. (or observers {}) first)]
        (if (and (next rest) (next os)) (publish os rest))
        (match os
          {key list} (each [_ f (pairs list)] (f)))))

    (fn observe [observers path fun]
      (let [el (get observers path)]
        (if el
            (table.insert (. el key) fun)
            (update observers path {key [fun]} true))))
    {
     :observe #(observe observers $2 $3)
     :update #(do (update data $2 $3) (publish observers $2))
     :get #(get data $2)
     }))

{: new }
