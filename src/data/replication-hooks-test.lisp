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
