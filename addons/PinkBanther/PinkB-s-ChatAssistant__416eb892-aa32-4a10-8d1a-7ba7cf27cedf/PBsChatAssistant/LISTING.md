# Store listing copy — PB's ChatAssistant 1.30.1

Text for the ZOS Console AddOn Uploader. Plain text, no markup, so it survives whatever the
uploader does to it.

---

## Overview

PB's ChatAssistant makes console chat easier to open, organize and use with a USB keyboard. It
raises the console text input screen for Japanese input, creates one chat tab for each guild, and
lets you switch tabs from the HUD with L2 + D-pad Right. The selected tab and outgoing channel
stay synchronized, while a customizable HUD label shows where your next message will go. An
optional filters hide Guild Finder recruitment adverts carrying guild links and NPC speech.

---

## Description

On console, a USB keyboard can type into chat but cannot normally open the full chat workflow by
itself. Japanese input also depends on the console's own text input screen for kana-to-kanji
conversion. PB's ChatAssistant raises that screen when chat opens and can optionally arm the Enter
key to start chatting without reaching for the controller.

It also organizes guild conversations into real ESO chat tabs. The add-on creates exactly one tab
for each guild you currently belong to, routes that guild's normal and officer chat into it, and
removes stale or duplicate tabs when guild membership changes.

WHAT IT DOES

- Raises the console text input screen when chat is opened from the controller.
- Optionally lets an armed Enter key open chat from a USB keyboard.
- Creates a normal chat tab plus one tab for each joined guild.
- Keeps guild and officer messages together in their guild's tab.
- Lets you decide, separately for each named guild, whether its messages also appear in the normal
  chat tab.
- Optionally hides guild-link recruitment adverts before they enter the chat log.
- Optionally removes NPC speech from the chat log without affecting subtitles.
- Switches to the next tab with L2 + D-pad Right while on the HUD.
- Keeps the selected tab and outgoing channel synchronized in both directions.
- Restores a non-guild destination when the normal chat tab is selected.
- Selects the matching tab when the configured login channel is applied.
- Shows the active tab name on the HUD: white for normal chat and the game's guild-chat color for
  a guild tab. The label can be disabled and is hidden in menus.
- Lets you configure the active-tab label's position, text size and draw layer.

ABOUT TAB SWITCHING

On the HUD, hold L2 and press D-pad Right to move through the available tabs. L2 itself is read
without being rebound. D-pad Right's normal quest-cycling action is blocked only while the chord
is active. The shortcut is disabled during combat, in menus, while text entry is open and while
the console keyboard is on screen.

The number of guild tabs follows your actual guild membership. Joining, leaving or renaming a
guild is reconciled automatically. Turning the feature off removes only the tabs created by this
add-on and returns guild chat to the normal tab.

ABOUT GUILD RECRUITMENT

Guild Finder's Link in Chat action inserts a real guild link into an advert. The optional filter
matches that link markup rather than guessing words, so it works in every language. Plain-text
adverts without a guild link and ordinary chat remain visible. Guild and officer channels and
your own messages are always exempt. Whispers are exempt by default and have a separate opt-in.

ABOUT NPC SPEECH

The NPC option removes the game's four dedicated monster speech channels -- speech, yells,
whispers and emotes -- from the chat log. Player messages are unaffected. Subtitles use a
separate UI and continue to appear normally.

ABOUT ENTER INPUT

Listening continuously for Enter can temporarily hold keyboard focus and pause controller buttons,
so Enter capture is deliberately opt-in:

  /pbchat enter   Arm Enter. Buttons pause until chat opens or the arm expires.
  /pbchat safe    Stand down immediately and return normal controller input.

You can leave Enter capture off and continue opening chat from the controller. The automatic
console text-input-screen assistance still works independently.

SETTINGS

Settings -> Add-Ons -> PB's ChatAssistant includes:

- Enable or disable L2 + D-pad Right tab switching.
- Enable or disable per-guild chat tabs.
- Choose whether each guild's messages also appear in normal chat. Actual guild names are shown.
- Hide guild-link recruitment adverts, with a separate option for whispers.
- Hide NPC speech from the chat log while keeping subtitles visible.
- Show or hide the active-tab HUD label, and configure its position, text size and draw layer.
- Choose the outgoing channel and matching active tab used at login.
- Adjust the delay before opening the console text input screen.

NOTES

- Built for the console UI. On PC, bind a key to Controls -> PB's ChatAssistant -> Open Chat.
- Requires LibHarvensAddonSettings for the settings panel.
- The login channel and tab are applied once after add-on load, after guild data becomes available.
- /pbchat reports the running version and diagnostic state.

---

This Add-On is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls and related logos are registered trademarks or trademarks of
ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
