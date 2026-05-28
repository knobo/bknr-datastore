;;;; -*- Mode: LISP -*-

(defsystem :bknr.impex.test
  :name "BKNR impex tests"
  :description "Regression tests for the BKNR XML import/export module"
  :licence "BSD"
  :depends-on (:bknr.impex :fiveam)
  :components ((:module "xml-impex"
                :components ((:file "xml-import-tests"))))
  :perform (test-op (o c)
             (symbol-call :fiveam :run! :bknr.impex)))
