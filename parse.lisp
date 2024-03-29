(in-package :cl-naive-store)

(defgeneric parse-object-p (collection object &key &allow-other-keys)
  (:documentation "Returns t if the object represents a naive object in its raw/reference state as read from file"))

(defmethod parse-object-p ((collection collection) object &key &allow-other-keys)
  (declare (ignore collection))
  (and (listp object)
       (atom (first object))
       (symbolp (first object))
       (> (length object) 1)
       (not (getx object :reference%))))


(defgeneric parse-object-deleted-p (collection object &key &allow-other-keys)
  (:documentation "Returns t if the raw/reference object is marked as deleted."))

(defmethod parse-object-deleted-p ((collection collection) object &key &allow-other-keys)
  (declare (ignore collection))
  (getf object :deleted-p))



(defgeneric parse-reference-object-p (collection object &key &allow-other-keys)
  (:documentation "Returns t if the raw/reference object is marked as an object referenced from another 
collection."))

(defmethod parse-reference-object-p ((collection collection) object &key &allow-other-keys)
  (declare (ignore collection))
  (and (listp object)
       (atom (first object))
       (symbolp (first object))
       (> (length object) 1)
       (getx object :reference%)))

(defgeneric parse-top-level-data-object (collection object &key &allow-other-keys)
  (:documentation "Parses the raw top level object read from file to its object reprensentation."))

(defmethod parse-top-level-data-object ((collection collection) object &key &allow-other-keys)
  (let ((resolved-values (parse-data-object collection object))
	(looked-up-object  (index-lookup-uuid 
			   collection
			   (dig object :hash)))
	(final-object))

    (setf final-object resolved-values)
    
    (cond (looked-up-object
	   (remove-data-object collection looked-up-object)	   
	   (if (parse-object-deleted-p collection object)
	       (setf final-object nil)))
	  ((not looked-up-object)
	   (unless (getf object :deleted-p)
	     (add-data-object collection final-object))))
    final-object))


(defun load-object-reference-collection (universe object-ref)
  "When objects are persisted to file any object values that are referencing an object in a different
collection is first sanitized (just enough info to retrieve the object later from where it is stored). 
When objects are read from a file the references need to be converted to objects but for that to 
happen the collection containing the referenced objects need to be loaded first."
  (let* ((store (get-store* universe (getf object-ref :store)))
	 (collection (get-collection* store (getf object-ref :collection))))
    
    ;;Incase the collection exists but has not been loaded try and load it.
    (when (and collection (not (data-objects collection)))
      (load-data collection))
    
    (unless collection
      (add-collection store collection)
      (load-data collection))
    collection))

(defgeneric parse-reference-data-object (parent-collection object &key &allow-other-keys)
  (:documentation "Parses the raw reference object read from file to its object reprensentation."))

(defmethod parse-reference-data-object ((parent-collection collection) object &key &allow-other-keys)
  (let ((universe (universe (store parent-collection))))
    
    (let* ((collection (load-object-reference-collection universe object))
	   (ref-object (and collection (index-lookup-uuid 
				      collection
				      (dig object :hash)))))     
      
      (unless ref-object

	#|

	(break "~A~% ~A~%~A" collection (dig tree :hash) tree)
	(break "~A" (index-lookup-uuid 
		     collection
		     (dig tree :hash)))
	|#
	
	(write-to-file  (format nil "~Aerror.err" (location (universe (store collection))))
			(list "Could not resolve reference  ~S" object)))

      ref-object)))


(defgeneric parse-child-data-object (parent-collection object &key &allow-other-keys)
  (:documentation "Parses the raw child object read from file to its object reprensentation."))

(defmethod parse-child-data-object ((parent-collection collection) object &key &allow-other-keys)
  (let* ((resolved-values (and object
			       (parse-data-object parent-collection object))))
    resolved-values))

(defgeneric parse-data-object (collection line &key &allow-other-keys)
  (:documentation "Parses the raw object read from file to its object reprensentation."))

(defmethod parse-data-object ((collection collection) object  &key top-level-p &allow-other-keys)
  (cond ((null object)
	 nil)
	(top-level-p
	 (parse-top-level-data-object collection object))
	((parse-object-p collection object)
	 (parse-child-data-object collection object))
	((parse-reference-object-p collection object)
	 (parse-reference-data-object collection object))
	((blob-ref-p object)
	 (read-blob (blob-ref-values object)))
	((atom object)
	 object)
        ((consp object)
	 (mapcar (lambda (child)
		   (parse-data-object collection child))
		 object))
        (t object)))
