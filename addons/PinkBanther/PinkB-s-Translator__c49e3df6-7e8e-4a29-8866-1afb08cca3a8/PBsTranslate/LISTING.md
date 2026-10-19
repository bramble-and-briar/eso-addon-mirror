# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown —
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's Translate` there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's Translate

## Overview (JP)

英語のチャットの下に日本語訳を表示します。翻訳はすべてアドオン内で行い、インターネットには
接続しません。日常英語、チャットの略語、ネットゲームのスラング、ESO用語、シロディールの
PvP用語を収録した約9,000項目の辞書と、語順を日本語に並べ替える文法規則で訳します。
/en で日本語を英語にして入力欄に入れることもできます。

## Overview (EN)

Shows a Japanese translation under English chat messages. Everything runs inside the add-on
with no internet connection: a built-in dictionary of about 9,000 entries (everyday English,
chat shorthand, online-game slang, ESO terms and Cyrodiil PvP calls) and a small grammar that
reorders English into Japanese. /en also turns Japanese into English in the chat entry box.

---

## Description (JP)

アドオンは外部のサーバーに接続できないため、翻訳サービスは使えません。PB's Translate は
辞書と文法規則をアドオンの中に持ち、チャットをその場で翻訳します。

■ チャットの翻訳

・英語の発言の下に、日本語訳を1行表示します（[訳] の目印付き）。
・自分の発言、他のプレイヤーの発言、ゾーンチャットを、それぞれオン／オフできます。
・訳文のみ表示モード：発言者とチャンネルはそのまま、本文を訳文に置き換えます。
　翻訳できなかった発言は原文のまま表示します。
・訳文の文字色を変更できます。
・/jp <英文> で、入力した英文の訳を自分にだけ表示します。

■ 辞書（約9,000項目）

・日常会話と高校レベルの英単語・熟語
・チャットの略語と崩した綴り（ty, omw, idk, u, ur, shud など）
・ネットゲームのスラング（gg, carry, aggro, nerf, afk など）
・ESOのゲーム用語
・シロディールのPvP用語
　砦・資源・街の名前、inc, ua, lit, fd, rss などのコール。
　シロディールと帝都にいる間は、PvPの意味を優先して訳します。
・設定画面（英語・日本語・品詞を入力して登録）か、/pbtr add english = 日本語 で、
　自分で単語や言い回しを追加できます。
　追加した単語は内蔵の辞書より優先されます。

■ 文法

英語の語順を日本語の語順に並べ替え、次のような文型に対応します。

・時制、否定、疑問、命令、依頼、勧誘（let's）
・can / must / should / need / want / try などの助動詞・表現
・進行形、受け身、完了形（経験）
・関係代名詞と分詞による後置修飾（the guy who… / the keep attacked by…）
・比較と最上級、to不定詞、when / if / because などの接続詞

■ 日本語から英語へ（/en）

・/en <日本語> で英訳し、その英文を入れた状態でチャットの入力欄を開きます。
・送信は自分で行います（アドオンからはチャットを送信できません）。
・翻訳できなかったときは、入力欄に「翻訳不可」と入ります。
・対応しているのは、よく使う短い定型文と単語が中心です。

■ 注意

・辞書と規則による直訳です。自然な翻訳ではなく、意味をつかむための目安としてお使いください。
・辞書にない単語は英語のまま残ります。
・他のプレイヤーに訳文は見えません。訳は自分の画面にだけ表示されます。

■ 設定

設定 → アドオン設定 → PB's Translate
（LibHarvensAddonSettings があれば表示されます。無くてもアドオンは動作し、
　チャットコマンドですべて操作できます）

チャットコマンド
　/jp <英文>                       自分だけに訳を表示
　/en <日本語>                     英訳を入力欄に入れる
　/pbtr                            状態を表示
　/pbtr on | off                   翻訳のオン／オフ
　/pbtr own on | off               自分の発言
　/pbtr others on | off            他のプレイヤーの発言
　/pbtr zone on | off              ゾーンチャットを含める
　/pbtr only on | off              訳文のみ表示
　/pbtr color <RRGGBB | default>   訳文の文字色
　/pbtr known <0-100>              翻訳に必要な既知語の割合
　/pbtr add english = 日本語       単語や言い回しを追加
　/pbtr remove english             追加した単語を削除
　/pbtr list                       追加した単語の一覧

## Description (EN)

Add-ons cannot reach an outside server, so no translation service is available to them.
PB's Translate carries its own dictionary and grammar rules and translates chat on the spot.

■ Chat translation

- A one-line Japanese translation appears under each English message, marked [訳].
- Your own messages, other players' messages and zone chat each have their own switch.
- Translation-only mode keeps the speaker and the channel and replaces the message text with the
  translation. A message that could not be translated is shown as written.
- The colour of the translation can be changed.
- /jp <text> translates a line and shows it to you alone.

■ Dictionary (about 9,000 entries)

- Everyday and high-school-level English words and phrases
- Chat shorthand and casual spellings (ty, omw, idk, u, ur, shud and so on)
- Online-game slang (gg, carry, aggro, nerf, afk and so on)
- ESO game terms
- Cyrodiil PvP terms: keeps, resources and towns, and calls such as inc, ua, lit, fd and rss.
  In Cyrodiil and the Imperial City the PvP meaning takes priority.
- Add your own words and phrases on the settings panel (English, Japanese and a part of speech)
  or with /pbtr add english = 日本語. They take priority over the
  built-in dictionary.

■ Grammar

English word order is rearranged into Japanese order, covering:

- Tense, negation, questions, commands, requests and let's
- can, must, should, need, want, try and similar
- Progressive, passive and perfect (experience)
- Relative clauses and participles after a noun (the guy who… / the keep attacked by…)
- Comparatives and superlatives, to-infinitives, and when / if / because clauses

■ Japanese to English (/en)

- /en <Japanese> translates the line into English and opens the chat entry box with it filled in.
- You send it yourself; add-ons cannot send chat.
- When the line cannot be translated, the box reads 翻訳不可 ("cannot translate").
- It handles common short phrases and single words best.

■ Notes

- The result is a rough literal rendering from a dictionary and rules, not a natural translation.
  Use it to get the gist.
- Words that are not in the dictionary stay in English.
- Nobody else sees the translations. They appear on your screen only.

■ Settings

Settings → Add-On Settings → PB's Translate
(shown if LibHarvensAddonSettings is installed; without it the add-on still works and the chat
commands do everything)

Chat commands:
  /jp <text>                       translate a line for you alone
  /en <Japanese>                   put the English translation in the chat entry box
  /pbtr                            show the state
  /pbtr on | off                   translation on or off
  /pbtr own on | off               your own messages
  /pbtr others on | off            other players' messages
  /pbtr zone on | off              include zone chat
  /pbtr only on | off              translation-only mode
  /pbtr color <RRGGBB | default>   translation colour
  /pbtr known <0-100>              share of known words needed to translate
  /pbtr add english = 日本語       add a word or phrase
  /pbtr remove english             remove an added word
  /pbtr list                       list added words

---

## Dependencies

LibHarvensAddonSettings (optional — the settings panel only; the add-on loads and translates
without it)

## Version

1.0.2

---

This Add-On is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls and related logos are registered trademarks or trademarks of
ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
