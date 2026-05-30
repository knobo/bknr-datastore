;; -*-Lisp-*-

(defsystem :bknr.datastore.replication
  :name "bknr.datastore.replication"
  :description "Log-shipping replication for bknr.datastore: ship committed
transactions from a primary and apply them on a standby, with apply hooks for
server-sent events, derived views, and change-data-capture."
  :depends-on (:bknr.datastore :usocket :bordeaux-threads :ironclad :trivial-utf-8)
  :components ((:module "replication"
                :components ((:file "package")
                             (:file "wire" :depends-on ("package"))
                             (:file "auth" :depends-on ("package" "wire"))
                             (:file "replication" :depends-on ("package"))
                             (:file "network" :depends-on ("package" "wire" "replication" "auth"))))))

(defsystem :bknr.datastore.replication/tls
  :name "bknr.datastore.replication/tls"
  :description "Optional TLS transport for bknr.datastore replication (cl+ssl).
Plugs into the :make-stream seam of start-replication-server / run-replica."
  :depends-on (:bknr.datastore.replication :cl+ssl :usocket)
  :components ((:module "replication"
                :components ((:file "tls")))))
