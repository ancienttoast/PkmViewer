import
  gba/rom

# From:
#   http://bulbapedia.bulbagarden.net/wiki/Character_encoding_in_Generation_III
# 
# Control Characters 
#   0xFA and 0xFB both mark a prompt for the player to press a button to continue the
#          dialogue. However, they will print the new line of dialogue differently: 0xFA
#          will scroll the previous dialogue up one line before printing the next line,
#          while 0xFB will clear the dialogue box entirely.
#   0xFC is an escape character that leads to several different functions (see below).
#   0xFD is an escape character for variables, such as the player's name or a Pokémon's
#          name (see below).
#   0xFE is a line break.
#   0xFF is a terminator, marking the ends of strings.
# 
# 0xFC functions
#   When 0xFC is followed by...
#   0x01 it will change the color of the text, depending on the byte following. The
#          available colors are listed below.
#   0x02 the text will be highlighted, depending on the byte following. The available
#          colors are listed below.
#   0x03 the text's shadow will have its color changed, depending on the byte following.
#          The available colors are listed below.
#   0x04 the text will be colored and highlighted. The byte immediately following
#          determines the text's color, while a second byte afterward will determine the
#          highlight color. The available colors are listed below.
#   0x06 the text will change size, depending on the byte following. 0x00 will make the
#          font smaller, while anything else will make the font the default size.
#   0x08 and another byte, it produces a pause in the text. The byte after 0x08 determines
#          the length of the pause.
#   0x09 the game will pause text display, and resume upon pressing a button.
#   0x0C it will escape the byte that follows 0x0C if it is a control character and print
#          a new character. If the second byte after 0xFC is not a control character byte,
#          that byte prints normally.
#     When the third byte is 0xFA, "➡" is produced.
#     When the third byte is 0xFB, "+" is produced (though in the Japanese games, within
#       the Options screen, it produces "=").
#     The other control characters do not produce any characters. In the English games,
#       nothing is printed, while in the Japanese games, miscellaneous data appears to be
#       printed.
#   0x0D the text will be shifted by a certain amount of pixels, depending on the byte
#          following this one. The effect wears off upon entering a new line.
#   0x10 music will begin to play. Music is specified by the two bytes following, in
#          little endian format.
#   0x15 text will be rendered slightly larger and more spread out.
#   0x16 text will be rendered at the default size and spread.
#   0x17 music will be paused.
#   0x18 music will resume playing.


const
  englishCharSet = [
    " ", "À", "Á", "Â", "Ç", "È", "É", "Ê", "Ë", "Ì", "こ", "Î", "Ï", "Ò", "Ó", "Ô", 
    "Œ", "Ù", "Ú", "Û", "Ñ", "ß", "à", "á", "ね", "ç", "è", "é", "ê", "ë", "ì", "ま", 
    "î", "ï", "ò", "ó", "ô", "œ", "ù", "ú", "û", "ñ", "º", "ª", "[c0x2c]", "&", "+", "あ", 
    "ぃ", "ぅ", "ぇ", "ぉ", "Lv", "=", "ょ", "が", "ぎ", "ぐ", "げ", "ご", "ざ", "じ", "ず", "ぜ", 
    "ぞ", "だ", "ぢ", "づ", "で", "ど", "ば", "び", "ぶ", "べ", "ぼ", "ぱ", "ぴ", "ぷ", "ぺ", "ぽ", 
    "っ", "¿", "¡", "PK", "MN", "PO", "Ké", "[c0x57]", "[c0x58]", "[c0x59]", "Í", "%", "(", ")", "セ", "ソ", 
    "タ", "チ", "ツ", "テ", "ト", "ナ", "ニ", "ヌ", "â", "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ", "í", 
    "ミ", "ム", "メ", "モ", "ヤ", "ユ", "ヨ", "ラ", "リ", "⬆", "⬇", "⬅", "➡", "ヲ", "ン", "ァ", 
    "ィ", "ゥ", "ェ", "ォ", "ャ", "ュ", "ョ", "ガ", "ギ", "グ", "ゲ", "ゴ", "ザ", "ジ", "ズ", "ゼ", 
    "ゾ", "ダ", "ヂ", "ヅ", "デ", "ド", "バ", "ビ", "ブ", "ベ", "ボ", "パ", "ピ", "プ", "ペ", "ポ", 
    "ッ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "!", "?", ".", "-", "・", 
    "…", "“", "”", "‘", "’", "♂", "♀", "[c0xb7]", ",", "×", "/", "A", "B", "C", "D", "E", 
    "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", 
    "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", 
    "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "▶", 
    ":", "Ä", "Ö", "Ü", "ä", "ö", "ü", "⬆", "⬇", "⬅", "[c0xfa]", "[c0xfb]", "[c0xfc]", "[c0xfd]", "[c0xfe]", "[c0xff]"
  ]

  japaneseCharSet = [
    " ", "あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ", "さ", "し", "す", "せ", "そ", 
    "た", "ち", "つ", "て", "と", "な", "に", "ぬ", "ね", "の", "は", "ひ", "ふ", "へ", "ほ", "ま", 
    "み", "む", "め", "も", "や", "ゆ", "よ", "ら", "り", "る", "れ", "ろ", "わ", "を", "ん", "ぁ", 
    "ぃ", "ぅ", "ぇ", "ぉ", "ゃ", "ゅ", "ょ", "が", "ぎ", "ぐ", "げ", "ご", "ざ", "じ", "ず", "ぜ", 
    "ぞ", "だ", "ぢ", "づ", "で", "ど", "ば", "び", "ぶ", "べ", "ぼ", "ぱ", "ぴ", "ぷ", "ぺ", "ぽ", 
    "っ", "ア", "イ", "ウ", "エ", "オ", "カ", "キ", "ク", "ケ", "コ", "サ", "シ", "ス", "セ", "ソ", 
    "タ", "チ", "ツ", "テ", "ト", "ナ", "ニ", "ヌ", "ネ", "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ", "マ", 
    "ミ", "ム", "メ", "モ", "ヤ", "ユ", "ヨ", "ラ", "リ", "ル", "レ", "ロ", "ワ", "ヲ", "ン", "ァ", 
    "ィ", "ゥ", "ェ", "ォ", "ャ", "ュ", "ョ", "ガ", "ギ", "グ", "ゲ", "ゴ", "ザ", "ジ", "ズ", "ゼ", 
    "ゾ", "ダ", "ヂ", "ヅ", "デ", "ド", "バ", "ビ", "ブ", "ベ", "ボ", "パ", "ピ", "プ", "ペ", "ポ", 
    "ッ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "！", "？", "。", "ー", "・", 
    "・・", "『", "』", "「", "」", "♂", "♀", "円", ".", "×", "/", "A", "B", "C", "D", "E", 
    "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", 
    "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", 
    "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "▶", 
    ":", "Ä", "Ö", "Ü", "ä", "ö", "ü", "⬆", "⬇", "⬅", "[c0xfa]", "[c0xfb]", "[c0xfc]", "[c0xfd]", "[c0xfe]", "[c0xff]"
  ]



type
  PKMText* = distinct string


proc readPKMText*(s: GBARom, length: int): PKMText =
  s.read(length, string).PKMText

proc readPKMText*(s: GBARom): PKMText =
  const
    textSeparator = 0xFF

  result = "".PKMText
  var
    c = 0'u8
  c = s.read(uint8)
  while c != textSeparator:
    result.string &= c.char
    c = s.read(uint8)


proc toAscii*(s: PKMText): string =
  result = ""
  for c in s.string:
    result &= englishCharSet[c.int]
