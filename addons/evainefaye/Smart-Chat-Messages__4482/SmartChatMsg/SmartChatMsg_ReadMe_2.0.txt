# SmartChatMsg 2.0 — User Guide

SmartChatMsg prepares reusable messages in ESO's chat box. **Press Enter to send them.** It runs only while you are online with the addon loaded; it cannot send announcements while ESO is closed.

## Install or update

Install the SmartChatMsg addon folder and enable **LibAddonMenu-2.0** and **LibAddonMenuDatePicker**. Keep your existing SavedVariables file when updating. Open the settings with `/scm`, and open the status window with `/scm status`.

## Commands, guilds, and messages

Create a command name, then select that command and a guild under **Create / Edit / Delete Messages**. A command can have different settings and messages for different guilds. Choose **Guild**, **Officer**, **Zone**, or **Group (/g)** as its output channel. Group prepares messages for your current ESO group; the selected guild still identifies the configuration and substitutions, rather than the recipients. Enter a message and click **Add**; add several variations to have the addon choose randomly. Existing messages can be updated or deleted.

The selected **command + guild** is the unit of scheduling and cooldown coordination. Zone messages still belong to that selected combination, but their output and incoming matching use Zone chat.

## Global settings

- **Default guild:** used when you launch an ordinary command without a guild number.
- **Scheduling timezone:** Eastern (ET), Central (CT), Mountain (MT), or Pacific (PT). Eastern is the default. US daylight-saving rules are applied for the date, independently of your computer's timezone. Mountain follows the DST-observing Mountain rules, rather than Arizona's year-round standard time.
- **Chat revert time:** how long an unchanged prepared message can wait before timing out. Player edits are protected.

The global timezone is a fallback. Each guild can choose its own timezone under **Scheduling → Guild timezone**, with **Use global default** selected initially. This default applies to all schedules for that guild, across commands. For example, one guild can use Eastern while another uses Pacific. Selecting a guild changes the Scheduling heading, picker labels, previews, event substitutions, and status dates to that guild's effective zone.

Changing a guild timezone moves that guild's existing schedules to the **same clock time in the new zone**. For example, 8 PM Eastern becomes 8 PM Pacific. Other guilds are unchanged. Changing the global timezone moves only schedules for guilds using **Use global default**; explicit guild choices stay fixed. Choosing Use global default again moves the guild's schedules back to the current global zone. Unsaved schedule edits are retained when you change the guild choice. Event recurrence, midnight boundaries, event substitutions, faction rotation, and month-final selection use the guild's zone. Literal text such as `8 PM ET` inside a message keeps its explicit timezone meaning; edit that text yourself if needed. Prefer `%eventtime%` for scheduled events.

Dates and times in settings are readable calendar values; stored UTC timestamps are internal. The spring DST hour that does not exist cannot be selected for an anchor. Repeating occurrences that land in that missing hour are skipped. During the repeated autumn hour, scheduling uses the first occurrence by default; legacy explicitly selected second-occurrence values are retained.

## Choose how a combination starts: Run At

| Run At | What happens | How to launch |
| --- | --- | --- |
| **On Demand** | Waits for you to start it; can prepare once or repeat. | Type your custom slash command, such as `/recruit 1`. |
| **Startup** | Enters a queue when the addon initializes, including after a UI reload. It uses the ordinary command's behavior settings. | Starts automatically; its slash command remains available. |
| **Scheduled** | Runs only within the saved schedule's eligible times. | Click **Save and activate**; no slash command is needed. |

A name used exclusively for Scheduled combinations has no custom slash command. Changing a combination to On Demand or Startup restores the command. If another guild uses the same name for an ordinary combination, its command remains available.

### Ordinary On Demand and Startup behavior

