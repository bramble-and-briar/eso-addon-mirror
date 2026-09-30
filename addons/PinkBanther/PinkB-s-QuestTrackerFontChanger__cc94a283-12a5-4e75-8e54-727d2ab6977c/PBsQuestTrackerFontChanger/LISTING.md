# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown —
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's QuestTrackerFontChanger` there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's QuestTrackerFontChanger

## Overview (JP)

画面右上に並ぶトラッカー（クエストトラッカー／黄金の追跡／ハウス情報）の文字サイズを変更
します。小さくて読めない、大きすぎて視界を塞ぐ、どちらも設定パネルのスライダーで調整でき
ます。3つは別々に設定できます。トラッカーの列の位置と、クエストトラッカーの表示倍率も
変更できます（コンソールには標準のHUD編集が無いため、その代わりになります）。

## Overview (EN)

Changes the text size of the trackers stacked down the top right: the quest tracker, the
Golden Pursuits panel, and the house information shown while you are in a house. Too small to
read, or big enough to block your view — either way it is a slider in the settings panel. The
three are configured separately. The tracker column can be moved and the quest tracker scaled
too — on console, where the game's own Edit HUD screen does not exist.

---

## Description (JP)

HUD右上に縦に並ぶトラッカーのフォントを調整するアドオンです。設定画面は3つの欄に分かれて
おり、画面に出る順番（クエストトラッカー → 黄金の追跡 → ハウス情報）で並んでいます。

■ クエストトラッカー

・文字サイズの変更（10〜72）
　クエスト名／ステップ説明／目標行 の3種類を個別に設定できます。
　ゲーム側でこの3つには別々のサイズが割り当てられているため（コンソール表示では
　目標行のほうがクエスト名より大きい）、スライダーも分けてあります。
　すべて同じ大きさにしたい場合は3つとも同じ値にしてください。

■ 黄金の追跡

クエストトラッカーとハウス情報の間に出るパネルです。追跡中の「黄金の追跡」の課題と、その
進行状況のバーが表示されます。同じパネルが「タムリエルの書」やピン留めした実績にも使われる
ため、この欄の設定はそれらすべてに適用されます。

・文字サイズの変更（10〜72）
　見出し／課題名／進行状況（バーの中の数字）の3種類。
　進行状況のバー自体の大きさは変わらないため、大きくしすぎるとバーからはみ出します。

■ ハウス情報（ホームツアー）

家の中にいる間、クエストトラッカーの下に出るパネルです。自分の家でも、ホームツアーで
訪れた他人の家でも表示されます。

・文字サイズの変更（10〜72）
　家の名前／詳細行（愛称と所有者・人数・タグ）の2種類。
　ゲーム側が詳細の3行を同じフォントで描画しているため、スライダーは1本にまとめてあります。

■ 位置と大きさ

・トラッカーの列の位置（横・縦、ゲーム標準位置からのずらし量）
　0でゲーム標準のままです。ゲームはクエスト・黄金の追跡・ハウス情報などすべての
　トラッカーを1つの列にまとめているため、全部が一緒に移動し、並び順は保たれます。
　ゲーム本体の「HUD編集」はキーボード操作専用でコンソールには無いため、その代わりに
　なります。PCで「HUD編集」を使って位置を決めている場合は、そちらが優先されます。
・クエストトラッカーの表示倍率（50〜200%）
　クエストトラッカー全体を、文字・アイコンごと比率を保って拡大縮小します。
　フォント構築が発生しないため、コンソールでもコストがかかりません。
・ゲーム本体の設定は一切書き換えません。アドオンを外せば元通りです。

■ すべてに共通

・書体の変更
　ゲームが持っている書体から5種類。欄ごとに別々に選べます。
・縁取りの変更
　影・縁取りなど、背景から文字を浮き立たせる方法。こちらも欄ごとです。

■ 特徴

・行間も一緒に詰まります。
　行と行の間隔はフォントとは別の数値で管理されているため、文字を小さくしても
　そのままだと行間だけが空いたままになります。このアドオンは各行の間隔を、
　その下に来る行の文字サイズと同じ比率で自動的に調整します。設定項目はありません
　（ゲーム標準のサイズなら比率は1になり、何も変更しません）。
・各スライダーの初期値は「ゲームが実際に描画しているサイズ」です。
　フォント定義の数値をそのまま使うのではなく、実際のラベルから測っています
　（ゲーム内部のサイズ指定は解像度に応じて拡縮されるため、定義上の数値をそのまま
　書き戻すと意図しないサイズ変更になります）。
・設定がゲーム標準と同じ間は、アドオンは一切フォントを書き換えません。
　入れただけの状態は、入れていない状態と完全に同じです。
・書体を変更してもUIの再読み込みは発生しません。
・設定はセッションを越えて残りません。アドオンを外せば元通りです。

■ 注意

・縁取り系を選ぶとクライアントが縁取り用の字形を生成します。日本語フォントでは
　これに約100MBかかり、コンソールのアドオン共有メモリと同規模です。動作が不安定に
　なる場合は「デフォルト」に戻してください。
・各トラッカーを表示するかどうかはゲーム本体の設定です
　（設定 > インターフェース）。
・タイマー付きクエストのカウントダウン表示は対象外です。

