;;;; Regression tests for SAX character handling in the XML importer.
;;;;
;;;; SAX delivers the text content of a single element across an arbitrary
;;;; number of SAX:CHARACTERS calls (entity references, CDATA boundaries and
;;;; buffer chunking all cause splits). The importer must therefore buffer the
;;;; raw chunks and apply the slot's :parser exactly once, on the complete
;;;; string, at IMPORTER-FINALIZE -- never per chunk. See xml-import.lisp.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (or (find-package :bknr.impex.tests)
      (defpackage :bknr.impex.tests
        (:use :cl :bknr.impex :fiveam))))

(in-package :bknr.impex.tests)

(def-suite :bknr.impex)
(in-suite :bknr.impex)

(defvar *test-dtd*
  (namestring (asdf:system-relative-pathname
               :bknr.impex "xml-impex/xml-import-tests.dtd")))

;;; The slot parser records every value it is called with, so a test can assert
;;; both *how many times* it ran and *what* it received.
(defvar *parser-calls* nil)

(defun recording-parser (value)
  (push value *parser-calls*)
  value)

(defclass item-with-recorded-body ()
  ((body :initarg :body :reader item-body
         :body t :parser #'recording-parser))
  (:metaclass xml-class)
  (:dtd-name *test-dtd*)
  (:element "item"))

(defclass item-with-integer-body ()
  ((body :initarg :body :reader item-body
         :body t :parser #'parse-integer))
  (:metaclass xml-class)
  (:dtd-name *test-dtd*)
  (:element "item"))

;;; ---------------------------------------------------------------------------
;;; Deterministic unit tests: drive the SAX handler methods directly so the
;;; chunk boundaries are fixed and do not depend on the parser's coalescing
;;; behaviour.
;;; ---------------------------------------------------------------------------

(defun finalize-from-chunks (class-name &rest chunks)
  "Feed CHUNKS to the importer as separate SAX:CHARACTERS events for a fresh
instance of CLASS-NAME, then return the finalized object."
  (let ((handler (make-instance 'xml-class-importer))
        (instance (make-instance 'bknr.impex::xml-class-instance
                                 :element "item"
                                 :class (find-class class-name))))
    (dolist (chunk chunks)
      (bknr.impex::importer-add-characters handler instance chunk))
    (bknr.impex::importer-finalize handler instance)))

(test parser-runs-once-on-reassembled-body
  "The slot parser must see the whole body exactly once, not one call per
SAX chunk."
  (let ((*parser-calls* nil))
    (let ((object (finalize-from-chunks 'item-with-recorded-body
                                        "foo " "&" " bar")))
      (is (= 1 (length *parser-calls*))
          "parser was called ~A time(s), expected exactly 1" (length *parser-calls*))
      (is (string= "foo & bar" (first *parser-calls*)))
      (is (string= "foo & bar" (item-body object))))))

(test non-distributive-parser-sees-whole-string
  "A parser such as PARSE-INTEGER only works on the complete string; running
it per chunk and concatenating the results would error or be wrong."
  (let ((object (finalize-from-chunks 'item-with-integer-body "10" "0")))
    (is (eql 100 (item-body object)))))

;;; ---------------------------------------------------------------------------
;;; Integration test: parse a real XML file through cxml. The body text
;;; contains an entity reference, which causes cxml to emit several
;;; SAX:CHARACTERS events for the single element.
;;; ---------------------------------------------------------------------------

(test entity-split-body-parsed-end-to-end
  (let* ((*parser-calls* nil)
         (xml (namestring (asdf:system-relative-pathname
                           :bknr.impex "xml-impex/xml-import-tests-entity.xml")))
         (items (getf (parse-xml-file xml (list (find-class 'item-with-recorded-body)))
                      :item)))
    (is (= 1 (length items)))
    (is (string= "foo & bar" (item-body (first items))))))
