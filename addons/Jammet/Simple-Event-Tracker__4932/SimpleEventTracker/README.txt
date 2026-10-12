Simple Event Tracker
====================
Shows when an event is running, tells you whether today's Trade Bars are collected, and keeps a short history.
Credits: Jammet / Claude AI assisted. Inspired by Event Tracker by Kelinmiriel.
AI disclosure: this addon's code was written with the help of Claude (Anthropic) and tested by the author.

Getting started
1. Install and log in. Nothing else to set up.
2. Play as usual. Trade Bars are counted when you loot or open a Trade Bar Satchel.
3. The first time you collect bars, the addon decides an event is running. It shows a small alert at the top of
   the screen, a chat message, and a widget with a "Start Event Tracking" button.
4. Click the button (or type /sevt event). A small window opens with boxes for the event's name and the time
   left in days, hours and minutes. It is pre-filled with a guess from an active Golden Pursuit when there is
   one; check it, Golden Pursuits do not always match the event. The time is optional. Press Save.
5. That's it. The widget now shows the event name, time left and today's Trade Bars, and each login you get an
   announcement with the days left.
The game gives addons no event information, so the addon cannot read names or dates itself; that is why it asks.
Without your details it still works and just calls the event "Event". Without an end date, the event counts as
over after a day without Trade Bars.

The button needs a mouse cursor: click it while the cursor is active (the game's "UI mode" key binding under
Controls, or whenever a menu is open). /sevt event opens the same window and switches the cursor on for you, as does the widget's right-click menu.

Right-click the widget (while the cursor is active) for a menu: set up the event, clear it, show the trade bar
history, hide the widget, or Cancel. The addon never opens a window or activates the cursor by itself; it only
offers, and you pick it up through the chat command, the widget button or this menu.

Changing your mind
  /sevt event clear   Disregard the current event (widget disappears until a new event begins)
  /sevt event         Enter or change the name and time left (opens the window)
  /sevt event Jubilee 5d 4h   The same in one line: the name, then the time left (d, h, m)
  /sevt pause         Stop looking for events altogether; type it again to resume

Looking things up
  /sevti              The event: name, end date, time left, today's Trade Bars
  /sevt               Trade Bars: today, last 7 days, event total, all-time total
  /sevt history 14    Longer history (up to 30 days)

Fixing a day
  /sevt done 20       Mark today as collected (the number of bars is optional)
  /sevt undo          Clear today's record

Options
  /sevt ui            Show/hide the widget (a key binding is under Controls > Add-Ons)
  /sevtsize 1-5       Widget text size: 1 = largest, 5 = smallest (default 4)
  /sevt help          Show this list in chat
/sevti and /sevt take the same options, so "/sevti done" works as well.

Notes
- Bars from other sources that arrive as a satchel (e.g. Twitch drops) count too; use /sevt undo to correct.
- Days you were not logged in show as "-" in the history.
- Update "## APIVersion" in SimpleEventTracker.txt after each major game patch.
