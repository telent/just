(local fennel (require :fennel))
(local observable (require :observable))

(macro expect [form]
  `(do
     (assert ,form ,(view [:failed form]))
     (print ,(view [:passed form]))))

(macro expect-error [form]
  `(let [(ok?# msg#) (pcall (fn [] ,form))]
     (assert (not ok?#) msg#)
     (print ,(view [:passed (list :error form)]))))

(local app-state
       (observable.new
        {
         :foo 27
         :bar 54
         :nest {
                :name "beatles"
                :artists [:john :paul: :ringo :george ]
                }
         }))


(expect (= (app-state:get [:foo]) 27))
(expect (= (app-state:get [:nest :name]) "beatles"))

(let [s (observable.new {:foo 43})]
  ;; s:get on a non-leaf returns the subtree. use table.concat
  ;; for comparison of values
  (expect (= (table.concat (s:get [])) (table.concat {:foo 43}))))

(let [s (observable.new {:foo 43})]
  ;; update existing entry
  (s:update [:foo] 84)
  (expect (= (s:get [:foo]) 84))

  ;; create new entry
  (s:update [:baz] 48)
  (expect (= (s:get [:baz]) 48))

  ;; doesn't create new nested keys
  (expect-error (s:update [:nonexistent :path] 22)))

(let [s (observable.new {:foo {:bar 43}})]
  (var win false)
  ;; observers live on subtrees, not individual nodes
  (s:observe [:foo] #(set win true))
  (s:update [:foo :bar] 42)
  (expect (and win)))

(let [s (observable.new {:foo {:bar {:baz 43}}})]
  (var win 0)
  ;; observers on ancestor trees are called after child trees
  (s:observe [:foo] #(set win (/ win 2)))
  (s:observe [:foo :bar] #(set win 4))
  (s:update [:foo :bar :baz] 42)
  (expect (= win 2)))

(let [s (observable.new {:foo {:bar {:baz 43}}})]
  (var win 0)
  ;; multiple observers can live on same subtree
  (s:observe [:foo :bar] #(set win (+ win 1)))
  (s:observe [:foo :bar] #(set win (+ win 1)))
  (s:update [:foo :bar :baz] 42)
  (expect (= win 2)))
