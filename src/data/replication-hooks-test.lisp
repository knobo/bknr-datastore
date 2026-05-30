;;;; Tester for replikerings-hookene: commit-observer og persistert LSN.
(in-package :bknr.datastore)

(5am:in-suite :bknr.datastore)

;;; --- Fixtures ---

(defclass repl-test-object (store-object)
  ((value :initarg :value :accessor repl-test-object-value :initform nil))
  (:metaclass persistent-class))

(deftransaction repl-test-set (object value)
  (setf (slot-value object 'value) value))

(defun make-test-store-directory ()
  "En frisk, unik, tom katalog for en teststore."
  (ensure-directories-exist
   (merge-pathnames (make-pathname :directory (list :relative "bknr-repl-test"
                                                    (string (gensym "STORE"))))
                    (uiop:temporary-directory))))

(defmacro with-fresh-store ((store-var) &body body)
  "Kjør BODY med en frisk store bundet til STORE-VAR, og rydd opp katalogen etter."
  (let ((dir (gensym "DIR")))
    `(let ((,dir (make-test-store-directory)))
       (unwind-protect
            (let ((,store-var (make-instance 'store :directory ,dir)))
              (unwind-protect (progn ,@body)
                (when (boundp '*store*) (close-store))))
         (uiop:delete-directory-tree ,dir :validate t :if-does-not-exist :ignore)))))

(defun encode-to-bytes (object)
  "Encode OBJECT til en (unsigned-byte 8)-vektor, slik commit-pathen gjør internt."
  (let ((buffer (flex:make-in-memory-output-stream)))
    (encode object buffer)
    (flex:get-output-stream-sequence buffer)))

;;; --- Commit-observer ---

(5am:test commit-observer.receives
  "Observere kalles for hver committed transaksjon med strengt voksende LSN."
  (with-fresh-store (store)
    (let ((events '()))
      (add-commit-observer
       (lambda (s txn bytes lsn)
         (declare (ignore s))
         (push (list (type-of txn) (length bytes) lsn) events))
       store)
      (let ((obj (make-instance 'repl-test-object :value 1)))   ; logges som én txn
        (with-transaction () (setf (repl-test-object-value obj) 2)))  ; én anonym txn
      (setf events (nreverse events))
      (5am:is (>= (length events) 2))
      (5am:is (apply #'< (mapcar #'third events)))       ; LSN strengt voksende
      (5am:is (every #'plusp (mapcar #'second events)))))) ; ikke-tomme bytes

(5am:test commit-observer.bytes-match-encoding
  "Bytene observeren får er nøyaktig encodingen av transaksjonen."
  (with-fresh-store (store)
    (let ((captured '()))
      (add-commit-observer
       (lambda (s txn bytes lsn)
         (declare (ignore s lsn))
         (push (cons txn bytes) captured))
       store)
      (make-instance 'repl-test-object :value 7)
      (5am:is (= 1 (length captured)))
      (destructuring-bind (txn . bytes) (first captured)
        (5am:is (equalp bytes (encode-to-bytes txn)))))))

(5am:test commit-observer.remove
  "Etter remove-commit-observer kalles ikke observeren lenger."
  (with-fresh-store (store)
    (let ((count 0))
      (flet ((obs (s txn bytes lsn)
               (declare (ignore s txn bytes lsn))
               (incf count)))
        (add-commit-observer #'obs store)
        (make-instance 'repl-test-object :value 1)
        (remove-commit-observer #'obs store)
        (make-instance 'repl-test-object :value 2)
        (5am:is (= 1 count))))))

;;; --- Persistert LSN ---

(5am:test lsn.survives-snapshot-and-restore
  "Tellerstanden persisteres ved snapshot og leses tilbake ved restore."
  (let ((dir (make-test-store-directory)) counter-before)
    (unwind-protect
         (progn
           (let ((store (make-instance 'store :directory dir)))
             (make-instance 'repl-test-object :value 1)
             (make-instance 'repl-test-object :value 2)
             (setf counter-before (store-transaction-counter store))
             (5am:is (>= counter-before 2))
             (snapshot-store store)
             (close-store))
           (let ((store2 (make-instance 'store :directory dir)))
             (5am:is (>= (store-transaction-counter store2) counter-before))
             (close-store)))
      (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore))))

(5am:test lsn.consistent-after-replay
  "Etter snapshot + flere commits + reopen er telleren identisk reprodusert."
  (let ((dir (make-test-store-directory)) counter-at-close)
    (unwind-protect
         (progn
           (let ((store (make-instance 'store :directory dir)))
             (make-instance 'repl-test-object :value 1)
             (snapshot-store store)                       ; baseline persistert
             (make-instance 'repl-test-object :value 2)   ; post-snapshot poster i ny logg
             (make-instance 'repl-test-object :value 3)
             (setf counter-at-close (store-transaction-counter store))
             (close-store))
           (let ((store2 (make-instance 'store :directory dir)))
             (5am:is (= counter-at-close (store-transaction-counter store2)))
             (close-store)))
      (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore))))

(5am:test observer.does-not-corrupt-restore
  "Med en observer registrert restoreres tilstanden fortsatt korrekt."
  (let ((dir (make-test-store-directory)) id)
    (unwind-protect
         (progn
           (let ((store (make-instance 'store :directory dir)))
             (add-commit-observer (lambda (&rest args) (declare (ignore args))) store)
             (setf id (store-object-id (make-instance 'repl-test-object :value 99)))
             (close-store))
           (let ((store2 (make-instance 'store :directory dir)))
             (declare (ignorable store2))
             (let ((obj (store-object-with-id id)))
               (5am:is (not (null obj)))
               (5am:is (= 99 (repl-test-object-value obj))))
             (close-store)))
      (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore))))
