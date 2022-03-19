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
     })}
