(load "item.lisp" :external-format :utf-8)
(ql:quickload "unix-opts")

(defparameter *tate* 11) ;;マップサイズ11
(defparameter *yoko* 11) ;;11
(defparameter *monsters* nil)
(defparameter *monster-builders* nil)
(defparameter *attack* '("突く" "ダブルスウィング" "薙ぎ払う" "待機" "回復薬"))

(defparameter *battle?* nil)
(defparameter *monster-num* 6)
(defparameter *monster-level* 1) ;;階数によるモンスターのレベル
(defparameter *boss?* 0)
(defparameter *end* 0)
(defparameter *lv-exp* 100)
(defparameter *start-time* 0)
(defparameter *ha2ne2* nil)
(defparameter *copy-buki* (copy-tree *buki-d*))
(defparameter *proc* nil)
(defparameter *ai* nil)
(defparameter *ai-name* nil)
(defparameter *ai-command-line* nil)

(defparameter *battle-delay-seconds* 0.3)
(defparameter *map-delay-seconds* 0.3)

(defparameter *gamen-clear?* t)

;;(defparameter p1 (make-player))
(defstruct player
  (hp 30)
  (maxhp 30)
  (agi 30)
  (maxagi 30)
  (str 30)
  (maxstr 30)
  (posy 0)
  (posx 0)
  (map 1) ;;マップ深度
  (heal 2) ;;持ってる薬の数
  (hammer 5) ;;持ってるハンマーの数
  (level 1)
  (exp 0)
  (buki '("なし" 0 0 0))
  (msg nil)
  (item nil) ;;持ち物リスト
  (drop nil) ;;敵からのドロップ品一時保管場所
  (monster-num 0)) ;;戦闘時の敵の総数

(defstruct donjon
  (map nil)  ;;マップ
  (tate 11)  ;;縦幅
  (yoko 11)  ;;横幅
  (stop-list nil)) ;;行き止まりリスト

(load "maze-test.lisp" :external-format :utf-8)

;;json用player情報リスト作成
(defun player-list (p)
  (list :|player|
	 (list :|hp|        (player-hp p)    :|maxhp|  (player-maxhp p)
	       :|str|       (player-str p)   :|maxstr| (player-maxstr p)
	       :|agi|       (player-agi p)   :|maxagi| (player-maxagi p)
	       :|level|     (player-level p) :|exp|    (player-exp p)
	       :|heal|      (player-heal p)  :|hammer| (player-hammer p)
	       :|map-level| (player-map p)
	       :|buki|      (player-buki p)
	       :|pos|   (list :|x| (player-posx p) :|y| (player-posy p)))))

(defun init-data ()
  (setf *battle?* nil
	*monster-num* 6
	*monster-level* 1
	*boss?* 0
	*end* 0
	*lv-exp* 100
	*start-time* (get-internal-real-time)
	*ha2ne2* nil
	*copy-buki* (copy-tree *buki-d*)))

(defun get-ai-command-line ()
  (if *ai-command-line*
      *ai-command-line*
    (with-open-file (in "ai.txt" :direction :input)
                    (format nil "~a" (read-line in nil)))))

;;ai.txtからai起動するコマンドを読み込む
;;*ai* ストリーム？
(defun load-ai ()
  (let* ((hoge (ppcre:split #\space (get-ai-command-line))))
    (setf *proc* (sb-ext:run-program
                  (car hoge) (cdr hoge)
                  :input :stream
                  :output :stream
                  :wait nil
                  :search t))
    (setf *ai* (make-two-way-stream (process-output *proc*) (process-input *proc*)))
    (setf *ai-name* (read-line *ai*))))

;;画面クリア？
(defun sh (cmd)
  (sb-ext:run-program "/bin/sh" (list "-c" cmd) :input nil :output *standard-output*))

(defun gamen-clear ()
  (when *gamen-clear?*
    (sh "clear")))

;;ゲームオーバーメッセージ
(defun game-over-message (p)
  (format t "Game Over.~%")
  (format t "あなたは地下~d階で力尽きた。~%" (player-map p)))

;;勝利メッセージ
(defun victory-message ()
  (gamen-clear)
  (show-pick-monsters)
  (format t "~%~%")
  (format t "「大 勝 利 ！」~%~%"))

;;レベルアップポイント振り分け入出力
(defun point-wake (p n)
  (if (= n 0)
      ;;振り分け終わったらステータス全回復
      (setf (player-hp p) (player-maxhp p)
	    (player-str p) (player-maxstr p)
	    (player-agi p) (player-maxagi p))
      (let ((str nil))
	(format *ai* "~a~%" (jonathan:to-json (append (list :|levelup| 1)(player-list p))))
	(finish-output *ai*)
	(setf str (read-line *ai*))
	(cond
	  ((string= str "HP")
	   (incf (player-maxhp p))
	   (point-wake p (1- n)))
	  ((string= str "STR")
	   (incf (player-maxstr p))
	   (point-wake p (1- n)))
	  ((string= str "AGI")
	   (incf (player-maxagi p))
	   (point-wake p (1- n)))
	  (t nil)))))
;;戦闘終了後レベルアップ
(defun level-up (p)
  (loop while (>= (player-exp p) *lv-exp*) do
    (let ((point (randval 3)))
      (point-wake p point)
      (decf (player-exp p) *lv-exp*)
      (incf (player-level p))
      (incf *lv-exp* 10))))
;;戦闘終了後アイテム入手
(defun item-drop? (p)
  (gamen-clear)
  (dolist (item (player-drop p))
    (let ((buki (assoc item *event-buki* :test #'equal)))
      (cond
	(buki (equip? p buki))
	((string= item "ハンマー")
	 (format t "「ハンマーを拾った！」~%")
	 (incf (player-hammer p)))
	((string= item "回復薬")
	 (format t "「回復薬を拾った！」~%")
	 (incf (player-heal p))))
      (setf (player-drop p) nil)))) ;;ドロップ品を消す
;;バトル開始
(defun orc-battle (p)
  (cond ;;モンスターズ作成
    ((= *boss?* 1) ;;ラスボス
     (boss-monsters p 0))
    ((= *boss?* 2) ;;中ボス
     (boss-monsters p 1))
    ((= *boss?* 0) ;;雑魚
     (init-monsters p)))
  (game-loop p) ;;バトルループ
  (gamen-clear)
  (cond
    ((player-dead p) ;;プレイヤーが死んだとき
     (game-over-message p)
     (setf *end* 2))
    ((= *end* 2) ;;エラー終了
     nil)
    (t ;;(monsters-dead) 敵を倒したとき
     (level-up p) ;;レベルアップ処理
     (if (player-drop p)
	 (item-drop? p)) ;;アイテム入手処理
     (cond
       ((= *boss?* 1)
	(setf *end* 1)
	(victory-message)) ;;ラスボスならエンディングへ
       ((= *boss?* 2) (setf *ha2ne2* t))) ;;中ボス倒したフラグ
     ;;バトルフラグとボスフラグを初期化
     (setf *battle?* nil
	   *boss?* 0))))

;;バトル時、プレイヤーが死ぬかモンスターが全滅するまでループ
(defun game-loop (p)
  (unless (or (player-dead p) (monsters-dead))
    (dotimes (k (1+ (truncate (/ (max 0 (player-agi p)) 15))))
      (unless (or (monsters-dead) (= *end* 2))
	(player-attack2 p)))
    (cond
      ((= *end* 2) ;;エラー集雨量
       nil)
      ((null (monsters-dead))
       (map 'list
            (lambda (m)
              (or (monster-dead m) (monster-attack m p)))
            *monsters*)
       (game-loop p)))))

;;プレイヤーの生死判定
(defun player-dead (p)
  (<= (player-hp p) 0))
;;プレイヤーのステータス表示(バトル時)
(defun show-player (p)
  (format t "Lv ~d, ~a : HP ~d/~d 力 ~d/~d 素早さ ~d/~d ~%"
	      (player-level p) *ai-name* (player-hp p) (player-maxhp p)  (player-str p) (player-maxstr p)
	      (player-agi p) (player-maxagi p)))

;;ステータスとバトルコマンド表示
(defun status-and-command (p)
  (format t "------------------------------------------------------------~%")
  (format t ":ステータス~%")
  (loop for i from 0 to 4
	do
	   (case i
	     (0 (format t "L v  ~2d~%" (player-level p)))
	     (1 (format t "H P  ~2d/~2d~%" (player-hp p) (player-maxhp p)))
	     (2 (format t "ATK  ~2d/~2d~%" (player-str p) (player-maxstr p)))
	     (3 (format t "AGI  ~2d/~2d~%" (player-agi p) (player-maxagi p)))
	     (4 (format t "EXP ~3d/~3d~%" (player-exp p) *lv-exp*)))))
;;攻撃方法入出力
(defun player-attack2 (p)
  (let ((str-l nil) (str nil) (act nil))
    (format *ai* "~a~%" (jonathan:to-json (append (list :|battle| 1) (monster-list) (player-list p))))
    (finish-output *ai*)
    (setf str-l (read-line *ai*)
	  str (ppcre:split #\space str-l)
	  act (car str))
    (cond
      ((find act '("HEAL" "SWING" "STAB" "DOUBLE") :test #'equal)
       (gamen-clear)
       (show-pick-monsters)
       (status-and-command p)
       (cond
	 ((string= act "HEAL")
	  (use-heal p))
	 ((string= act "SWING")
	  (format t "「なぎはらい！」~%") 
	  (dotimes (x (1+ (randval (truncate (/ (player-str p) 3)))))
	    (unless (monsters-dead)
	      (monster-hit2 p (random-monster) 1))))
	 (t
	  (cond
	    ((string= act "STAB")
	     (format t "「~c に斬りかかった！」~%" (number->a (parse-integer (cadr str))))
	     (let ((m (aref *monsters* (parse-integer (cadr str)))))
	       (monster-hit2 p m (+ 2 (randval (ash (player-str p) -1))))))
	    ((string= act "DOUBLE")
	     (format t "「~c と ~c にダブルアタック！」~%" (number->a (parse-integer (second str)))
		     (number->a (parse-integer (third str))))
	     (let ((m (aref *monsters* (parse-integer (second str))))
		   (x (randval (truncate (/ (player-str p) 6)))))
	       (monster-hit2 p m x) ;;選ばれたモンスターにダメージ与える
	       (unless (monsters-dead) ;;生き残ってるモンスターがいるなら２回目の攻撃
		 (let ((m2 (aref *monsters* (parse-integer (third str)))))
		   (if (monster-dead m2)
		       (monster-hit2 p (random-monster) x)
		       (monster-hit2 p m2 x)))))))))
       (sleep *battle-delay-seconds*))
      (t (format t "~A~%" str-l) ;;規定文字列以外の表示(エラーとか)
	 (setf *end* 2)))))
	   
;;n内の１以上の乱数
(defun randval (n)
  (1+ (random (max 1 n))))

;;ランダムでモンスターを選択
(defun random-monster ()
  (let ((m (aref *monsters* (random (length *monsters*)))))
    (if (monster-dead m)
	(random-monster)
	m)))
;;a→ 0 b→ 1 c→ 2 ...
(defun ascii->number (x)
  (if (null (numberp x))
      (- (char-code (char (symbol-name x) 0)) 65)))

;;(カーソル付きで)敵表示
(defun show-pick-monsters ()
  (fresh-line)
  (format t "-----------------------敵が現れた！-------------------------~%")
  (format t "敵:~%")
  (loop for m across *monsters*
	for x = 0 then x
	do
	   (cond
	     ((monster-dead m)
	      (format t "~a" (minimum-column 3 ""))
	      (format t "~c."  (number->a x))
	      (incf x)
	      (if (> (monster-damage m) 0)
		  (progn
		    (format t "~a" (minimum-column 31 "**死亡**"))  
		    (format t "~d のダメージを与え倒した！~%" (monster-damage m)))
		  (format t "**死亡**~%")))
	     (t
	      (format t "~a" (minimum-column 3 ""))
	      (format t "~c."  (number->a x))
	      (incf x)
	      (format t "~a"
			  (minimum-column 9 (format nil "(HP=~d) " (monster-health m))))
	      (format t "~a" (minimum-column 22 (monster-show m)))
	      (if (> (monster-damage m) 0)
		  (format t "~d のダメージを与えた！~%" (monster-damage m))
		  (fresh-line))))
	   (setf (monster-damage m) 0)));;与えたダメージリセット


;;モンスター配列をリスト化
(defun monster-list ()
  (let ((lst nil))
    (loop for m across *monsters*
	  for i from 0 do
      (case (type-of m)
	(orc (push (list :|name| "オーク" :|number| i :|level| (orc-club-level m)
					  :|hp| (monster-health m)) lst))
	(hydra (push (list :|name| "ヒドラ" :|number| i :|level| (monster-health m)
					    :|hp| (monster-health m)) lst))
	(slime-mold (push (list :|name| "スライム" :|number| i
				:|level| (slime-mold-sliminess m)
						   :|hp| (monster-health m)) lst))
	(brigand (push (list :|name| "ブリガンド" :|number| i :|level| (brigand-atk m)
						  :|hp| (monster-health m)) lst))
	(yote1 (push (list :|name| "メタルヨテイチ" :|number| i :|level| (yote1-atk m)
						    :|hp| (monster-health m)) lst))
	(ha2ne2 (push (list :|name| "ハツネツエリア" :|number| i :|level| 50
						     :|hp| (monster-health m)) lst))
	(boss (push (list :|name| "もげぞう" :|number| i :|level| 100
			  :|hp| (monster-health m)) lst))))
    (list :|monsters| lst)))

;;ランダムなモンスターグループを作る
(defun init-monsters (p)
  (setf *monsters*
	(map 'vector
	     (lambda (x)
	       ;;(funcall (nth (random (length *monster-builders*)) *monster-builders*)))
               (let ((y (random 101)))
		 ;;モンスターの出現率
                 (cond
                   ((<= 0 y 25) (make-orc))
                   ((<= 26 y 50) (make-hydra))
                   ((<= 51 y 75) (make-slime-mold))
                   ((<= 76 y 99) (make-brigand))
                   (t (make-yote1 :health 3)))))
	     (make-array (setf (player-monster-num p)
			       (randval (+ *monster-num* (floor (player-level p) 4))))))))
;;配列の０番目にボス、あとはランダムなモンスター(m=0,もげぞう m=1,ハツネツ)
(defun boss-monsters (p m)
  (let ((hoge 0))
    (setf *monsters*
	  (map 'vector
	       (lambda (x)
		 (if (= hoge 0)
		     (progn (incf hoge)
			    (cond
			      ((= m 0) (make-boss :health 300))
			      ((= m 1) (make-ha2ne2 :health 220))))
		     (funcall (nth (random (length *monster-builders*))
				   *monster-builders*))))
	       (make-array 10)))
    (setf (player-monster-num p) 10)))

;;モンスターの生死判定
(defun monster-dead (m)
  (<= (monster-health m) 0))
;;モンスターグループが全滅したか判定
(defun monsters-dead ()
  (every #'monster-dead *monsters*))
;; 0->a 1->b 2->c ...
(defun number->a (x)
  (code-char (+ x 97)))

;;-----------------------------------------------------------------------
;;モンスターデータ作成用
(defstruct monster
  (health (randval (+ 10 *monster-level*)))
  (damage  0))

;;-----------------敵からのアイテムドロップ-------------------------
(defun yote1-drop (p)
  (if (= 1 (random 100))
      (push "メタルヨテイチの剣" (player-drop p))))
(defun ha2ne2-drop (p)
  (if (= 0 (random 1)) ;;とりあえず100%
      (push "ハツネツの剣" (player-drop p))))

(defun orc-drop (p)
  (if (= 1 (random 20))
      (push "ハンマー" (player-drop p))))
(defun slime-drop (p)
  (if (= 1 (random 20))
      (push "回復薬" (player-drop p))))
;;-----------------------------------------------------------------
;;モンスターの受けたダメージ処理
(defmethod monster-hit2 (p m x)
  (decf (monster-health m) x)
  (incf (monster-damage m) x)
  ;;倒したら経験値取得
  (if (monster-dead m)
      (case (type-of m)
        (ha2ne2
	 (ha2ne2-drop p)
	 (incf (player-exp p) 99))
	(orc
	 (orc-drop p)
	 (incf (player-exp p) 2))
	(slime-mold
	 (slime-drop p)
	 (incf (player-exp p) 3))
	(hydra
	 (incf (player-exp p) 4))
	(brigand
	 (incf (player-exp p) 5)))))


(defmethod monster-attack (m p))
;;--------中ボス------------------------------------------------------------------------
(defstruct (ha2ne2 (:include monster)) (h-atk 8))
(defmethod monster-show ((m ha2ne2))
  (format nil "ボス：ハツネツエリア"))
(defmethod monster-attack ((m ha2ne2) (p player))
  (let ((x (+ 3 (randval (+ (player-level p) (ha2ne2-h-atk m))))))
    (case (random 3)
      (0
       (format t "「ハツネツの攻撃。~dのダメージをくらった。」~%" x)
       (decf (player-hp p) x))
      (1
       (let ((dame-str (- (player-str p) x)))
	 (if (= (player-str p) 0)
	     (progn (format t "「ネコPパンチ。HPが~d下がった。」~%" x)
		    (decf (player-hp p) x))
	     (if (>= dame-str 0)
		 (progn (format t "「ネコPパンチ。力が~d下がった。」~%" x)
			(decf (player-str p) x))
		 (progn (format t "「ネコPパンチ。力が~d下がった。」~%" (player-str p))
			(setf (player-str p) 0))))))
      (2
       (format t "「ハツネツが料理してご飯を食べている。ハツネツのHPが~d回復した！」~%" x)
       (incf (monster-health m) x)))))

;;--------ボス------------------------------------------------------------------------
(defstruct (boss (:include monster)) (boss-atk 10))
(defmethod monster-show ((m boss))
  (format nil "ボス：もげぞう"))
(defmethod monster-attack ((m boss) (p player))
  (let ((x (+ 5 (randval (+ (player-level p) (boss-boss-atk m))))))
    (case (random 5)
      ((0 3)
       (format t "「もげぞうの攻撃。~dのダメージをくらった。」~%" x)
       (decf (player-hp p) x))
      ((1 4)
       (let ((dame-agi (- (player-agi p) x)))
	 (if (= (player-agi p) 0)
	     (progn (format t "「もげぞうの攻撃。~dのダメージをくらった。」~%" x)
		    (decf (player-hp p) x))
	     (if (>= dame-agi 0)
		 (progn (format t "「もげぞうの不思議な踊り。素早さが~d下がった。」~%" x)
			(decf (player-agi p) x))
		 (progn (format t "「もげぞうの不思議な踊り。素早さが~d下がった。」~%" (player-agi p))
			(setf (player-agi p) 0))))))
      (2
       (let ((dame-agi (- (player-agi p) x))
	     (dame-str (- (player-str p) x)))
	 (format t "「もげぞうのなんかすごい攻撃！すべてのステータスが~d下がった！」~%" x)
	 (decf (player-hp p) x)
	 (if (>= dame-agi 0)
	     (decf (player-agi p) x)
	     (setf (player-agi p) 0))
	 (if (>= dame-str 0)
	     (decf (player-str p) x)
	     (setf (player-str p) 0)))))))

;;-------------------メタルヨテイチ--------------------------------------------------
(defstruct (yote1 (:include monster))
  (atk    (randval (+ 10 *monster-level*))))
;;(push #'make-yote1 *monster-builders*)

(defmethod monster-show ((m yote1))
  (format nil "メタルヨテイチ"))

(defmethod monster-attack ((m yote1) (p player))
  (let ((atk (randval (yote1-atk m))))
    (case (random 2)
      (0 (format t "「メタルヨテイチは何もしていない。」~%"))
      (1 (format t "「メタルヨテイチが突然殴り掛かってきた。~dのダメージを受けた。」~%" atk)
       (decf (player-hp p) atk)))))

(defmethod monster-hit2 ((p player) (m yote1) x)
  (decf (monster-health m))
  (incf (monster-damage m))
  (if (monster-dead m)
      (progn (incf (player-exp p) 100)
	     (yote1-drop p))))

;;-------------------オーク---------------------------------------------------------
(defstruct (orc (:include monster))
  (club-level (randval (+ 8 *monster-level*)))
  (name "オーク"))

(push #'make-orc *monster-builders*)

(defmethod monster-show ((m orc))
  (let ((x (orc-club-level m)))
    (cond
      ((>= 3 x 1) (format nil "か弱いオーク"))
      ((>= 6 x 4) (format nil "日焼けしたオーク"))
      ((>= 9 x 7) (format nil "邪悪なオーク"))
      (t (format nil "マッチョオーク")))))

(defmethod monster-attack ((m orc) (p player))
  (let ((x (randval (orc-club-level m))))
    (format t (monster-show m))
    (format t "が棍棒で殴ってきて ~d のダメージをくらった。~%" x)
    (decf (player-hp p) x)))



;;-------------------ヒドラ------------------------------
(defstruct (hydra (:include monster)))
(push #'make-hydra *monster-builders*)


(defmethod monster-show ((m hydra))
  (let ((x (monster-health m)))
    (cond
      ((>= 3 x 1)
       (format nil "意地悪なヒドラ"))
      ((>= 6 x 4)
       (format nil "腹黒いヒドラ"))
      ((>= 9 x 7)
       (format nil "強欲なヒドラ"))
      (t (format nil "グレートヒドラ")))))


(defmethod monster-attack ((m hydra) (p player))
  (let ((x (randval (ash (monster-health m) -1))))
    (format t (monster-show m))
    (format t "の攻撃 ~dのダメージを食らった。~%" x)
    (format t (monster-show m))
    (format t "の首が一本生えてきた！~%")
    (incf (monster-health m))
    (decf (player-hp p) x)))


;;-------------------スライム------------------------------
(defstruct (slime-mold (:include monster)) (sliminess (randval (+ 5 *monster-level*))))
(push #'make-slime-mold *monster-builders*)

(defmethod monster-show ((m slime-mold))
  (let ((x (slime-mold-sliminess m)))
    (cond
      ((<= 1 x 3) (format nil "ベタベタなスライム"))
      ((<= 4 x 6) (format nil "ベトベトなスライム"))
      ((<= 7 x 9) (format nil "ベチョベチョなスライム"))
      (t (format nil "ヌルヌルなスライム")))))

(defmethod monster-attack ((m slime-mold) (p player))
  (let ((x (randval (slime-mold-sliminess m))))
    (cond
      ((> (player-agi p) 0)
       (let ((dame-agi (- (player-agi p) x)))
	 (if (>= dame-agi 0)
	     (progn (format t (monster-show m))
		    (format t "は足に絡みついてきてあなたの素早さが ~d 下がった！~%" x)
		    (decf (player-agi p) x))
	     (progn (format t (monster-show m))
		    (format t "は足に絡みついてきてあなたの素早さが ~d 下がった！~%"
				(player-agi p))
		    (setf (player-agi p) 0)))))
      (t (format t (monster-show m))
	 (format t "が何か液体を吐きかけてきて ~d ダメージくらった！~%" x)
	 (decf (player-hp p) x)))))

;;-------------------ブリガンド------------------------------
(defstruct (brigand (:include monster)) (atk (+ 2 (random *monster-level*))))
(push #'make-brigand *monster-builders*)

(defmethod monster-show ((m brigand))
  (let ((x (brigand-atk m)))
    (cond
      ((<= 1 x 3) (format nil "毛の薄いブリガンド"))
      ((<= 4 x 6) (format nil "ひげもじゃなブリガンド"))
      ((<= 7 x 9) (format nil "胸毛の濃いブリガンド"))
      (t (format nil "禿げてるブリガンド")))))

(defmethod monster-attack ((m brigand) (p player))
  (let ((x (max (player-hp p) (player-agi p) (player-str p)))
	(damage (brigand-atk m)))
    (format t (monster-show m))
    (cond ((= x (player-hp p))
	   (format t "のスリングショットの攻撃で ~d ダメージくらった！~%" damage)
	   (decf (player-hp p) damage))
	  ((= x (player-agi p))
	   (format t "は鞭であなたの足を攻撃してきた！素早さが ~d 減った！~%" damage)
	   (decf (player-agi p) damage))
	  ((= x (player-str p))
	   (format t "は鞭であなたの腕を攻撃してきた！力が ~d 減った！~%" damage)
	   (decf (player-str p) damage)))))

;;-----------------------マップ------------------------------------------------------------
;;---------------------------------------------------------------------------------------
;;マップ移動
(defun show-msg (p)
  (if (player-msg p)
      (format t "~a~%" (player-msg p)))
  (setf (player-msg p) nil))

;;文字幅取得
(defun moge-char-width (char)
    (if (<= #x20 (char-code char) #x7e)
        1
	2))
;;string全体の文字幅
(defun string-width (string)
  (apply #'+ (map 'list #'moge-char-width string)))
;;最低n幅もったstring作成
(defun minimum-column (n string)
  (let ((pad (- n (string-width string))))
    (if (> pad 0)
	(concatenate 'string string (make-string pad :initial-element #\ ))
        string)))



(defun map-type (num)
  (case num
    (30 "ロ") ;; 壁
    (40 "ロ") ;; 壊せない壁
    (0  "　")
    (1  "主") ;; プレイヤーの位置
    (4  "薬") ;; 薬
    (5  "ボ") ;;ボス
    (3  "宝") ;; 宝箱
    (2  "下") ;; 下り階段
    (6  "イ") ;; イベント
    (7  "ハ") ;; 中ボス ハツネツエリア
    ))

;;マップ表示+マップの情報リスト作成
(defun show-map (map p)
    (gamen-clear)
    (format t "地下~d階  " (player-map p))
    (show-player p)
    (format t "~%")
    (loop for i from 0 below (donjon-tate map) do
      (loop for j from 0 below (donjon-yoko map) do
	(let ((x (aref (donjon-map map) i j)))
	  (format t "~a" (map-type x))
	  (if (= j (- (donjon-yoko map) 1))
	      (case i
		(0 (format t " 武器[i]   ~a~%" (first (player-buki p))))
		(1 (format t " 回復薬    ~d個~%" (player-heal p)))
		(2 (format t " ハンマー  ~d個~%" (player-hammer p)))
		(3 (format t " Exp       ~d/~d~%" (player-exp p) *lv-exp*))
		(5 (format t " 薬を使う[q]~%"))
		(6 (format t " 終わる[r]~%"))
	      (otherwise (fresh-line)))))))
    (show-msg p))

(defun map-data-list (map)
  (let ((blocks nil)
	(walls nil)
	(items nil)
	(boss nil)
	(kaidan nil)
	(ha2 nil)
	(events nil))
    (loop for i from 0 below (donjon-tate map) do
      (loop for j from 0 below (donjon-yoko map) do
	(let ((x (aref (donjon-map map) i j)))
	  (case x
	    (30 (push (list j i) blocks)) ;; 壁
	    (40 (push (list j i) walls)) ;; 壊せない壁
	    (5  (push (list j i) boss)) ;;ボス
	    (3  (push (list j i) items)) ;; 宝箱
	    (2  (push (list j i) kaidan)) ;; 下り階段
	    (6  (push (list j i) events)) ;; イベント
	    (7  (push (list j i) ha2)))))) ;; 中ボス ハツネツエリア
    (list :|blocks| blocks :|walls| walls :|items| items :|boss| boss :|kaidan| kaidan
	  :|events| events :|ha2| ha2)))
    

;;マップ情報とプレイヤー情報を渡して移動先を受け取る
(defun map-move (map p)
  (unless (or *battle?* (= *end* 2))
    ;;バトル時と差別化するため先頭にmapってのいれとく.1は特に意味なし
    (let ((json (append (list :|map| 1) (player-list p) (map-data-list map)))
	  (str nil))
      (format *ai* "~a~%" (jonathan:to-json json)) ;;データ送る
      (finish-output *ai*) ;;なぞ
      (setf str (read-line *ai*)) ;;データもらう
      
      (cond
	((find str '("UP" "DOWN" "RIGHT" "LEFT" "HEAL") :test #'equal)
	 (show-map map p)
	 (cond 
	   ((equal str "UP") (update-map map p -1 0))
	   ((equal str "DOWN") (update-map map p 1 0))
	   ((equal str "RIGHT") (update-map map p 0 1))
	   ((equal str "LEFT") (update-map map p 0 -1))
	   ((equal str "HEAL") (use-heal p)))
	 (format t "~a~%" str) ;;アクション表示
	 (sleep *map-delay-seconds*))
	(t (format t "~a~%" str))) ;;規定の出力以外(エラーとか)を表示
      (map-move map p))))

;;エンディング
(defun ending ()
  (let* ((ss (floor (- (get-internal-real-time) *start-time*) 1000))
	 (h (floor ss 3600))
	 (m (floor (mod ss 3600) 60))
	 (s (mod ss 60)))
    (if *ha2ne2*
	(format t "~%「あなたは見事もげぞうの迷宮を完全攻略した！」~%")
	(progn (format t "~%「もげぞうを倒したが、逃したハツネツエリアが新たな迷宮を作り出した・・・」~%")
	       (format t "「が、それはまた別のお話。」~%")))
    (format t "クリアタイムは~2,'0d:~2,'0d:~2,'0d でした！~%" h m s)
    (ranking-dialog ss)))
    ;;(continue-message)))
;;プレイヤーが死ぬか戦闘に入るか*end*=2になるまでループ
(defun main-game-loop (map p)
  (unless (or (= *end* 2) (player-dead p))
    (map-move map p)
    (if *battle?*
	(orc-battle p))
    (cond
      ((= *end* 1) ;;ゲームクリア
       (ending))
      ((= *end* 2) ;;規定の文字列以外で終了
       nil)
      ((= *end* 0) ;;ゲームループ
       (main-game-loop map p)))))
;;ゲーム開始
(defun main ()
  (parse-args)
  (load-ai)
  #+nil (setf *random-state* (make-random-state t))
  (let* ((p (make-player)) 
	 (map (make-donjon))
	 (err nil))
    (init-data) ;;データ初期化
    (maze map p) ;;マップ生成
    (main-game-loop map p)))

(defun set-random-seed (n)
  (dotimes (i n)
    (random 2)))

(defun parse-args ()
  (opts:define-opts
   (:name :help
          :description "このヘルプを表示"
          :short #\h
          :long "help")
   (:name :random-seed
          :description "乱数の種(非負整数)"
          :short #\r
          :long "random-seed"
          :arg-parser #'parse-integer)
   (:name :delay
          :description "表示のディレイ(小数可)"
          :short #\d
          :long "delay"
          :arg-parser #'read-from-string)
   (:name :no-clear
          :description "画面のクリアをしない"
          :long "no-clear")
   (:name :ai
          :description "AIプログラムを起動するコマンドライン"
          :long "ai"
          :arg-parser #'identity))
  (let ((options (opts:get-opts)))
    (when (getf options :help)
      (opts:describe
       :prefix "もげRPGserver"
       :usage-of "mogeRPGserver")
      (sb-ext:exit))
    (when (getf options :delay)
      (setf *battle-delay-seconds* (getf options :delay)
            *map-delay-seconds* (getf options :delay)))
    (if (getf options :random-seed)
        (set-random-seed (getf options :random-seed))
      (setf *random-state* (make-random-state t))) ; 環境から乱数を取得。
    (when (getf options :no-clear)
      (setf *gamen-clear?* nil))
    (when (getf options :ai)
      (setf *ai-command-line* (getf options :ai)))))

;;壁破壊
(defun kabe-break (map p y x)
  (if (>= (random 10) 3)
      (setf (aref map (+ (player-posy p) y) (+ (player-posx p) x)) 0)
      (setf (aref map (+ (player-posy p) y) (+ (player-posx p) x)) 3))
  (decf (player-hammer p)))
;;(format t "「壁を壊しました。」~%"))))


;;武器装備してステータス更新
(defun equip-buki (item p)
  (incf (player-hp p)     (- (third item) (third (player-buki p))))
  (incf (player-maxhp p)  (- (third item) (third (player-buki p))))
  (incf (player-str p)    (- (second item) (second (player-buki p))))
  (incf (player-maxstr p) (- (second item) (second (player-buki p))))
  (incf (player-agi p)    (- (fourth item) (fourth (player-buki p))))
  (incf (player-maxagi p) (- (fourth item) (fourth (player-buki p))))
  (setf (player-buki p) item))

;;装備してる武器と見つけた武器のリスト
(defun equip-list (p item)
  (let ((now-buki (player-buki p)))
    (append (list :|equip| 1)
	    (list :|now|
		  (list :|name| (first now-buki) :|str| (second now-buki)
			:|hp| (third now-buki) :|agi| (fourth now-buki)))
	    (list :|discover|
		  (list :|name| (first item) :|str| (second item)
			:|hp| (third item) :|agi| (fourth item))))))

;;装備モード入出力
(defun equip-select (p item)
  (let ((str nil))
    (format *ai* "~a~%" (jonathan:to-json (equip-list p item)))
    (finish-output *ai*)
    (setf str (read-line *ai*))
    (cond
      ((string= str "YES")
       (format t "「~aを装備した。」~%" (first item))
       (equip-buki item p))
      (t nil))))

;;見つけた武器を装備するか
(defun equip? (p item)
  (format t "「~aを見つけた」~%" (first item))
  (format t "現在の装備品：~a 攻撃力:~d HP:~d 素早さ:~d~%"
	      (first (player-buki p)) (second (player-buki p))
	      (third (player-buki p)) (fourth (player-buki p)))
  (format t "発見した装備：~a 攻撃力:~d HP:~d 素早さ:~d~%"
	      (first item) (second item) (third item) (fourth item))
  (format t "「装備しますか？」(z:装備 x:捨てる c:袋にしまう)~%")
  (equip-select p item))

(defun hummer-get (p)
  (setf (player-msg p) "「ハンマーを見つけた。」")
  (incf (player-hammer p)))

(defun kusuri-get (p)
  (setf (player-msg p) "「回復薬を見つけた。」")
  (incf (player-heal p)))



;;重み付け抽選-----------------------------------------------
(defun rnd-pick (i rnd lst len)
  (if (= i len)
      (1- i)
      (if (< rnd (nth i lst))
	  i
	  (rnd-pick (1+ i) (- rnd (nth i lst)) lst len))))
;;lst = *copy-buki*
(defun weightpick (lst)
  (let* ((lst1 (mapcar #'cdr lst))
	 (total-weight (apply #'+ lst1))
	 (len (length lst1))
	 (rnd (random total-weight)))
    (car (nth (rnd-pick 0 rnd lst1 len) lst))))
;;------------------------------------------------------------
;; lst = *copy-buki*
;;*copy-buki*の確率の部分をずらす
(defun omomin-zurashi (lst)
  (let ((buki (mapcar #'car lst))
	(omomi (mapcar #'cdr lst)))
    (setf omomi (butlast omomi))
    (push 10 omomi)
    (mapcar #'cons buki omomi)))

;;---------------------------------------------
;;武器ゲット２ 全アイテムからランダム
(defun item-get2 (p)
  (case (random 7)
    ((0 1 2 5) ;;武器ゲット
     (equip? p (weightpick *copy-buki*)))
    ((3 6) (hummer-get p)) ;;ハンマーゲット
    (4 (kusuri-get p)))) ;;回復薬ゲット

;;プレイヤーの場所更新
(defun update-player-pos (p x y map)
  (setf (aref map (+ (player-posy p) y) (+ (player-posx p) x)) 1)
  (setf (aref map (player-posy p) (player-posx p)) 0)
  (setf (player-posy p) (+ (player-posy p) y)
	(player-posx p) (+ (player-posx p) x)))
;;マップ設定
(defun set-map (map p moto)
  (loop for i from 0 below (donjon-tate map) do
    (loop for j from 0 below (donjon-yoko map) do
      (if (= (aref moto i j) 1)
	  (setf (player-posx p) j
		(player-posy p) i))
      (setf (aref (donjon-map map) i j) (aref moto i j)))))

;;100階イベント
(defun moge-event (p)
  (if (equal (car (player-buki p)) "もげぞーの剣")
      (progn
        (format t "~%「もげぞーの剣が輝き出し、もげぞうの剣に進化した！」~%")
        (equip-buki (assoc "もげぞうの剣" *event-buki* :test #'equal) p))
      (format t "~%「なにも起こらなかった。」~%")))
;;移動後のマップ更新
(defun update-map (map p y x)
  (case (aref (donjon-map map) (+ (player-posy p) y) (+ (player-posx p) x))
    (30 ;;壊せる壁
     (if (and (> (player-hammer p) 0)
	      (> (- (donjon-tate map) 1) (+ (player-posy p) y) 0)
	      (> (- (donjon-yoko map) 1) (+ (player-posx p) x) 0))
	 (kabe-break (donjon-map map) p y x)))
	 ;;(format t "「そっちには移動できません！！」~%")))
    (40 ;;壊せない壁
     nil)
    (2 ;;くだり階段
     (incf (player-map p))
     (maze map p)
     ;;２階降りるごとにハンマーもらえる
     (if (= (mod (player-map p) 2) 0)
	 (incf (player-hammer p)))
     ;;５階降りるごとに宝箱の確率変わる
     (if (= (mod (player-map p) 5) 0)
	 (setf *copy-buki* (omomin-zurashi *copy-buki*)))
     ;;７階降りるごとに敵のレベル上がる
     (if (= (mod (player-map p) 7) 0)
	 (incf *monster-level*)))
    (3 ;;宝箱
     (item-get2 p)
     (update-player-pos p x y (donjon-map map)))
    (5 ;;ボス
     (update-player-pos p x y (donjon-map map))
     (setf *battle?* t
	   *boss?* 1))
    (6 ;;イベント
     (update-player-pos p x y (donjon-map map))
     (moge-event p))
    (7 ;;中ボス
     (update-player-pos p x y (donjon-map map))
     (setf *battle?* t
           *boss?* 2))
    (otherwise
     (update-player-pos p x y (donjon-map map))
     (if (= (randval 13) 1) ;;敵との遭遇確率
	 (setf *battle?* t)))))
;;薬を使う
(defun use-heal (p)
  (cond
    ((>= (player-heal p) 1)
     (format t "~%「回復薬を使った。」~%")
     (decf (player-heal p))
     (setf (player-hp p)  (player-maxhp p)
	   (player-agi p) (player-maxagi p)
	   (player-str p) (player-maxstr p)))
    (t
     (format t "~% 「回復薬を持っていません！」~%"))))


;; ランキングは (("一位の名前" 秒数) ("二位の名前" 秒数) ...) の形の属
;; 性リストで、秒数でソートされて保存される。
(defconstant +ranking-file-name+ "ranking.lisp") ; ランキングファイルの名前
(defconstant +ranking-max-length+ 10)            ; ランキングに登録するエントリーの最大数

;; 合計の秒数を (時 分 秒) のリストに変換する。
(defun total-seconds-to-hms (ss)
  (let* ((h (floor ss 3600))
         (m (floor (mod ss 3600) 60))
         (s (mod ss 60)))
    (list h m s)))

;; プレーヤー name の記録 total-seconds を ranking に登録し、新しいラ
;; ンキングデータを返す。ranking に既にプレーヤーの項目がある場合は、
;; 秒数が少なければ項目を更新する。項目の数が +ranking-max-length+ を
;; 超えると、超えた分は削除される。
(defun ranking-update (name total-seconds ranking)
  (let ((ranking1
         (stable-sort
          (if (and (assoc name ranking :test #'string-equal)
                   (< total-seconds (cadr (assoc name ranking :test #'string-equal))))
              (mapcar (lambda (entry)
                        (if (string-equal (car entry) name)
                            (list name total-seconds)
                          entry))
                      ranking)
            ;; 同じタイムは後ろに追加する。早い者勝ち。
            (append ranking (list (list name total-seconds))))
          #'< :key #'cadr)))
    ;; 最大で +ranking-max-length+ の項目を返す。
    (loop for i from 1 to +ranking-max-length+
          for entry in ranking1
          collect entry)))

;; ランキングの内容を表示する。name を指定すると該当の項目の左に矢印が
;; 表示される。
(defun ranking-show (ranking &optional name)
  (loop for place from 1 to 10
        for entry in ranking
        do
        (destructuring-bind (entry-name total-seconds) entry
          (destructuring-bind (h m s) (total-seconds-to-hms total-seconds)
            (let ((arrow (if (string-equal entry-name name) "=>" "  ")))
              (format t "~a ~a位 ~2,'0d:~2,'0d:~2,'0d ~a~%"
                          arrow place h m s entry-name))))))

;; ランキングを更新する。ランキングファイルからデータを読み込み、1引数
;; の関数 fun にランキングデータを渡す。fun の返り値をランキングファイ
;; ルに保存する。
;;
;; TODO: 別のプロセスがランキングを同時に変更しないようにロックすべき。
(defun ranking-transaction (fun)
  (flet ((read-ranking ()
                       (with-open-file (file +ranking-file-name+
                                             :external-format :utf8
                                             :if-does-not-exist nil)
                                       (if file
                                           (let ((buf (make-string (file-length file))))
                                             (read-sequence buf file)
                                             (read-from-string buf))
                                         ;; ランキングファイルが存在しなかった場合は空のデータを返す。
                                         '())))
         (write-ranking (ranking)
                        (with-open-file (file +ranking-file-name+
                                              :direction :output
                                              :if-exists :supersede
                                              :if-does-not-exist :create)
                                        (format file "~S" ranking))))
    (let ((ranking (read-ranking)))
        (write-ranking (funcall fun ranking)))))


;; クリア記録 total-seconds をランキングファイルへ登録時のダイアログ。
(defun ranking-dialog (total-seconds)
  (format t "~%ランキングに登録します：~%")
  ;;(format t "名前を入力してください:~%")
  (let ((name *ai-name*))
    (ranking-transaction
     (lambda (ranking)
       (let ((ranking1 (ranking-update name total-seconds ranking)))
	 (if (equal ranking1 ranking)
	     (progn
	       (format t "ランキングに入りませんでした。~%")
	       (ranking-show ranking)
	       ranking)
             (progn
               (format t "見事ランクイン！~%")
               (ranking-show ranking1 name)
               ranking1)))))))
