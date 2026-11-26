# Fury's Guild Toolset

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game in my own guilds before it goes up, and I maintain it. Please report any problem in the comments.

*Bank, roster, trader, recruiting, raffles and events. One window, your rules.*

**Video tutorial:** new to the toolset? See how everything works in my video. [Watch it on YouTube](https://www.youtube.com/live/IoDgDIp34fA).

**Built for the leaders and officers who keep a guild running.** It watches your guild banks, rosters, trader and guild store, tells you when something needs your attention, and lets you deal with it in a click or two. It also helps you advertise, recruit, welcome new members, run raffles and fill your guild events from Discord sign-ups (sesh or any sign-up sheet).

**Get your data out of the game.** ESO keeps your guild's records locked inside the game. Here, every tab has an **Export / copy** button: the member list, inactive members, bank alerts, hoppers, the watchlist, the bank and roster history, trader weeks and member sales all come out as comma-separated text you paste straight into Excel, Google Sheets or Discord.

- **Everything starts turned off.** Nothing runs, alerts, logs or mails until you turn it on, so you switch on only what you want. Updating keeps your settings as they were.
- **You stay in control.** Nothing is done to a member without your click, unless you turn on auto-demote or automatic invites yourself. It never kicks or posts in chat on its own: chat text waits in the chat box for your Enter, and mails open for your Send.
- **Easy on the server.** Guild history comes only through **LibHistoire**, the way the ESO addon community asks. No extra history requests, no polling.

**Requires:** **LibHistoire** (AddOn version 1112 or newer) and **LibAddonMenu-2.0** (version 43 or newer). Both are separate downloads: search for them in Minion, or get them from ESOUI.

**Download:** [ESOUI](https://www.esoui.com/downloads/info5063.html) or Minion, or [FurysGuildToolset-1.33.4.zip](https://github.com/AlbertHoffpauir/FurysGuildToolset/raw/main/downloads/FurysGuildToolset-1.33.4.zip) from GitHub. To install by hand, copy the `FurysGuildToolset` folder to `Documents/Elder Scrolls Online/live/AddOns/`.

**Contents:** [Getting started](#getting-started) · [Finding your way around](#finding-your-way-around) · [Bank alerts](#bank-alerts) · [Auto-demote and the Auto tab](#auto-demote-and-the-auto-tab) · [Members and Inactive](#members-and-inactive) · [Kick and blacklist mails](#kick-and-blacklist-mails) · [Bank hoppers and watchlist](#bank-hoppers-and-watchlist) · [History](#history) · [Bank space](#bank-space) · [Trader and Member sales](#trader-and-member-sales) · [Guild Crier](#guild-crier) · [Recruiting](#recruiting) · [Raffle](#raffle) · [Events](#events) · [Questions](#questions)

## Getting started

1. Install **LibHistoire** and **LibAddonMenu-2.0** (see Requires above). The addon won't load without them.
2. Log in and type `/gt`. On a new install the window opens on the **Start here** page (later: the **Start here** button next to the window title, or `/gt start`).
3. Click the guilds you look after (step 1 on the page). Bank, hopper, inactivity and bank space alerts only happen in these.
4. Click the features you want (step 2). Each row says what the feature does; hover it for more, right-click it for its tab and its settings.
5. If a row says "after reload", click **Reload to apply** (step 3).
6. Click **Guild rules** and set the rules for each of your guilds: bank limits, who to ignore, inactivity limits and so on. **Copy rules from** gives a guild the same rules as another in one click.
7. Each feature has its own tab. A tab with nothing to list yet tells you what it is for. Everything on the Start here page is also in the settings (`/gtsettings`), with more detail.

## Finding your way around

### The report window

- `/gt` opens it; `/gt bank`, `/gt members`, `/gt raffle` and so on open a tab directly (see Commands).
- The tabs are grouped by job: the top row is your people and your trader (Members, Inactive, Recruit, Events, Raffle, Trader, Member sales), the bottom row is the bank and the Crier (Bank alerts, Bank space, Bank hoppers, Watchlist, Auto, History, Crier).
- A tab whose feature is turned off has a dimmed name. Open it for what it does and a **Set up** button that takes you to the **Start here** page.
- **Right-click any row** for what you can do with it: whisper, mail, set rank, kick, dismiss and more. The line at the top of each tab reminds you.
- To copy someone's @name, right-click their row > **Copy @name**. The name shows up selected in a small window; press Ctrl+C.
- **Hover** over any button, tab, column header or row for a short tip or the full details.
- The small icons in the title bar are your other Fury addons: left-click one to open that addon, right-click for its settings.
- Click a column header to sort, and again to reverse. Tabs with a search box have a small X to clear it.
- Every tab has an **Export / copy** button: the tab as comma-separated text to paste into Excel, Google Sheets or Discord.
- The gear at the top right opens the settings for the tab you're on (for example the Crier page on the Crier tab, the Guild rules page on Members). Tabs without settings of their own open the main page.

### The settings pages

- Esc > Settings > Add-Ons, or `/gtsettings`. There are six pages, all starting with "Fury's Guild Toolset":
- **Fury's Guild Toolset** (main page): guilds to get alerts from, bank alerts, members, hoppers, history, automatic actions, bank space and trader week totals. It has a button that opens each of the other pages.
- **- Guild rules:** a **Rules for (guild)** section for each ticked guild.
- **- Recruiting**, **- Raffle**, **- Events** and **- Crier:** everything for those features.

### Commands

- `/gt`: open or close the report window.
- `/gt start`: open the Start here page (pick your guilds, turn features on or off).
- `/gt bank`, `hoppers`, `watchlist`, `history`, `space`, `members`, `inactive`, `trader`, `sales`, `auto`, `recruit`, `raffle`, `events`, `crier`: open that tab.
- `/gtsettings` (or `/gt settings`): open the settings.
- `/gt tour`: start or stop the recruiting zone tour.
- `/gt raffle add @name 3 (reason)` and `/gt raffle remove @name 3`: change someone's raffle tickets by hand.
- `/fury`: shows or hides the Fury sidebar, a slim bar of icons, one per Fury addon you have installed, that shows whenever your cursor is out. Left-click an icon to open that addon, right-click for its settings; drag its violet line to move it. It starts turned off and also has a key: Controls > Keybindings > Fury's Addons > Show or hide the Fury sidebar.
- `/fury menu`: the list of your Fury addons, each with an Open and a Settings button, and the sidebar's options: a row or a column, bigger icons, lock in place, hide in combat, stay on screen without the cursor.
- `/crier`: the Guild Crier menu. `/crier next` posts the next message, `/crier reset` restarts the rotation.
- `/gt status`: how much history has loaded per guild, and the biggest withdrawers. `/gt guilds`: which guilds have alerts on.
- `/gt reset`: rebuild the alerts from the logged history with your current settings (what you already did is kept). `/gt reset full`: wipe the log and trader totals and download the look-back period again (settings and watchlist are kept; it asks first, because it reloads the UI).

### Keybinds

- Controls > Keybindings > Fury's Guild Toolset: open or close the report window, open or close the Crier menu, post the next Crier message, put the zone ad in chat, start or stop the zone tour, and travel to the next ready zone.

## Bank alerts

Catch members who take more from the guild bank than your rules allow.

### Turn it on

- On the **Start here** page, click your guilds and then **Bank alerts**, and reload. (The same switches are on the main settings page: **Guilds to get alerts from** and **Guild bank alerts > Enable bank alerts**.)
- On the **Guild rules** page, set each guild's limits with the **Items: warn at**, **demote at** and **kick at** sliders: X stacks per day (0 = never). Demote starts at 50; warn and kick start turned off.
- Add your bankers and restocking officers under **Ignore rank names** or **Ignore @names**. The top 2 ranks are ignored from the start.
- Optional: gold withdrawals, with their own **Gold: warn at**, **demote at** and **kick at** sliders (all start at 0, which means gold is not watched), counting items instead of stacks, or a rolling window of hours instead of midnight to midnight.

### Use it

- You get a chat and on-screen alert as it happens while you're online, and a summary at login.
- The **Bank alerts** tab (`/gt bank`) lists everyone over a limit: how many stacks and items they took, and how many came back. Alerts you haven't looked at yet are marked **NEW**; the tag goes away when you leave the tab or close the window, or with **Mark seen** (right-click) or **Mark all seen**. Seen alerts stay in the list until you deal with them. Hover for the full item list.
- Right-click an alert for **Whisper**, **Mail**, **Warn** (by whisper or mail), **Demote**, **Set rank**, **Add to guild note**, **Kick**, **Kick and blacklist** and **Dismiss**. Anything that changes the guild asks first.
- Warn and Demote open a filled-in message: the date, what they took, and your bank rules (from the Crier's "Guild Bank 101" message unless you write your own). Every text can be changed in the guild's rules.

### Good to know

- A stack put back whole within 72 hours (adjustable) doesn't count. A partly used stack still counts. An alert that drops under every limit once stacks come back (for example after someone restacks the bank) leaves the list by itself.
- Deposits never count, so stocking the bank never triggers anything.
- The first time, the addon looks back 30 days (change it with **First run: look back**, up to 365 days, before a guild is first read). Old withdrawals show up as alerts to review; nothing is done to anyone for them.
- After changing limits, click **Rescan alerts** (main page) or type `/gt reset`.

## Auto-demote and the Auto tab

Optional: let the addon demote someone the moment they reach a guild's demote limit.

### Turn it on

- On the **Guild rules** page, in that guild's rules, turn on **Auto-demote at the demote threshold**. Each guild is separate.
- Optional, in the same place: **Send the demotion mail automatically** and **Note the reason in their guild note**.
- Optional, on the main page under **Automatic actions**: **Alert window for auto-demotes** (a big window that stays until you close it). **Test the alert window** shows you what it looks like.

### Use it

- Each auto-demote is explained in chat: old and new rank, the rule they hit, and each withdrawal.
- The **Auto** tab (`/gt auto`) keeps everything the addon did by itself, with the reason: auto-demotes, demotion mails and hoppers added to the watchlist. It shows whether the server confirmed the new rank and the mail. If a mail failed, right-click to send it.

### Good to know

- Only withdrawals after you turn it on count. It never touches anyone at or above your rank or on your ignore lists.
- At most 5 per session over all guilds (change it under **Guild bank alerts**).
- Kick and blacklist always need your click. The addon never kicks anyone by itself.

## Members and Inactive

See your whole roster, and who has been offline too long.

### Members tab

- `/gt members`: every member's rank, time in guild, time at rank, last online and guild note (hover a row for their last promotion). Join and rank dates come from all the roster history LibHistoire has saved for the guild and from the toolset's own History log (the first time, reading it can take a minute); anyone who joined or got their rank before the oldest history it has shows **before** that date. Filter by guild or rank, hide offline members, search and sort. Offline members are drawn a bit faded, so the ones online now stand out.
- Right-click a member to whisper or mail them, **Set rank**, **Kick** or **Kick and blacklist**. Each change asks first.

### Turn on inactivity alerts

- On the **Guild rules** page, in each guild's rules, turn on **Inactivity alerts**.
- Set the limits: officers 30, members 21, recruits 14 days offline to start with. For each rank, pick which limit applies, or no check.
- Optional, on the main page under **Members and inactivity**: **Alert at login** tells you how many are over the limit.

### Inactive tab

- `/gt inactive`: members over the limit for their rank, how long they have been in the guild, and how many guild slots each guild has open (out of 500).
- Right-click for a **"we miss you" mail**, a blank mail, **Set rank**, **Kick**, **Kick and blacklist** or **Dismiss**. A dismissed member comes back if they go over the limit again after logging in.
- Tip: pick Rank: Recruit and sort by Offline to go through recruits from most to least inactive.

### Good to know

- The game doesn't store when someone got their rank, so rank dates come from roster history. Older changes show as "since before (date)".

## Kick and blacklist mails

Optional: mail people why they were removed.

### Turn it on

- On the **Guild rules** page, in each guild's rules under **Mail when you kick or blacklist**, turn on **Mail members kicked for inactivity** and/or **Mail members you blacklist**, and edit the texts if you like.

### Use it

- **Kick** on the Inactive tab mails them why (days offline and their limit) and that they're welcome back if they return to the game.
- **Kick and blacklist** or **Blacklist** on any tab opens a confirm window with a reason box, filled in for you. The reason becomes their blacklist note and goes in the mail.
- The **Send mail** button in the confirm window skips the mail for one person. Hover it to read the mail. The mail goes out after you click Confirm, with normal postage.
- In the **kick mail** text: `<<1>>` is their @name, `<<2>>` the guild, `<<3>>` the days offline and `<<4>>` their limit.
- In the **blacklist mail** text: `<<1>>` is their @name, `<<2>>` the guild and `<<3>>` the reason.

## Bank hoppers and watchlist

Spot people who join, empty the bank and leave.

### Turn it on

- Turn on **Bank hoppers and watchlist > Enable hopper report** (main settings page).
- On the **Guild rules** page, set how soon a leave counts (48 hours to start with), and optionally **Add hoppers to the watchlist automatically** and **Alert when a watchlisted person joins**.

### Use it

- The **Bank hoppers** tab (`/gt hoppers`) lists people who joined and left within your time limit. Right-click to blacklist, watch, whisper, mail or dismiss them.
- The **Watchlist** (`/gt watchlist`) is shared by all your guilds and alerts you when a known hopper joins any of them.

## History

A searchable log of your guild banks and rosters.

### Turn it on

- Turn on **History log and export > Keep a history log** (main settings page). Events are kept 90 days to start with (up to 20,000).

### Use it

- `/gt history`: bank items, bank gold and roster events (joins, leaves, kicks, promotions, demotions, blacklist changes) for all your guilds.
- Filter by type, time and guild, search by name or item, or see totals per member.
- **Show: Bank items** marks every withdrawal as returned whole, returned partly or not returned, so you can see who took what and what came back.
- The log is saved as one line per event, so even a full log keeps your saved file small. If you update from a version before 1.28.0, your log is moved over at your first login, every event is checked, and the old copy stays as a backup for 7 days (**History log and export > Remove the old log backup** removes it sooner).

## Bank space

Know when a guild bank is getting full.

### Turn it on

- Turn on **Guild bank space > Alert when a guild bank is nearly full** (main settings page). Each guild's alert level (90% to start with) is on the **Guild rules** page.

### Use it

- Open each guild bank once. The game only shows how full a bank is while it's open, so the count updates every time you open it.
- The **Bank space** tab (`/gt space`) shows each bank and how long ago it was counted.

## Trader and Member sales

Weekly trader results, and what each member sold.

### Turn it on

- Turn on **Trader week totals > Keep weekly trader and bank totals** (main settings page). 12 weeks are kept to start with (up to 52).

### Trader tab

- `/gt trader`: for each guild and trader week (from the Tuesday trader change): your trader, sales and tax, what the trader really cost (every bid marked won or refunded), revenue against cost in green or red, and gold in and out.
- **View: traders** compares every trader you held. The top line shows your current trader, the bank gold and when traders change next.

### Member sales tab

- `/gt sales`: what each member sold in the guild store and the tax it earned, for one week or all stored weeks.
- Right-click to whisper, mail (sellers get a filled-in congratulations note) or shout them out in guild chat. **Post top ten** puts the top sellers in the guild chat box.

## Guild Crier

A clickable menu of ready-made guild, zone and whisper messages.

### Use it

- `/crier` (or the Crier tab, or a keybind) opens the menu. Click a message to put it in the chat box, then press Enter.
- `/crier next` (or a keybind) posts the next message in the rotation. The rotation goes through your list in order and nothing is left out or bunched up: in a round every message is posted as often as its weight says, and the turns of a heavier message are spread evenly, never in a row. It remembers its place between reloads, logins and characters, and a reminder message you didn't send comes back at the next reminder.

### Set it up

- On the **Crier** settings page, replace the sample messages and the 19 tips for newer players with your own, add sections, and set each section's channel and rotation weight.
- Optional: a **Rotation reminder** every X minutes. It keeps its timing across logouts and reloads.
- Adding a message or a section doesn't reload the UI, so you can add several in a row. Pick the new message's channel and rotation weight next to the Add box. Each one is in the menu and the rotation right away, and shows on the settings page after you type `/reloadui`.
- Updates never replace your messages. **Import new tips** adds tips from a newer version.

## Recruiting

Advertise in zones, invite, and welcome new members. Every part is off until you turn it on.

### Set it up

- Open the **Recruiting** settings page (or the button under Recruiting in `/gtsettings`).
- Pick the guild you recruit for, write a zone ad for each guild (`{guild}` becomes the guild's name), and turn on the parts you want.

### Zone ads and the zone tour

- **Put ad in chat** (a button on the Recruit tab, or a keybind) puts your ad in zone chat; press Enter. That zone then goes on cooldown (15 minutes to start with, up to 4 hours), and posting there too soon asks first.
- **Start tour:** each time you press Enter on your ad, you travel to the next ready zone, through a guildmate, a friend or a house you own there, and the ad is waiting when you arrive. Nothing moves until you post. If a jump fails, it tries the next person, then the next zone. If you're in combat, it waits until combat clears and then travels.
- The **Recruit** tab (`/gt recruit`) lists every zone as ready or on cooldown. Right-click one to travel there, clear its cooldown or leave it out of the tour.

### Invites and leads

- Right-click a name in chat for **Invite to (guild)**.
- **Whisper leads:** when someone whispers a keyword (inv, invite, join, guild to start with), you get an [Invite] link and a row on the Recruit tab. Nobody is invited without your click, unless you tick **Invite automatically** (off to start with): then the invite goes out right away, with a chat line saying who was invited. One invite per person; whispering again within 10 minutes doesn't send another.
- **Join notices:** who joined, how many slots are left, and a warning when the guild is nearly full or has no trader.

### Welcomes

- Pick a guild under **Welcome settings for**, tick **Welcome new members in this guild**, and write its welcome message and mail. Each guild has its own.
- Someone who joins while you're online gets the welcome in the guild chat box; press Enter. Someone who joined while offline gets a welcome mail that opens for you to send (or goes out by itself, if you turn on **Send the welcome mail automatically**).
- Mails that go out by themselves wait for other addons that use the mailbox (like Writ Crafter taking hireling mails) to finish, and are tried up to 3 times before you are told one failed.

### Status bar

- Optional: a small bar you can drag anywhere, with zones posted (for example 5/23), pending applications and whether whisper leads are listening. Show it during the zone tour or always.

## Raffle

Sell raffle tickets for gold and draw the winners. Works without a guild too, for housing, fashion or other groups.

### Set it up

- Open the **Raffle** settings page (or the button under Raffle in `/gtsettings`) and turn on **Turn on the raffle**; reload when asked.
- Pick the raffle guild (or "(no guild)" for mail only), and whether **guild bank deposits**, **mailed gold** or both buy tickets.
- List the prizes, one per line: the first goes to the winner of draw 1, and so on. Set the ticket price, winners, one win per person, an optional limit per person, the start time and how many hours sales run.

### Run it

- On the **Raffle** tab (`/gt raffle`), click **Start sales now** (or let your start time arrive). The tab counts down to the end.
- The top line keeps a running total: tickets sold, the number of buyers and the gold paid for them.
- **Announce in guild** puts the announcement in the guild chat box; **Text for Discord** gives you text to paste into Discord, with one line per holder with their ticket numbers. Both include the running totals, and so do the winners posts.
- Each deposit or mail buys its amount divided by the ticket price; the rest is dropped (with 1,000g tickets, 5,600g buys 5). Plain donations count too.
- For mailed gold, open your mailbox: each gold mail is counted once and printed in chat. Open it once more after sales end.
- Gold mailed to you counts for whoever mailed it. When you then put that gold in the guild bank, your deposit buys you no tickets until all the mailed gold is passed on: with 100,000g mailed to you and 101,000g deposited, 1,000g is yours. The top line shows what you have passed on and what you still hold.
- Ticket numbers never change once someone has them. New tickets always get the next numbers after everyone else's, so someone who buys again later holds numbers spread through the list. Tickets you remove by hand take that person's highest numbers out of the draw.
- Right-click a buyer and pick **Add tickets...** or **Remove tickets...**, type how many, and confirm; or leave them out of the draw. To give tickets to someone who hasn't bought any (a helper, say), right-click them on the **Members** tab and pick **Give raffle tickets...**. Every change is logged.

### Draw the winners

- When sales end, click **Draw winners** (or **End and draw now** while sales run). Each draw picks a random ticket.
- **Winners to guild chat** and **Winners for Discord** post the results. Right-click a winner to mail them their prize, or to draw a replacement if they can't take it.
- **New / other raffles > New raffle** puts the finished raffle away and opens the settings for the next one.

### Several raffles at once

- **New / other raffles > Add another raffle to sell at the same time** gives you another raffle with its own prizes, price, times, draw and posts. The same button switches between raffles.
- Raffles in different guilds never share bank deposits. Two raffles taking deposits into the same guild bank need different prices: a deposit counts for the raffle whose price it's an exact multiple of, so use odd prices like 1,001g and 1,003g (a new raffle gets one automatically).
- Two raffles taking mail at the same time each need a **mail subject keyword**; a mail counts for the raffle whose keyword is in its subject.
- Anything unclear goes to **Unassigned payments** (in the New / other raffles menu). Right-click to count it for a raffle or ignore it. A raffle won't draw while something unassigned might belong to it.

## Events

See who signed up for a guild event in Discord and who actually showed up, then fill the empty slots. Reads sesh bot posts and your guild's own sign-up sheets. Works for trials with Tank, Healer and DPS limits, and for classes or any event with no limit. Events starts turned off.

### Turn it on

- Open the **Events** settings page (or the button under Events in `/gtsettings`) and tick **Turn on Events**.
- Under **Guilds to advertise in**, tick the guilds that should get your ads for open slots.
- **Group forms (minutes before start)** is when your group starts forming (15 minutes before the start time by default). Before then, ads ask people to sign up. From then on, they ask for replacements.
- Turn **Invite by code** on and set your **Invite code** ("X" to start with; upper or lower case both work) if people who type the code in guild chat should get a group invite (see Fill the empty slots). The top of the Events tab shows the status button (**Invite by code: ON**, **OFF** or **FULL**): click it to turn Invite by code on or off. Next to it, **Options** opens the **Invite by code** window: **Turn on** / **Turn off**, the **Code** box, and, with no event pasted, the **IA (2)**, **Group (4)** and **Trial (12)** buttons that turn it on until your group has that many (you included), solo or already grouped. The window also has a **Dynamic group** button. The ways work differently: **Dynamic group** fills the group (to a pasted event's size, or 12), then pauses (the button says **FULL**) and starts listening again by itself when a spot opens, until you turn it off. A size button fills the group to that size and then stops (Invite by code turns off). **Turn on** with an event pasted fills the event's group and then turns off; with no event pasted it works as a Dynamic group. Either way it turns off when you leave or disband the group. The window explains this too. Invite by code always starts turned off when you log in or reload.
- **Kick offline members** (starts turned off; in the Invite by code window and the Events settings): while Invite by code is on or paused and you lead the group, anyone in the group who has been offline for the minutes you set (10 to start with) is removed from the group, so the spot opens for someone who types the code. A chat line says who and how long they were offline.
- Change the whisper, mail and guild ad texts if you like (one ad for sign-ups, one for replacements). {name}, {event}, {time} (how long until it starts, like "3d 4h 30m from now", right in every time zone), {date}, {need}, {cp}, {code} and {me} are filled in for you.

### Read the sign-ups

- In Discord, select the sign-up sheet (a sesh post or your guild's own) from its title down to the last name under the last role, and press Ctrl+C.
- On the **Events** tab (`/gt events`), click **Paste sign-ups**, click in the box, press Ctrl+V, then **Read sign-ups**. Chat tells you how many sign-ups it read, when the event starts in your time, and how many it matched to accounts.
- **sesh posts:** the addon reads the title, time, CP requirement ("160 CP"), required addons, and every sign-up section with its limit: "Tank (1 / 2)", "DPS (1 / 8)", "Standby (0)" or "Attendees (4)". Any number of tanks or DPS works, and so does a section with no limit.
- **Your own sheet:** line 1 is always the title. Tags have a colon: **Time:** with the time zone written out ("Time: Sat Nov 28 1:00 PM CT", "Time: 2026-11-28 13:00 CT" or "Time: 28.11.2026 13:00 CET"; CT, ET, PT, CET, UTC+2 and others work, and summer time is taken care of), **CP:** ("CP: 600") and **Duration:**. Roles are "Name (have / need)" with the names under them, one per line, as @name or "Name (@Account)". Lines the addon doesn't know are skipped, and lines above the first role are the description.
- Role names with Tank, Heal or DPS in them count as those group roles. Any other role name (Plar, Kite, Portal) is your own role and counts toward the group size. **Standby**, **Tentative**, **Absent** and sesh's **Fills** are never roles. For a class or any event with no roles, use one line **Attending (0 / 20)** (or just "Attending" for no limit) with the names under it.
- **Copy template** (in the Paste sign-ups window) opens with a page on how sheets are read, then gives you blank sheets in that layout to copy into Discord, with an example time in your own time zone: a trial with your own roles (MT, OT, GH, KH, DPS and a Portal role of your own), a trial with Tank, Healer and DPS, a dungeon, and a class with Attending. Pick one with **Next part**, click **Select all** and press Ctrl+C. The parts work in any sheet, so mix tags and roles from different examples as you like. Any name before (have / need) is a role, so rename, add or remove them.
- **Discord time** (in the same window): type a date and time ("Sat Nov 28 8:00 PM CT") and get Discord time codes to copy. Discord shows them in each reader's own time zone, with a countdown, and the addon reads them back when you paste the sheet.
- **Other guilds' sheets** are read as well as they can be: one role per line ("MT: @Briar", "DD @Rumple", "R Plar: @Revan (Cantgetright86)"), a role with no name is an open slot, and a boss-by-boss plan that repeats the roles without names only counts the first set. Notes about gear and mechanics are skipped.
- When the event is over, click **Clear** to empty the tab. The accounts you matched to Discord names are kept for the next event.

### Who's here, who's missing

- Each sign-up shows as **In group**, **In group as (another role)**, **Online, not in group** or **Offline** (with how long), plus their group role and CP. CP under the requirement shows in red.
- People in your group who didn't sign up show as **Not signed up**.
- Names are matched to @accounts in your guilds and friends by name (fancy letters, emoji and spaces are ignored). An @name on a sheet is often a Discord name, so it's looked up too. "Name (@Account)" uses the account written there, "@Revan (Cantgetright86)" also tries the name in brackets, and when no name matches exactly but only one account has a name like it ("zephyrus" in @zephyrus_eso), that one is used; the row's tip says so. If a match is wrong or missing, right-click the row > **Set account**. **Set account (type it)** drops down names from your guilds, friends, group and recent contacts as you type (it starts with names that look like the Discord name); click one, or pick it with the arrow keys and Tab. A name you type is checked when you save and saved with the game's spelling; if it isn't found, the addon says so and suggests close names, and **Save anyway** keeps it as typed. The addon remembers it for every event.
- The line at the top shows each section's sign-ups and how many are here, and the open slots:
- Before the group forms: **Open sign-up slots** (for example "1 tank, 6 DPS"), the slots nobody has signed up for. Everyone who signed up keeps their slot.
- Once the group forms (start time minus the minutes in the settings): **Need now** (for example "1 tank, 1 healer, 7 DPS"), what your group is missing, so people who signed up and didn't show count as open too.

### Ping the missing people

- Right-click a sign-up to **Whisper** them (the text waits in the chat box), **Invite** them to the group, or **Mail** them (the mail opens for you to send).
- **Invite online** sends a group invite to every sign-up who is online and not in your group (not Standby).
- **Copy for Discord** gives you a ready-made Discord post with headings, emoji and the start time shown in each reader's own time zone. Before the group forms it shows the open slots per role and who signed up. Once it forms it shows who is still missing and what the group needs now. Names are written as Discord mentions (**@name**, an @ is added when the sheet has none), so Discord pings those people when you send it. Roles are written as Discord role mentions too: the open slots as **@Tank**, **@Healer** and **@DPS**, and the sign-up list with the sheet's own role names (**@MT**, **@Portal**...), so a server with roles of those names gets pinged. Standby, Tentative, Absent and Attending are not roles and stay as they are. A menu lets you pick either; the one that fits the time is first. Events with no limit (Attendees only) always say there's room for more.

### Fill the empty slots

- With **Invite by code** on, anyone who types your invite code (upper or lower case) in the chat of a guild you advertise in, or whispers it to you, gets a group invite. With no event pasted, that works any time, up to a full group. With an event pasted, it starts once the group forms (until 2 hours after the start time) and stops at the event's group size. The replacement ad tells people the code; while Invite by code is off, the ad leaves the code out. Nobody is invited when the group is full, when you aren't the group leader, when the event hasn't formed yet, or when their CP (as their guild shows it) is under the post's requirement; you get a chat line saying why instead.
- **Advertise in guilds** puts an ad in the chat box of each ticked guild, one after another. Press Enter for each. Pick the kind from the menu: **Ask for sign-ups** (before the event, for the slots nobody signed up for) or **Ask for replacements, join now** (once the group forms, for no-shows and empty slots). The one that fits the time is first.
- **Group Finder** shows a listing to check: the first line is its title (the event's name; numbers and symbols are taken out, since the Group Finder takes letters and spaces only, and at most 5 words: day names go first, then words from the end), the rest its description (the description from the sheet, cut to fit; the Group Finder shows the roles it still needs by itself). It picks the trial from the post ("Sunspire", "vSS") and lists it as Veteran unless the post says normal (or "nSS") and switches your difficulty to match, as the game's own Group Finder does, the playstyle (Educational when the post says trainer or training, Speed Run for a zerg or loot run, Standard otherwise), Voice Chat Required with VOICE REQUIRED in the description (and in the title when the game takes it) when the post says learn, sets the CP minimum, and sets the group's roles to the sign-up limits (2 tanks, 2 healers, 8 DPS for a trial when the post doesn't say). The Group Finder shows who's there and who's still needed by itself. Edit it, then press **Create listing**. You accept applicants in the game's Group Finder window.

## Questions

**Will it kick, blacklist or invite people on its own?**  
Kick, blacklist and Group Finder listings always need your click, and kicks and blacklists ask to confirm. It can do three things by itself, and only if you turn them on: demote (auto-demote), invite someone who types your event invite code (Invite by code on the Events page), and invite someone who whispers a recruiting keyword (Invite automatically under Recruiting).

**I just installed it and already have a pile of alerts. Did it do anything?**  
No. The first time, it looks back 30 days so you can review older withdrawals. Nothing is done to anyone for those.

**Why does Warn put the text in my chat box instead of sending it?**  
Addons can't send chat messages. Press Enter to send it. Mails open filled in and you press Send.

**My bankers keep getting flagged.**  
Add their rank name or @name to the ignore lists in that guild's rules (Guild rules page), then type `/gt reset`.

**I don't see a Rules for section for my guild.**  
Turn the guild on in step 1 of the Start here page (or tick it under Guilds to get alerts from on the main settings page) and reload. The Rules for sections are on the Guild rules page.

**Why is the Bank space tab empty?**  
The game only shows how full a guild bank is while it's open. Open each guild bank once.

**Do I need to be online for it to work?**  
Addons only run while you're logged in. Anything that happened while you were away is picked up at your next login.

**Can my rank use the menus?**  
The menus do what the game lets your rank do. If your rank can't demote, kick or invite in that guild, the game won't allow it.

## More from Fury

- [Fury's Character Tracker](https://www.esoui.com/downloads/info5078.html): every character on one board: skill lines, crafting, research, daily writs, wallet and gear.
- [Fury's Inventory Ledger](https://www.esoui.com/downloads/info5099.html): every item you own in one list, across all your characters, the bank and your houses, with export to Excel.
- [Fury's Account Sync](https://www.esoui.com/downloads/info5106.html): make your other accounts on this PC match your main one: settings, keybinds, addon settings and builds.
- [Fury's Quality of Life](https://www.esoui.com/downloads/info5115.html): small comforts for everyday play: Select all when you deconstruct, a fishing bite alert with the right bait, a queue alert and a lock for everything you wear.

All free on ESOUI and in Minion.

## Credits

- Guild history is read through **LibHistoire** by sirinsidiator (Artistic License 2.0).
- Settings pages use **LibAddonMenu-2.0** by Seerah and sirinsidiator.
- Game API details from the ESOUI wiki and ZeniMax's ESO UI source code.
- Thanks to Dack for code review feedback on how guild history should be read.
- The Guild Crier started as my own separate addon, "Fury's Guild Crier", and is now part of this toolset.
- License: free to use and share for noncommercial purposes under the **PolyForm Noncommercial License 1.0.0** (the LICENSE file on GitHub). Selling it, or any other commercial use, needs a separate license from me: send me a private message on ESOUI.

Bug reports and ideas are welcome in the comments on ESOUI.

---

<sub>**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game in my own guilds before it goes up, and I maintain it. Please report any problem in the comments.</sub>
