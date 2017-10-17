;; sb-exit:quit を使っている警告を消す。
(declaim (sb-ext:muffle-conditions cl:warning))

;; エラーが起こったら終了する。
(setf sb-ext:*invoke-debugger-hook*
      (lambda (condition hook)
        (declare (ignore condition hook))
        (sb-ext:quit :recklessly-p t)))

(ql:quickload :jonathan :silent t)

(defun map-mode (data)
  (declare (ignore data))
  (let ((rnd '("UP" "DOWN" "RIGHT" "LEFT" "HEAL")))
    (princ (nth (random (length rnd)) rnd))))

(defun battle-mode (data)
  (declare (ignore data))
  (princ "SWING"))

(defun equip-mode (data)
  (declare (ignore data))
  (princ "YES"))

(defun levelup-mode (data)
  (declare (ignore data))
  (princ "HP"))

(defun main ()
  (format t "モゲAI~%")
  (ignore-errors
  (loop do
    (let ((json-data (jonathan:parse (read-line) :as :alist)))
      
      (cond
	((assoc "map" json-data :test #'equal)
	 (map-mode json-data))
	((assoc "battle" json-data :test #'equal)
	 (battle-mode json-data))
	((assoc "equip" json-data :test #'equal)
	 (equip-mode json-data))
	((assoc "levelup" json-data :test #'equal)
	 (levelup-mode json-data))
	(t (princ "UP")))
      (fresh-line)))))

(main)
       
