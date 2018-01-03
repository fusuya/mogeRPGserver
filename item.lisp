
;; ((名前 攻撃力　HP 素早さ) . ドロップ確率)　
;;ドロップ確率付き
(defparameter *buki-d*
  '((("もげぞーの剣" 1 0 0) . 100) (("ナイフ" 1 0 0) . 97) (("木の枝" 1 0 0) . 94)
    (("木刀" 2 0 0) . 91) (("ダガー" 2 0 0) . 88) (("メイス" 2 0 0) . 85)
    (("鎌" 2 0 0) . 82) (("ショートソード" 1 0 1) . 79) (("スピア" 2 0 0) . 76)
    (("ヌンチャク" 2 0 1) . 73) (("ブロードソード" 3 0 0) . 70) (("シミター" 3 0 0) . 67)
    (("レイピア" 3 0 0) . 64) (("鉄の剣" 3 0 0) . 61) (("ジャベリン" 3 0 0) . 58)
    (("ミスリルナイフ" 4 0 0) . 55) (("サーベル" 3 0 1) . 52) (("銅の剣" 4 0 0) . 49)
    (("バトルアクス" 4 0 0) . 46) (("銀の剣" 5 0 0) . 43) (("金の剣" 6 0 0) . 40)
    (("フォールチュン" 6 0 0) . 37) (("チャクラム" 6 0 0) . 32) (("ウェアバスター" 6 0 0) . 31)
    (("ちからのつえ" 6 0 0) . 30) (("ファルシオン" 7 0 0) . 29) (("グレートアクス" 7 0 0) . 28)
    (("ツーハンドソード" 7 0 0) . 27) (("猫の爪" 8 0 0) . 26) (("グレートソード" 8 0 0) . 10)
    (("ククリ" 7 0 2) . 10) (("バスタードソード" 9 0 0) . 9) (("クレイモア" 10 0 0) . 9)
    (("モーニングスター" 10 2 0) . 8) (("バルディッシュ" 11 0 0) . 8) (("パルチザン" 12 0 0) . 8)
    (("マインゴーシュ" 8 0 5) . 7) (("シャムシール" 11 0 3) . 7) (("ウォーハンマー" 11 5 0) . 6)
    (("ルーンブレード" 13 5 0) . 6) (("さんごのつるぎ" 14 0 4) . 5) (("ディフェンダー" 15 7 0) . 5)
    (("ブリューナク" 16 5 0) . 4) (("ソードブレイカー" 17 5 1) . 4) (("レーヴァテイン" 18 9 0) . 3)
    (("オートクレール" 20 8 0) . 3) (("正宗" 21 0 10) . 2) (("ゲイボルグ" 22 5 5) . 2)
    (("エクスカリバー" 25 10 10) . 1) (("ラグナロク" 40 0 15) . 1) 
    (("あれくまブレード" 30 20 10) . 1)))

(defparameter *event-buki*
  '(("もげぞうの剣" 30 20 20)
    ("ハツネツの剣" 12 12 12)
    ("メタルヨテイチの剣" 20 0 30)))


(defparameter *test-item*
 '(("もげぞうの剣" 30 20 20)
    ("ハツネツの剣" 12 12 12)
   ("メタルヨテイチの剣" 20 0 30)
   ("もげぞうの剣" 30 20 20)
    ("ハツネツの剣" 12 12 12)
   ("メタルヨテイチの剣" 20 0 30)
   ("もげぞうの剣" 30 20 20)
    ("ハツネツの剣" 12 12 12)
   ("メタルヨテイチの剣" 20 0 30)
   ("もげぞうの剣" 30 20 20)
    ("ハツネツの剣" 12 12 12)
   ("メタルヨテイチの剣" 20 0 30)
   ("もげぞうの剣" 30 20 20)
    ("ハツネツの剣" 12 12 12)
   ("メタルヨテイチの剣" 20 0 30)
   ("もげぞうの剣" 30 20 20)
    ("ハツネツの剣" 12 12 12)
    ("メタルヨテイチの剣" 20 0 30)))
