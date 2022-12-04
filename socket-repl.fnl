(local { : fdopen } (require "posix.stdio"))
(local fcntl (require "posix.fcntl"))
(local unistd (require "posix.unistd"))
(local socket (require "posix.sys.socket"))
(local lgi (require :lgi))

(local { : GLib } lgi)

(local { : repl } (require :fennel))


(fn watch-fd [fd mode handler]
  (let [events [ GLib.IOCondition.IN GLib.IOCondition.HUP]
        channel (GLib.IOChannel.unix_new fd)]
    (GLib.io_add_watch channel 0 events #(handler fd))))

(fn unix-socket-listener [pathname on-connected]
  (let [sa {:family socket.AF_UNIX
            :path pathname
            }
        fd (socket.socket socket.AF_UNIX socket.SOCK_STREAM 0)]
    (socket.bind fd sa)
    (socket.listen fd 5)
    (watch-fd
     fd fcntl.O_RDWR
     #(let [connected-fd (socket.accept $1)]
        (on-connected connected-fd)))
    ))

(fn get-input [fd]
  (let [buf (unistd.read fd 1024)]
    (if (and buf (> (# buf) 0))
        buf
        "\n,exit")))

(fn start [pathname]
  (unistd.unlink pathname)
  (unix-socket-listener
   pathname
   (fn [fd]
     (let [sock (fdopen fd "w+")
           repl-coro (coroutine.create repl)]
       (watch-fd fd fcntl.O_RDONLY
                 (fn [fd]
                   (coroutine.resume repl-coro (get-input  fd))
                   (if (= (coroutine.status repl-coro) :dead)
                       (do
                         (sock:write "bye!\n")
                         (sock:close)
                         false)
                       true
                       )))
       (coroutine.resume repl-coro
                         {:readChunk
                          (fn [{: stack-size}]
                            (sock:write
                             (if (> stack-size 0) ".." ">> "))
                            (sock:flush)
                            (coroutine.yield))
                          :onValues
                          (fn [vals]
                            (sock:write (table.concat vals "\t"))
                            (sock:write "\n"))
                          :onError
                          (fn [errtype err]
                            (sock:write
                             (.. errtype " error: " (tostring err) "\n")))
                          })))))


{ : start }