- **Repeat Every (mins):** after you send a prepared message, wait this long before preparing another. Leave repeating disabled for a one-time command.
- **Retry Delay (mins):** when a prepared repeated message times out unsent, controls the retry delay. Zero or blank uses the normal repeat interval; an explicit retry cannot exceed that interval.
- **Auto Populate Chat on Zone:** prepares messages on eligible zone arrivals instead of ordinary repeating. Only one Zone automation owner can be active at a time.
- **Cooldown (mins):** prevents another automatic message for the same zone until that zone's cooldown has elapsed. It is separate from Repeat Every.
- **Open Status Panel on Run:** opens the status window when the combination runs.
- **Notify Sound:** plays the chosen sound when a message is prepared; **None** is silent, and **Preview** lets you hear the selection.

For example, Repeat Every 60 and Retry Delay 5 means a confirmed send waits 60 minutes, while an untouched unsent message can be retried after 5 minutes. Zone delivery uses its own per-zone cooldown instead of this repeat loop. Scheduled combinations use the delivery and intervals inside Scheduling.

## Scheduling

Select **Run At → Scheduled**, then open **Scheduling (your guild's timezone name Time)** beneath Enter Message. Use **Guild timezone** near the top to choose Eastern, Central, Mountain, Pacific, or Use global default. This section is disabled for On Demand or Startup combinations. There are three schedule types.

### Run during a window

Use this for a message that stays relevant over a period: volunteer recruitment, an open guild poll, ticket sales, or housing contest entries.

1. Under **Window dates and times**, set the start and end dates and times.
2. Choose the recurrence, or leave it non-repeating for a one-off campaign.
3. Under **Message delivery**, choose Repeat while active or On zone arrival.
4. Select several messages and the message interval.
5. Review the preview, then click **Save and activate**.

No event date or event phases are needed. The start is inclusive and the end is exclusive.

### Remind me at set times

Set the first reminder's date and time and its recurrence. Each occurrence prepares one randomly selected message. There is a two-minute eligibility window; reminders missed while offline are skipped, rather than delivered as a backlog.

### Promote an event

Use this when messages should change as an event or submission deadline approaches.

1. Under **Event and promotion timing**, set the **Event date**, hour, minute, and AM/PM. This original date is also the recurrence and faction-rotation anchor.
2. Set **Start promoting (days before event)**. **0 starts at midnight on event day in the selected timezone.** Positive values start that many calendar days earlier at the event's clock time: 1 for an 8 PM event starts at 8 PM the previous day; 2 starts at 8 PM two days earlier. DST can make the elapsed duration differ from exactly 24/48 hours. The preview shows the actual promotion start.
3. Set **Stop promoting (minutes after event)**. For a contest deadline, use the smallest available end delay and leave the final phase's messages unchecked if you want no post-deadline announcements.
4. Optionally enable **Starting soon** and choose its lead time, such as 120 minutes.
5. Set delivery, recurrence, phase messages, and intervals, then review and save.

The phases use these same names in settings and status:

| Phase | When it applies |
| --- | --- |
| **Before event day** | Promotion starts until midnight on event day. |
| **On event day** | Midnight until the event starts, unless Starting soon takes over earlier. |
| **Starting soon** | The configured final minutes before the event, within the promotion window. |
| **From event start until promotion ends** | Event start until the configured promotion stop. |

Scheduled message views are sorted by their earliest selected phase: Before event day, On event day, Starting soon, From event start until promotion ends, then messages not selected for any enabled phase. A message in several phases appears in its earliest group; a default message enabled for all phases appears in the first group. Within a group, the existing order stays stable. Sorting changes only the view, not the saved message list or random message selection.

The order updates as you check or uncheck messages, including unsaved changes. Phase lists keep the top visible message and your offset within it; the main settings page keeps its scroll offset. The existing sections and message controls are reused. Near the end of a shortened list, scrolling is limited to the remaining content.

Each phase can have several checked messages; one eligible message is chosen randomly each time. A message can be included in several phases. **Message interval override (optional)** overrides the default interval for that phase; leave it blank to inherit the default. For example: every 180 minutes before event day, every 60 minutes on event day, and every 15 minutes starting soon.

### Prepare only once

**Prepare only once before event day**, **on event day**, **during Starting soon**, and **when event starts** apply independently to their respective phases. When checked, that phase gets one announcement per event occurrence. It selects one random eligible message, not one of every checked variation. After a confirmed send, the phase is complete. An unsent message may be retried while the phase remains eligible. A recognized matching announcement from another player also counts as usage. Each recurring event has a fresh allowance.

### Save controls and previews

**Save and activate** validates and enables the schedule. **Save disabled** keeps the configuration without running it. Edits are drafts until saved. Review shows readable times, the promotion window, and upcoming occurrences. **Next event** shows the next future event date without replacing your original anchor.

## Repeat schedule and More repeat options

Recurrence repeats the **whole window, reminder, or event**. It does not control how frequently messages appear within a window.

- **Does not repeat:** one occurrence.
- **Daily:** repeats by calendar day.
- **Weekly:** repeats each week on the anchor weekday, unless you select other weekdays.
- **Every other week:** repeats in two-week blocks anchored by the original date's week.
- **Monthly on date:** the original day number; months without that date are skipped.
- **Monthly on weekday:** the original weekday and its position in the month, such as the third Friday; months without that occurrence are skipped.

**Custom repeat interval (optional)** multiplies the selected recurrence. Blank or 1 uses the normal pattern. Daily + 3 means every three days; Weekly + 2 means every two weeks; Every other week + 2 means every four weeks; Monthly + 2 means every two months.

**Repeat on weekdays (optional)** filters/adds eligible weekdays for Daily, Weekly, and Every other week. With no weekdays selected, Weekly/Every other week use the anchor weekday. With Monday and Thursday selected, Weekly produces events on both days each eligible week, at the anchor's clock time. Every other week uses those days in alternate eligible weeks. Daily still honors its day interval as well as the weekday filter. Dates before the original anchor are not generated. This option does not change monthly patterns.

## Special event patterns

These are optional refinements for **repeating Promote an event** schedules. They work with any supported recurrence; Every other week is not required.

### Faction rotation

Select **Special event pattern → Faction rotation**. Under **Faction rotation**, choose the first faction, optional second/third factions, and **Faction frequency (weeks)**. Choose **Not used** for slots you do not need.

The **Event date under Event and promotion timing** starts the first faction's block. Each selected faction runs for the chosen number of calendar weeks, then the order repeats. The complete cycle is frequency × number of selected factions: three factions at four weeks each gives 12 weeks; two factions at two weeks each gives four weeks. Rotation continues across weeks you are offline.

**Use `%eventfaction%` in a message to show the proper full faction name for that event.** In phase message rows, choose All selected factions for a reusable template or choose one faction for wording specific to it. Phase selections still control when the message runs.

### Last event of month

Select **Special event pattern → Last event of month**. This finds the last actual scheduled event in each calendar month, using your recurrence and scheduling timezone. It is not tied to raffles, a fixed weekday, or the month's last calendar day.

Under each phase, click the **Group: Regular events** button beneath a message to switch it to **Group: Month-final events**. Click again to switch back. Existing/unmarked messages are regular by default. Mark only the special month-final announcements; you do not need to change every message.

The final event uses its month-final pool throughout promotion, including promotion that starts in the previous month. If no messages for the combination are marked month-final, regular messages are used instead. Once a special pool exists, its phase checkboxes are respected; an empty special phase intentionally has no messages. Regular and month-final messages can each have several random variations.

## Message substitutions and countdowns

| Substitution | Meaning |
| --- | --- |
| `%eventtime%` | Current scheduled occurrence's clock time and timezone, such as 08:00 PM PDT. |
| `%eventdate%` | Current occurrence's calendar date. |
| `%eventwhen%` | Today, tomorrow, or weekday plus date, according to the occurrence. |
| `%eventfaction%` | Full faction name for the occurrence's configured rotation. |

Example: `Council orders: bring your sparkle! Our %eventfaction% PvP crew gathers %eventwhen% at %eventtime%.`

Event substitutions require an event schedule for the command/guild. Ordinary messages can also use the existing literal date/time countdown parser; a bare On Demand repeat does not create an event anchor. `%eventwhen%` describes the event's calendar day; it is not itself an hourly countdown. Supported event-time substitutions receive the countdown calculated directly from the occurrence's UTC timestamp. The fixed text and explicit event identity remain important for incoming matching.

## Other players' announcements and cooldowns

The addon monitors incoming messages even when your command is stopped or paused. It ignores your own messages. Guild and Officer announcements must arrive in that same channel for the same guild; Zone announcements must arrive in Zone chat; Group announcements must arrive in Group chat. Group chat has no guild identity, so matching applies only to matching templates configured for Group output. When a recognized template matches, the entire command + guild is recorded as used, and a random 30–90 seconds is added to its cooldown to stagger users.

Matching tolerates supported substitution values, formatting, spacing, and generated countdown annotations such as `(~23h)`. It does not accept arbitrary word changes or typos as a general fuzzy match. Unchecked phase messages are still saved templates available for monitoring; excluding one from your delivery pool does not delete it. A match does not enable a stopped command or unpause a schedule.

## Startup delay, chat protection, and status

On each addon load/UI reload, scheduled activity waits **three minutes**. After you confirm a scheduled send, other command + guild schedules wait **five minutes**. Another scheduled send extends spacing for the other combinations; the sender keeps its own interval, including intervals shorter than five minutes. Ordinary On Demand/Startup commands do not use the scheduled startup delay.

Busy chat input is protected. The addon does not overwrite what you type. Local messages announce addon startup, schedule starts/ends, phase changes, and cooldown skips through `CHAT_SYSTEM:AddMessage`; these notices are only for you.

The status window has collapsible Auto and Repeat Commands sections. Empty sections collapse. Scheduled cards appear only within their current eligible window. Cards show the type, event countdown, current phase and effective delivery frequency, promotion start/end, channel, and last sent time. **Next Send** appears only while Active. The button shows the next action and cycles **Enable → Pause → Disable → Enable**. Paused and Inactive cards retain their configurations.

Ordinary repeating commands appear after you launch them and can be paused/resumed from their cards. Once disabled, launch their slash command to start them again.

## Export, import, and personal messages

Use **Import / Export Settings** for full settings transfer. It includes command names, messages, channels, Run At, Open Status Panel on Run, Notify Sound, ordinary repeat/retry/zone settings, schedules, recurrence, phase assignments/intervals/once choices, Starting soon, faction order/frequency, month-final groups, global timezone, per-guild timezone defaults, and status-panel preferences. Guild defaults are identified by guild name, not the receiver's guild-slot number. Older exports without guild choices use the exported global timezone (or Eastern for older exports without any timezone). Import is a replacement operation; back up first. Saved last-used times and per-zone send history are included; pending chat buffers, session startup holds, shared spacing, and schedule retry/once runtime markers are not transferred.

**Lock** keeps a message personal: locked messages are omitted from exports and preserved through imports when their parent command still exists, even if the imported same-name command has a different ID. Their personal phase/group assignments are retained. If the parent command no longer exists after import, those messages are removed too. A Locked indicator identifies them. Locking affects transfer, not sending or incoming detection.

## Quick test

Create a dedicated test command and one message, choose your guild and output channel, and set Run At to Scheduled. For a simple test, choose Run during a window, starting now and ending 15 minutes later, with a five-minute message interval. Save and activate. Wait for the three-minute startup hold if you just loaded the addon, leave chat input empty, and watch `/scm status`. Press Enter when a message is prepared. A housing zone is convenient for a Zone test; use guild chat when testing guild-channel matching.

`/scm resetcooldowns` clears existing cooldowns for testing, including once-completion deadlines. It preserves schedule dates, paused/disabled states, and the startup delay. Other schedules' spacing is also reset. A future or expired schedule remains future or expired; resetting cooldowns does not move its dates.
