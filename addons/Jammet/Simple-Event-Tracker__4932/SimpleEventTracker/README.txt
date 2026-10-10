Simple Event Tracker
====================
Shows the currently running ESO event and tracks your account's daily Trade Bars.
Credits: Jammet / Claude AI assisted. Inspired by Event Tracker by Kelinmiriel.
AI disclosure: this addon's code was written with the help of Claude (Anthropic) and tested by the author.

Commands (both accept the same options)
  /sevti            Event info: name, description, end date, time left, today's trade bars
  /sevt             Trade bars: today, last 7 days, event total, all-time total
  /sevt history 14  Longer history (max 30 days)
  /sevt done [n]    Mark today's trade bars as collected (optionally add n bars)
  /sevt undo        Clear today's record
  /sevt ui          Show/hide the on-screen label (it only appears while an event runs)
  /sevt quiet       Turn the login announcement on/off
  /sevt help        List commands
Example: "/sevti done" works the same as "/sevt done".

On-screen label (drag to move): event name, time left, trade bar progress.
A key binding to show/hide it is under Controls > Add-Ons > Simple Event Tracker.

Notes
- Trade bars are counted when a Trade Bar Satchel is looted/opened. Bars from other sources
  (e.g. Twitch drops arriving as a satchel) count too; use /sevt undo to correct.
- Days you were not logged in show as "-" in the history.