■ 設定

設定 → アドオン設定 → PB's QuestTrackerFontChanger（LibHarvensAddonSettings が必要です）

チャットコマンドでも操作できます。
　/pbquest                        コマンド一覧
　/pbquest status                 現在の設定と、実際に画面に出ているフォント
　/pbquest quest <数値>           クエストトラッカーの3種類すべて
　/pbquest quest <部分> <数値>    個別に設定（name / step / goal）
　/pbquest pursuit <数値>         黄金の追跡の3種類すべて
　/pbquest pursuit <部分> <数値>  個別に設定（name / detail / progress）
　/pbquest house <数値>           ハウス情報の2種類すべて
　/pbquest house <部分> <数値>    個別に設定（name / detail）
　/pbquest size <数値>            すべてのトラッカーのすべて
　/pbquest pos <x> <y>            トラッカーの列の位置をずらす
　/pbquest pos reset              位置を元に戻す
　/pbquest scale <50-200>         クエストトラッカー全体の表示倍率
　/pbquest on | off               すべての適用／解除
　/pbquest <欄> on | off          欄ごと（quest / pursuit / house）
　/pbquest reset                  ゲーム本来のフォントに戻す
　（/pbqt でも同じ）

## Description (EN)

Adjusts the fonts of the HUD trackers stacked down the top right. The settings panel is split
into three sections, in the order they appear on screen.

■ Quest tracker

- Text size (10–72), separately for the quest name, the step description and the objective
  lines. The game gives those three different sizes — in console display the objectives are
  drawn larger than the quest name — so the sliders are separate too. Set all three to the
  same number if you want them uniform.

■ Golden Pursuits

The panel between the quest tracker and the house information, showing the pursuit you are
tracking and a bar for how far along it is. The same panel is reused for Tamriel Tomes and a
pinned achievement, so these settings cover all of them.

- Text size (10–72), separately for the heading, the pursuit name and the numbers inside the
  progress bar. The bar itself keeps its size, so a much larger progress setting spills over.

■ House tracker

The panel under that while you are in a house, yours or someone else's on a home tour.

- Text size (10–72), for the house name and for the details under it: the nickname and owner,
  the visitor count, and the House Tours tags. The game draws all three detail lines with one
  font, so they share one slider.

■ Position and size

- Tracker column position (horizontal and vertical), as a nudge from wherever the game puts
  it. 0 leaves it alone. The game keeps every tracker — quest, Golden Pursuits, house
  information and the rest — in one column, so they all move together and keep their order.
  The game's own Edit HUD screen is keyboard-only and does not exist on console; this is the
  console's way to move them. On PC, a position set in Edit HUD takes priority.
- Quest tracker scale, 50–200%. The whole quest tracker bigger or smaller, text and icons in
  proportion. It makes the client build nothing, so it costs nothing on console.
- None of the game's own settings are written. Removing the add-on is a complete undo.

■ Both

- Typeface: five of the game's own faces, chosen per section.
- Outline: shadow and outline styles, for separating the text from the scenery behind it.
  Also per section.

■ How it behaves

- The line spacing closes up with the text. The gaps between rows are separate numbers from
  the font, so shrinking the text on its own would leave the rows floating apart. Every gap is
  scaled by the same ratio as the row below it, automatically — there is no setting for it, and
  at the game's own size nothing is touched.
- Each slider starts at the size the game itself draws that part at, measured off a real label
  rather than taken from the font definition. The game's own size constants are scaled by
  resolution, so writing the definition's number back would be a size change nobody asked for.
- While every setting in a section still matches the game's own, the add-on never changes a
  font there at all. An untouched install is identical to not having it.
- Changing the typeface does not reload the interface.
- Nothing outlives the session. Removing the add-on is a complete undo.

■ Notes

- Outline styles make the client build outline glyphs, which the game's own source puts at
  about 100 MB for a CJK font — the same size as the whole memory pool console add-ons share.
  If the game becomes unstable, put this back to Default.
- Whether each tracker is shown at all is the game's own setting, under Settings > Interface.
- The countdown on timed quests is a separate piece of UI and is not touched.

■ Settings

Settings → Add-On Settings → PB's QuestTrackerFontChanger (requires LibHarvensAddonSettings)

Chat commands:
  /pbquest                        this list
  /pbquest status                 settings, and the font actually on screen
  /pbquest quest <n>              all three quest tracker sizes
  /pbquest quest <part> <n>       one part: name | step | goal
  /pbquest pursuit <n>            every Golden Pursuits size
  /pbquest pursuit <part> <n>     one part: name | detail | progress
  /pbquest house <n>              both house tracker sizes
  /pbquest house <part> <n>       one part: name | detail
  /pbquest size <n>               every size in every tracker
  /pbquest pos <x> <y>            nudge the tracker column from its default position
  /pbquest pos reset              put it back
  /pbquest scale <50-200>         draw the whole quest tracker bigger or smaller
  /pbquest on | off               every section
  /pbquest <section> on | off     one section: quest | pursuit | house
  /pbquest reset                  back to the game's own fonts
  (/pbqt is the same command)

---

## Dependencies

LibHarvensAddonSettings

## Version

1.3.0
