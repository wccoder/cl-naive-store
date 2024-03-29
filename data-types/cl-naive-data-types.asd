(defsystem "cl-naive-data-types"
  :description "Add on for cl-naive-store that supplies some predefined field data types and methods for getting, setting and validating them."
  :version "0.0.1"
  :author "Phil Marneweck <phil@psychedelic.co.za>"
  :licence "MIT"
  :depends-on ("cl-naive-store")
  :components ((:file "packages")
	       (:file "data-types" :depends-on ("packages"))))
