
-- NORLibrary.lua — Guild Charter / Library UI for NOR Guild Tools

local Addon = NORGuildTools
Addon.Library = Addon.Library or {}
local Lib = Addon.Library

Lib.window = nil

local function CreateGuildCharterWindow()
    local screenWidth = GetUIGlobalScale() * GuiRoot:GetWidth()
    local windowWidth = screenWidth * 0.6
    local windowHeight = windowWidth * 0.5

    -- Main Window (Draggable & Scaled)
    NORCharterWindow = WINDOW_MANAGER:CreateTopLevelWindow("NORCharterWindow")
    NORCharterWindow:SetDimensions(windowWidth, windowHeight)
    NORCharterWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    NORCharterWindow:SetHidden(true)
    NORCharterWindow:SetMouseEnabled(true)
    NORCharterWindow:SetMovable(true)

    
    --Background Frame
    NORCharterWindow.bg = WINDOW_MANAGER:CreateControl("NORCharterWindowBG", NORCharterWindow, CT_BACKDROP)
    NORCharterWindow.bg:SetAnchorFill(NORCharterWindow)
    NORCharterWindow.bg:SetEdgeTexture("", 1, 1, 0)
    NORCharterWindow.bg:SetCenterColor(0, 0, 0, 0.8)


    -- Title Label
    NORCharterWindow.title = WINDOW_MANAGER:CreateControl("NORCharterTitle", NORCharterWindow, CT_LABEL)
    NORCharterWindow.title:SetAnchor(TOP, NORCharterWindow.contentScrollContainer, TOP, 160, 10)

    NORCharterWindow.title:SetDimensions(windowWidth - 40, 40)
    NORCharterWindow.title:SetFont("SkyrimBooks_Handwritten_Bold|32|soft-shadow-thick")
    NORCharterWindow.title:SetColor(0, 0.5, 1, 1) -- Light blue (RGB: 0, 0.5, 1)
    NORCharterWindow.title:SetText("New OutRiders Guild Library")
    NORCharterWindow.title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    

    -- Left Panel (Scrollable Menu)
    local menuWidth = windowWidth * 0.3 -- 30% of total width
    local contentWidth = windowWidth * 0.65 -- Right-side panel

    NORCharterWindow.menuScrollContainer = WINDOW_MANAGER:CreateControlFromVirtual("NORCharterMenuScroll", NORCharterWindow, "ZO_ScrollContainer")
    NORCharterWindow.menuScrollContainer:SetAnchor(TOPLEFT, NORCharterWindow, TOPLEFT, 10, 60)
    NORCharterWindow.menuScrollContainer:SetDimensions(menuWidth, windowHeight - 80)
    NORCharterWindow.menuScrollChild = NORCharterWindow.menuScrollContainer:GetNamedChild("ScrollChild")

    NORCharterWindow.contentsLabel = WINDOW_MANAGER:CreateControl("NORCharterContentsLabel", NORCharterWindow, CT_LABEL)
    NORCharterWindow.contentsLabel:SetAnchor(TOP, NORCharterWindow.menuScrollContainer, TOP, 20, -30) -- Adjust positioning
    NORCharterWindow.contentsLabel:SetDimensions(menuWidth, 40) -- Match menu width
    NORCharterWindow.contentsLabel:SetFont("ZoFontGameBoldUnderline|26|soft-shadow-thick") -- Matches the title font
    NORCharterWindow.contentsLabel:SetColor(0, 0.5, 1, 1) -- Blue color (RGB: 0, 0.5, 1)
    NORCharterWindow.contentsLabel:SetText("Codex of the Order")
    NORCharterWindow.contentsLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER) -- Centers the text


    -- Right Panel: Scrollable Text Display
	NORCharterWindow.contentScrollContainer = WINDOW_MANAGER:CreateControlFromVirtual("NORCharterContentScroll", NORCharterWindow, "ZO_ScrollContainer")
	NORCharterWindow.contentScrollContainer:SetAnchor(TOPLEFT, NORCharterWindow.menuScrollContainer, TOPRIGHT, 10, 0)
	NORCharterWindow.contentScrollContainer:SetDimensions(contentWidth, windowHeight - 80)
    NORCharterWindow.contentScrollChild = NORCharterWindow.contentScrollContainer:GetNamedChild("ScrollChild")
    

    -- Scrollable Text Area
	NORCharterWindow.textDisplay = WINDOW_MANAGER:CreateControl("NORCharterTextDisplay", NORCharterWindow.contentScrollChild, CT_LABEL)
	NORCharterWindow.textDisplay:SetAnchor(TOPLEFT, NORCharterWindow.contentScrollChild, TOPLEFT, 10, 10)
	NORCharterWindow.textDisplay:SetDimensions(contentWidth - 40, windowHeight * 2) -- Expand height for scroll
	NORCharterWindow.textDisplay:SetFont("SkyrimBooks_Handwritten_Bold|16|soft-shadow-thick")
	NORCharterWindow.textDisplay:SetWrapMode(TEXT_WRAP_MODE_WORD)
	NORCharterWindow.textDisplay:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	NORCharterWindow.textDisplay:SetColor(1, 1, 1, 1)
    NORCharterWindow.textDisplay:SetText("Welcome to the New OutRiders Guild Library, a plethora of knowledge at your fingertips!")
    

    -- Create the shield texture (Overlay)
    NORCharterWindow.guildShield = WINDOW_MANAGER:CreateControl("NORCharterGuildShield", NORCharterWindow.contentScrollContainer, CT_TEXTURE)
    NORCharterWindow.guildShield:SetAnchor(CENTER, NORCharterWindow.contentScrollContainer, CENTER, 0, 0) -- Keeps it in place
    NORCharterWindow.guildShield:SetDimensions(contentWidth * 0.57, windowHeight - 80) -- Adjust the width ratio as needed

    NORCharterWindow.guildShield:SetTexture("NORGuildTools/Textures/norlogodds.dds") -- Relative path to image file
    NORCharterWindow.guildShield:SetAlpha(0.3) -- Transparency for readability
    NORCharterWindow.guildShield:SetDrawLayer(DL_BACKGROUND) -- Places it behind text



-- Adjust the scroll child height dynamically based on text size
    NORCharterWindow.contentScrollChild:SetDimensions(contentWidth - 40, windowHeight * 2)    

-- Function to Change Text When a Button is Clicked
    local function UpdateCharterText(text)
        NORCharterWindow.textDisplay:SetHorizontalAlignment(TEXT_ALIGN_LEFT) -- Reset alignment
        NORCharterWindow.textDisplay:SetText(text)
    end

    

    -- Charter Sections (Replace These With Actual Content)
    local sections = {

        { name = "About Us", text = [[

Welcome, and Hail *NOR/!

Note: If you happened upon this Addon and are interested in joining one of the oldest guilds in existence, go to https://newoutriders.org/join and fill out our online application!

We are a casual, mature, family-friendly guild that has been around since 1992 when it was founded in the game The Shadow of Yserbius on the ImagiNation Network (INN). The guild has had a presence in over 30 online games in the past 30 years. The New Outriders (NOR) is active in several current games and have a dedicated group of enthusiastic players looking to grow the guild and experience all aspects of these games.

“To have fun and help others do the same” is the philosophy that guides us and we are looking for more friendly, mature members to enjoy the game with us. We have a mix of veteran members along with plenty of people who are brand new to the guild and gaming. Whether you are a long-time veteran looking to be around people who love the game as much as you do, or someone new and just playing the game for free, you are welcome to join us.

What we offer:

1. A rich history of tradition in greeting our members, celebrating their dedication in supporting guildmates with awards and promotion through the guild ranks.
2. The feel and experience of a guild having the oversight and support of a core group of long-time MMO veterans, led by the High Council.
3. Weekly ingame events.
4. Dedicated website with complete roster information, forums, event calendar, and more.
5. Discord voice and chat server with dedicated game channels.
6. Support for other MMOs. The friends you make here in the *NOR/ realm you choose to play will be with you as you explore future games.

Is *NOR/ for you?

The kind of people we look for:

- Friendly, mature people (comfortable with a “PG” atmosphere) who fit within the principles that have served NOR well for decades. In brief, our principles are:
- Have fun!
- Help each other.
- Cooperate as a team.
- Service the greater good, group and guild.

How is the New Outriders different from other guilds?

1. NOR is an incorporated legal entity under 501c7.
2. Member produced monthly newsletter.
3. Internally created Online Application and Roster
4. Multi-Game Infrastructure, making it seamless as possible to connect with guildmates in this game or your next.

We look forward to seeing you in-game for many years to come!

        
___

 ]] },

        { name = "Commands Help", text = [[

        Here are the text chat slash commands that you can use for "purposes".
        
        /nor : Opens this window for access to Guild Documents
        /nor_trial  : Displays privately in text chat what and when our next trial is.
        /nor_event  : Displays privately in text chat what and when our next event is.
        /nor_holdings : Lists our guild holdings privately in text chat as clickable links for ease of travel.
        /timemachine : A stopwatch for timing things.
        /countdown <minutes> : A countdown timer.
        /nor_jacket : Dons/removes the Tabard, displaying your guild tag.
        /nor_jacket_status : Checks Tabard Status as it does on login.
        /nor_recruit : Populates the chat window with a standardized recruiting message you can send to a zone 
        with our applicable guild advertisement link to apply.
        /h : Populates the chat window with a Hail *NOR/!
        /nor_help : Returns this slash command list, but to your chat window.
        /norai : Activates NOR Autoinvite.
        ___

 ]] },
    
{ name = "Trial Team Rules I", text = [[
Trial Team Rules:

In order to increase the speed, efficiency, and enjoyment of our raid teams, I am implementing the following rules for our fixed raid groups:

Timeliness:

There will be a sign-up sheet in the NOR ESO Discord Channel section for *NOR-ESO (#eso-trial-signups). We are counting on you to sign up in a timely manner and to remove yourself from the signup sheet if you cannot make it. Sometimes things come up suddenly, please do your best to let us know.

Each raid team member must show up no less that fifteen minutes before the raid. Make sure your equipment is in good repair, you have repair kits on hand, and you have any food buffs you think will help you in the fight.

If a member is not ready and hasn't notified us, we will start the process of a substitute starting 5 minutes before the raid. We want to begin these things on time as much as possible.

Remember, there are eleven other people counting on you.


Preparedness:

Every member will make sure to have the content unlocked before the raid and watch or read the appropriate guide. The raid time is for raiding, not for unlocking content. You have 6 other days during the week to unlock content. If someone needs help, there are plenty of people who can help. Contact me or the DMG if you need assistance with this.


Discord Communications:

Everyone on the raid team needs to be on Discord with, at minimum, the ability to listen. During the fights, callouts will be done by the raid leader or someone designated by the raid leader to assist with callouts. If tank swaps are necessary in the fight, the tanks will communicate with each other as well. Calm and professionally, not like someone just stuck an axe in your back. Also, during the combat phases, comms will be kept to a minimum so clear-as-possible instruction and callouts can be given.
___

 ]] },

 { name = "Trial Team Rules II", text = [[

In the event of a wipe, which happens often, between pulls is the time for the group to analyze what happened and talk about corrective actions. Everyone's opinion here is valuable and that is when we can have a group discussion on how to improve our performance.
Some things go without saying, but even with multiple wipes which can be frustrating, we will not take it out on other members of the group. Not in our tone, not in our language, not in our attitudes. We will be kind and polite and respectful at all times. We will keep the swearing down to an absolute minimum because stress and negativity breeds more stress and negativity. So, let's keep it NOR-like.

Also, Tanks are there to tank and they know this. Healers are there to heal and they are aware of this - that is why they are on that job. So, please don't yell out for tanks to taunt or healers to heal, they are well-aware.

In between pulls, we will together examine what went wrong and then the raid leader will offer suggestions in a polite, respectful way. Anyone constantly badgering another player and ordering someone else about will be dealt with swiftly.

Conclusion:

If we follow these basic rules, our raids should run very smoothly and everyone should enjoy them. If we do have trouble with a fight, we will beat it eventually. Most trials run an hour to an hour and a half if done by a team that knows the mechanics. Learning runs have a cap of two hours with several breaks during the run. If we stay organized we will do wonderfully.

Lord Garadian,
*NOR/LD-HC
___

 ]] },

    { name = "Charter Home", text = [[
New OutRiders Guild Charter

Jacket Creed: 

I promise to wear the NOR name with pride. While wearing it, I will bring no shame or dishonor to NOR in word or deed. I will defend it and anyone else who wears it to the uttermost limits of my ability.

***Important NOTE:***

This Copy of the NOR Charter is for quick reference. The complete and definitive document can be found at https://newoutriders.org/charter.
___

 ]] },


       { name = "Mission Statement", text = [[
Mission and Sphere:

Our mission is to provide an online gaming community where our members have fun and play online games together, render aid and assistance to all, extend our presence to new games, and expand our membership.

Sphere of Influence of this Charter:

This Charter and Appendices pertain only to NOR and its members. This is the sole governing document of this guild. No citation of outside sources may be made for any purpose whatsoever.
___

 ]] },

        { name = "Membership", text = [[
Membership:

Membership in New OutRiders (NOR) is voluntary and a privilege, not a right.

a. The guild attributes membership to the individual player, not their characters or ingame personas.
b. Members will not discriminate or be discriminated against by NOR or its members on any basis.
___

 ]] },

        { name = "Admission", text = [[
Admission:

1. Admission to New OutRiders is determined by the presiding officers who will specify the method of applying and the status of any application.

2. The application is currently available online at: www.newoutriders.org/join

3. When asking to join or being admitted, all candidates agree to abide by the terms of membership in NOR and will:
   a. Provide a valid email address, date of birth, and first name for purposes of compliance with this Charter and record keeping.
   b. Be age 16 years or older.
1. Minors will not be admitted unless their parents or guardians are currently members.
2. Minors must be supervised by their member-parents or guardians while online.
3. Parents or guardians are responsible and accountable for the behavior of minors in their charge.
4. Conduct themselves in a courteious and socially-appropriate manner.
5. Restrict text and speech in public text and voice channels to “Family-Friendly”;
6. Abide by each game's Terms of Service or End User License Agreement.
7. Comply with directives of this Charter, guidance from officers in the guild Chain-of-Command, as well as other NOR documents, if any, cited in this Charter.
8. Not previously been expelled from NOR. To apply for Reinstatement, see the appropriate section in this Charter.
___
]] },

	{ name = "Jacket Creed", text = [[
Jacket Creed:

The NOR “Jacket” is defined as the specific tool used in each branch to identify a character as a member of New OutRiders. This is also referred to as a “Guild Tag”. The ”Jacket” is an imaginary badge of membership that is directly attached to the name of a member.

“I promise to wear the NOR name with pride. While wearing it, I will bring no shame or dishonor to NOR in word or deed. I will defend it and anyone else who wears it to the uttermost limits of my ability.”
___
 ]] },

	{ name = "Standing", text = [[
Standing:

There are a number of states a Member may be ascribed referred to as Standing.

1. Active: The member is online, visible and interacting with other members on a regular, ongoing basis.
2. MIA: Missing in Action. Member has not been seen online on any branch or the forums in over sixty (60) days.
3. LOA: Leave of Absence. Any member or officer may request relief from their duties for a limited period of time
4. Expelled: Member has been forcibly ejected from the guild.
5. Quit: Member has voluntarily left the guild and given notice of their intent.
6. Never Tagged: A recruit who filled out an application but never received a guild tag.
___
 ]] },

	{ name = "Allies and Recruits", text = [[
Member Ranks and Non-Member Status:

Each member of NOR is assigned a rank, starting with Recruit until their induction into the guild as a full member at the rank of Squire. A Recruit is not officially a member of NOR until Squired. Members may thereafter advance in rank in accordance with their own merit and at the discretion of their officers.

All ranks enjoy mutual reciprocity on all Branches of NOR. This means one’s rank on one realm is the same as the rank on another with all of the attendant privileges and responsibilities. Length of time in rank are guidelines only and neither a guarantee or requirement.

The current ranks of NOR are, in ascending order:

1. Allies (AL)

The Allies is the non-member status in the New OutRiders. This status is for raiding friends, friends and family that may have joined a realm, but for many reasons have not become members.
If the Ally wears a NOR guild tag they must fill out a guild application.
Allies wearing a guild tag must follow the guild charter’s rules stated in the ‘Admission’ and ‘Jacket Creed’.
Allies may post on non-member sections of the forums and join members in VoIP channels.

2. Recruit (RT)

The recruitment time is a trial period for both the recruit to see if NOR is the guild for them and for the officers to be sure the new recruit is a good fit for the guild. Upon full admittance into the guild a recruit will move to the member rank of Squire.

Recruit Requirements:
An application must be filled out, confirming they have agreed to the guild’s charter.
___


 ]] },

	{ name = "Squires and Knights", text = [[
3. Squire (SQ)

The majority of the guild’s membership is a Squire rank.

Squire Promotion Requirements:

Previously a Recruit rank for two or more weeks

3. Squire Court (SC)

The majority of the guild’s membership is a variation of the Squire rank.
Squire Promotion Requirements
Previously a Squire rank for three or more months.

4. Squire Honor (SH)

The Squire Honor along with Squires are the majority of the guild’s membership.

Squire Honor Promotion Requirements:
Previously an active Squire rank for three or more months.

5. Knight (KT)

Knights have been with the guild long enough that they understand the way the guild operates, they have shown dedication to the guild and are great examples to new recruits and squires.

Knight Mandate:

As non-officer members of the New OutRiders, Knights have no official mandate, however they have the power to tag alts of members.

Knight Promotion Requirements:

Previously an active Squire and or Squire Honor for nine or more months.

6. Knight Elite (KE)

Knight Elites have been with the guild long enough that they understand the way the guild operates, they have shown dedication to the guild and are great examples to new recruits and squires.
Knight Elite Mandate
As non-officer members of the New OutRiders, Knights have no official mandate, however they have the power to tag alts of members.
Knight Elite Promotion Requirements
Previously an active Knight for six or more months.
___

 ]] },

	{ name = "Champions", text = [[

6. Champion (CH)

The Champion is the highest non-officer rank in order of precedence in the New OutRiders. As non-officer members of the New OutRiders, Champions have no official mandate. They also have the power to tag alts of members.

Champion Promotion Requirements:

Previously an active Knight for one year or more.
___

 ]] },

	{ name = "Baron and Baroness", text = [[

7. Baron (BA) or Baroness (BA) or Banneret (BA)

The Baron is the entry officer rank in order of precedence in the New OutRiders.

Baron Mandate:

As officers of the order, Barons have the following mandate:
i. Follow the items listed in the Officer Mandate
ii. Your valued opinion, the Branch Leader will have several decisions when running a realm and may need multiple opinions to make their final decision.
iii. Carry out any tasks assigned to you by your CT/CS.

Baron and Baroness Promotion Requirements:

i. Any member Squire or above can be considered for a Baron/ess. Branch Leaders consider previous officers first for an active Officer position, then Champions and so forth down the hierarchy.
ii. When retiring from Baron or Baroness you receive the rank of Grandee.
___

 ]] },
	
	{ name = "Count and Countess", text = [[

8. Count (CT) or Countess (CS) or Castellan (CN)

The Count/ess is the second in charge at the branch level. They are one of the branch leaders closest advisors. They are also first to take over the realm when the Duke/Duchess steps down.

Count Mandate:
As officers of the order, Counts have the same mandate as Barons with these additions:
1. Follow the items listed in the Officer Mandate
2. Meet with the Baron/ess’s and Branch Leaders as often as necessary to keep the Duchy running smoothly.
3. Promote up to BA/BS those who are deserving with Ducal consent.

Count and Countess Promotion Requirements:

i. Previously an active Baron/ess for three or more months.
ii. When retiring from Count or Countess you receive the rank of Viscount or Contessa.
___
 ]] },

	{ name = "Duke and Duchess", text = [[

9. Duke (DK) or Duchess (DC) or Dux (DX)

The Duke and Duchess are the Branch Leaders that maintain and run the individual games the guild is established in.

Duke and Duchess Mandate:

1. Follow the items listed in the Officer Mandate
2. Moderate and Schedule branch meetings.
3. Supervise the officers in your Duchy, and meet with them as often as necessary to keep the Duchy running smoothly.
4. Promote up to CT/CS to fill the needs of a growing Duchy.
5. Ensure the Branch online roster is current and updated before the first Sunday of each calendar month. This may be delegated to another Officer.
6. Attend the weekly HC meetings at least twice each month, one being the official business meeting.
7. Notify members monthly via guild Newsletter of your realm’s current state, such as changes in officership, guild events, major game and branch changes and updates.
8. Act as Liaison to the other Guilds/Orders and entities within your server as needed.

Duke and Duchess Promotion Requirements:
i. Previously an active Count/ess for three or more months
ii. When retiring from Duke or Duchess you receive the rank of Marquis or marquise.
___

 ]] },

	{ name = "Branch Leader/Realm Advisor", text = [[

10. Branch Leader (BL)

The Branch Leader is the main person that runs the realm and makes the day to day decisions regarding the direction that branch takes. Branch Leaders are normally the rank of Duke/Duchess, however smaller branches or provisional branches can start off with a Baron/ess or Count/ess as the Branch Leader and they will be responsible for the Duke/Duchess Mandates.

11. Realm Advisor (RA)

In the New OutRiders the Realm Advisor is a Lord/Lady of the High Council who acts as a mentor, adviser and liaison between a NOR branch and the HC. 

Realm Advisor Mandate:

This office is limited to members of the High Council.

i.   Carry out or assign the duties of the Branch Leader in the realm (game) assigned if there is no Branch Leader.
ii.  Deal with matters of immediate importance in an assigned realm as soon as possible.
iii. Advise and train new and existing Branch Leaders to your Realm.
iv.  Ensure prompt flow of important information to the rest of the High Council.
v.   Act as one of the panel of HC members for disciplinary action.
___

 ]] },

	{ name = "Lord and Lady", text = [[

12. Lord (LD) or Lady (LY) or Liege (LI)

- The Lord and Lady is the highest rank in order of precedence in the New OutRiders. They are the active sitting High Council members.
- The High Council Mandate is described in the High Council section of this document.
Emeritus (LE) is the rank of a previous HC member no longer seated.

Lord and Lady Promotion Requirements:

The sitting High Council may collectively vote upon and promote a guild member Candidate to the rank of Lord or Lady at their own discretion. When considering a new Candidate for an available High Council seat, the acting High Council members shall take the following factors into consideration, (in no particular order):
1. Tenure of Candidate within the guild;
2. Candidate’s consistency as an active and participating member of the guild;
3. Candidate’s current rank and duration at that rank, with greater weight given to active Branch Leaders, Dukes, and Duchesses;
4. Whether the Candidate currently holds the position of Lord Emeritus or Lady Emeritus;
5. Candidate’s interest in, enthusiasm, and noteworthy efforts towards the growth of the guild;
6. Candidate’s aspiration to become a High Council member;
7. Candidate’s (expressed) personal motivation, individual energy level, and space/time available in their life to be part of the High Council experience;
8. Candidate’s history of disciplinary actions with or departures from the guild.

*Sometimes. higher ranked officers will fulfill lower ranked officers’ positions. For example an Count may be a Acting Baron or an Duke may be an Acting Count, these officers will keep their original rank title while filling other roles that a realm may need.
___

 ]] },

	{ name = "Officer Mandate", text = [[

Officer Mandate:

All members of NOR holding an officer rank must:

1. Model the values of NOR and virtues of good membership at all times;
2. Recruit new members.
3. Actively look for recruits that have filled out an application in your realm and tag them into the guild.
4. Keep track of WHO has done WHAT (Recruiting, Services to NOR, etc.) and pass this information along to your Branch Leader.
5. Perform member’s promotion ceremonies up to the rank immediately subordinate, with the consent of your superiors and announce promotions on the guild forum.
6. Have a working NORforum account and email account.
7. Answer questions, offer guidance and assistance, referring members up the chain of command if need be;Modify or mitigate the decisions of your subordinates when necessary.
8. Participate in guild and membership activities both ingame and out.
9. Attend guild meetings;
10. Keep a record of significant events involving the members, including date, rank, location, screenshots and details of what occurred. Make this information available to your superiors; If you need to step in please do so by private message instead of guild chat.
11. Enforce discipline, correct misconduct or mete out punishment when appropriate.
12. Obey the lawful orders of a superior.
___

 ]] },

	{ name = "High Council", text = [[

High Council:
The High Council (HC) is the body of members holding the rank of Lord or Lady that are collectively the final authority on all matters pertaining to NOR and must:

1. Consist of no fewer than three (3) members;
2. Hold their seat indefinitely but reaffirmed annually to verify the accuracy of contact information;
3. Be permitted to take a temporary Leave of Absence (LoA) from their duties for up to ninety (90) days or 25% of the scheduled HC Meetings (whichever is least) per year after which the member may be demoted, removed from office or both;
4. Render all decisions or take official action only by majority vote except where otherwise explicitly stated;
5. Make or change rules or regulations for the guild, including any portion of this Charter;
6. Collect and spend donations or other voluntary revenues from members for the purpose of supporting guild expenses;
7. Ensure that all income, collection and spending is reported to the membership;
8. Acquire property or enter into contracts on behalf of the guild;
9. Enter into guild-wide alliances with other guilds;
10.Establish or endorse new branches;
11.Stay in close contact with the members of NOR as an active and visible player on at least one branch in the role of Realm Leader;
Not make a rule for one member that does not apply to another.

No Quorum:

In the event the number of seated HC members drops below three (3) the remaining High Council members may:

1. Appoint a Councilor pro temp from among the highest ranking officers available for the purpose of conducting ordinary guild business until a permanent HC member may be seated.
2. Request former HC members return as voting members.
3. Not overturn a previous vote by a full HC until a quorum is re-established.
___

 ]] },

	{ name = "High Council Meetings", text = [[

High Council Meetings:

Meetings are public gatherings of the membership to conduct guild business.

1. The High Council will hold regular Open meetings at a day, time, venue and frequency of their choosing that is not less than once per month. Records of these meetings must be kept and made public.
2. Open HC Meetings may be attended by any member of NOR and their guests;
3. HC members will serve as chairperson on a rotating basis to their liking; The chair may:
	a. Gavel in the meetings;
	b. Set the agenda;
	c. Call for a vote;
	d. Open or close discussion on a vote;
	e. Close a queue.

The HC may conduct Closed meetings for any compelling reason the High Council deems appropriate. Records of these meetings must be kept and made available only to HC members.
1. The use of proxies is permitted for a specific vote;
2. A quorum must be present to vote.
3. A quorum is the presence of greater than 51% of the seated members of the High Council.
4. A proxy does not constitute a quorum.
5. An emergency meeting may be called by any HC member by notifying all HC members and receiving their acknowledgment within twenty-four (24) hours.
___


 ]] },

	{ name = "Meeting Agenda", text = [[

Agenda:

The customary agenda for HC Meetings is as follows:

1. Gavel in;
2. First meeting of each month is the Business Meeting, during which the HC receives reports from the individual Branches, otherwise;
3. Open forum;
4. Old business;
5. New business;
6. Adjourn;

Voting:

1. An HC member (movant) must have the floor to make a motion;
2. Any other member may “second” the motion;
	a. If the motion is not “seconded”, the motion dies;
	b. There may be only one motion on the floor at a time;
	c. The Chair must call for discussion of the motion once “seconded”;
	d. Movant may withdraw their motion at any time, without objection;
	e.Movant may amend their motion based on the discussion, without objection;
3. If a member objects, the motion must proceed unaltered;
4. Once discussion is closed the vote is called;
5. Voting by email may be conducted if there is a compelling need, but the motion and the results must be read into the record at the next Open or Closed meeting.

Speaking:

1. Attendees declare their desire to address the HC regarding the current topic by typing a single exclamation point “!” in order to be recognized and enter the que to be given the floor;
2. To declare a different topic than that being discussed they type a single question mark “?”;
3. Speakers yield the floor by typing “<d>” or “Done” or some clear indication that they have finished speaking.
___


 ]] },

	{ name = "High Council Recess Schedule", text = [[

High Council Recess Schedule

1. Any Sunday 3 or less days, either side of New Years day.
2. Superbowl Sunday
3. Valentine’s day when said holiday occurs on a Sunday.
4. St. Patrick’s day when said holiday occurs on a Sunday.
5. Easter Sunday.
6. Mothers Day.
7. The Sunday adjacent to the US Holiday, Memorial Day.
8. Fathers Day.
9. The closest Sunday to July 4th when the said date occurs on any day from Thursday-Tuesday.
10.Any Sunday in August that the High Council will not have a Quorum. (Dates will be posted on the forums no later than the last day of July)
11.The Sunday adjacent to the US Holiday, Labor Day.
12.Halloween when said holiday occurs on a Sunday or Monday.
13.The Sunday following the US Thanksgiving Holiday.
14.Any Sunday 3 or less days, either side of Christmas Day
___


 ]] },

	{ name = "Promotion", text = [[

Promotion:

An advancement in rank awarded to members in good standing by officers of the guild at their discretion within the parameters specified in the Officers Mandate section using the following criteria as a guide:

1. Helpfulness to others.
2. Knowledge of the game.
3. Awards.
4. Time in service.
5. Overall attitude.
___

 ]] },

	{ name = "Ceremonies and Oaths", text = [[

Ceremonies & Oaths

Ceremonies are typically embellished for flair or entertainment value when appropriate. Officiants may add to the ceremony if they like, but they may not subtract any language.

1. Induction Ceremony (Squiring)

Also known as “Squiring” – this ceremony marks the acceptance of a candidate-recruit as a full member of NOR and is when they receive their “Jacket”:

“[Name], do you wish to become a member of NOR, yea or nay?”
Response: “Yea.”
“Very well, [Name], please come forward and kneel.”
“Do you promise to protect the weak and defend the innocent?”
“Do you swear to abide and uphold the Charter of the guild of the New OutRiders?”
“Recite the Jacket Creed after me:
I promise to wear the NOR name with pride. While wearing it, I will bring no shame or dishonor to NOR in word or deed. “I will defend it and anyone else who wears it to the uttermost limits of my ability.”
“And do you all here, bearing witness to these oaths, reaffirm your own fealty and promise to aid this member in the keeping of their vows?”
Response: “We do!”
[donate to the traditional ear bucket];
“Then by the power vested in me by … [Rank and Name of superior officer, if applicable] and … the High Council of NOR, I dub you Squire [Name];
“Arise Squire [Name] and be greeted by your guild.”;

2. Promotion Ceremony

The primary difference in this ceremony is the affirmation of the Jacket Creed rather than its full recitation.

“[Name], you are being offered a promotion to the rank of [Rank], do you accept, yea or nay?
Response: “Yea.”
“Very well, [Name], please come forward and kneel.”
“Do you promise to protect the weak and defend the innocent?”
“Do you swear to abide and uphold the Charter of the guild of the New OutRiders?”
“Do you reaffirm the Jacket Creed?”
(If Officer) Ask: “Do you swear to carry out the duties of your new rank?”
“And do you all here, bearing witness to these oaths, reaffirm your own fealty and promise to aid this member in the keeping of their vows?”
Response: “We do!”
[Mutilate the member in some grotesque fashion … again];
“Then, by the power vested in me by … [Rank and Name of superior officer, if applicable] and … the High Council of NOR, I hereby promote you to the rank of [Rank], with all of its attendant privileges and responsibilities;
“Arise [Rank][Name] and be greeted by your guild.”
___

 ]] },

	{ name = "Ribbons, Awards, Medals I", text = [[

Ribbons, Awards & Medals:

The purpose of the NOR Awards program is to provide special recognition to members. Eligibility and criteria are listed under each individual award and can be found under the Awards page. Additional awards can be petitioned to the HC for creation.

Ribbons:

On the individual member profile of the online roster, each member displays a ribbon representing a Branch in which they were present as a member of NOR.

Awards & Medals:
All medals are awarded “downrank” to any member of NOR unless otherwise specified.

Venerable Order of Yserbius:

The highest granted in the guild. This medal may be awarded only by the HC. This is granted to a member for truly exceptional service above and beyond the call of duty. It may be granted no more than once per year (and there may be years it is not granted at all) to a a member in service for no less than five (5) years that currently or previously held an officer rank. The vote of the HC must be unanimous.

Silver Starburst:

Formerly “Silver Star Burst”. A recruiting award granted to members who have recruited ten (10) new members who are at least Squired.

Golden Aldobora Tree:

Name truncated to “Golden Aldobora Tree” from “Golden Star of the Aldobora Tree” Awarded to a member for consistently organizing, scheduling and participation in regular guild or branch events.

Heart of the Purple Dragon:

Presented to members who have been subjected to unusual pain and suffering in pursuit of aiding the guild or assisting other players.

NOR Commendation Medal:

This medal may be granted by any officer ranked Baron or above at their sole discretion, in recognition for what they find, in their judgment, are actions or behavior worthy of citation by the guild.
___


 ]] },
	{ name = "Ribbons, Awards, Medals II", text = [[

NOR Meritorious Achievement Medal:

This is a group award made to an entire Duchy, including the Duke or Duchess primarily for first reaching “Duchy Status” on a new branch. But it may also be awarded for other notable accomplishments or achievements made by a branch as a whole. When this award is granted, it is received by all members Active on the roll at the time it is nominated. Because the recipients include flag officers, only the High Council may award this version of the medal. This award has three variants, granted to each Squired member at the time of nomination to the entire group.

Founders Medal:

Awarded only to members who joined NOR on TSoY.

NOR Family Award:

This award has several individual qualifications, any one of which would permit its awarding:

Silver Gavel:

Presented by the High Council to a member attending their first HC meeting.

Guild Unity Event Medal:

Awarded to members for attending their first GLUE event.

Forum Ribbon:

Granted to members for achieving certain benchmarks in posting on the guild forums. These are currently: 1000, 2500, 5000 and 10000 posts.

Benefactor:

for contributing to the guild monetarily, either ingame or RL.

Broadcaster:

for contributing to the New OutRiders Podcast.

Scribe:

for contributing to the New OutRiders Newsletter.
___



 ]] },

	{ name = "Ribbons, Awards, Medals III", text = [[

Officer of the Year:

An annual award, nominated by their peers and selected by the HC.

Member of the Year:

An annual award, nominated by their peers and selected by the HC.

New Member of the Year:

An annual award, nominated by their peers and selected by the HC.

Basher:

Awarded for attending an RL Bash. This award requires no nomination process, but is automatically awarded to any member who attended a Bash.

The Order of NOR Masons:

Awarded for helping to build guild property in game. I.e. those that helped build the NOR Castle module in NW, or Guild ships in swToR/ARC, or anything of that nature. With possible 1st degree, 2nd degree etc if someone helped in multiple branches.
___


 ]] },	

	{ name = "Branches and Realms", text = [[

Branches and Realms:

The High Council has complete discretion ordering sanctioned branches, regardless of game or platform. The organizational structure of NOR branches is as follows:

Active:

Active Open Realms are the most active games that New OutRiders members currently play. These branches of the guild actively recruit, run events, and have a structured hierarchy.

1. An active realm must fall into the size of Barony, County or Duchy; and
2. Have a member able to perform the duties of a Branch Leader.

Barony:

Four to six (4-6) members and one (1) officer, typically a Baron or higher.

County:

Eight to twelve (8-12) members and three (3) officers, two Barons and one Count.

Duchy:

Sixteen to twenty-four (16-24) members and seven (7) officers, four Barons, two Counts and one Duke or Duchess.
___

 ]] },

	{ name = "NOMAD and Provisional", text = [[

NOMAD:

NOMAD realms are places where the New OutRiders “jacket” guild name is used by our members. These branches have no recruiting or structured hierarchy.

Below are the expectations for use of the New Outriders name, be it a game on PC, Mobile or Console. These realms are for existing members to play together where NOR doesn’t currently have an active recruiting realm of play. Common examples of these realms are new games that have not yet become provisional branches due to being in alpha/beta, or previously active realms that have been closed that may have a remaining active members, and also games that may not have a guild structure option. The High Council needs to be aware of where the “New Outriders” name is being used due to the importance of the guild’s name and must follow the guild charter and philosophy.

1. NOMAD realms are designed for existing NOR members only.
2. No active Recruiting or expanding until the game becomes a provisional branch or HC is petitioned.
	a. Family and friends that are recruited gain the status of “Allies” and in some instances may become members per HC approval.
	b. Recruits that transfer to a NOMAD realm and are no longer active in a Active Realm of NOR become Allies status.
3. Active members in these games fall into our NOMAD realm.
4. The guild member(s) interested in creating a new NOR branch in an unofficial NOR realm must petition the High Council for permission to use the New OutRiders name and *NOR/ tag.
5. These branches do not require an active hierarchy, but must follow NOR policies and standards.
6. Provide information about the game that can be added to the NOMAD forum section
	a. Game name & website.
	b. Platform (console, mobile, pc).
	c. NORmember realm creator.
7. The realm creator notifies the HC when they are no longer playing the game.

Provisional:

A provisional realm is a new recruiting realm that is in its initial phase of becoming an active realm.
___

 ]] },

	{ name = "Creating a Branch", text = [[

Creating a Branch:

Any member, preferably an officer, may petition the High Council to open a new branch. That petition should take the following form:

1. A written request to the entire HC or a verbal request at an Open High Council Meeting, for the endorsement of a particular game as a new Branch of the guild; details should include:
a. List of members who have expressed an interest or who are currently playing, include their current rank and current realm if applicable.
b. Proposed CoC(Chain of Command).

2. All new branches are considered a provisional Barony.

The status of a branch may be upgraded by a vote of the High Council either of its own accord or at the request of the resident officers;
Upgrades continue to be provisional until voted by the High Council as an official Branch.
Official branches would ideally have a representative on the High Council; a Realm Leader.
___

 ]] },

	{ name = "Branch Leadership", text = [[

Leadership:

If the HC wishes to proceed in creating a branch, the HC will decide at a closed meeting who will head the branch.

This person must agree to do the following while in provisional status::

1. Attend ¾ of open HC meetings during the provisional period, to include all business meetings. Be prepared to discuss how your prospective branch is progressing.
2. Keep HC up to date on all branch issues.
3. Hold regularly scheduled meetings at least once every two weeks during the provisional period. Meet with officers regularly. All meetings should be scheduled, if short notice meetings will be held, notify the RL so he/she may attend if able. IF the game is not Free to Play (F2P), Officer meetings should be held in Discord and follow NOR meeting protocol, unless all present officers agree to an alternate method (I.E Voice chat).
4. Be in the game of the new branch as much as possible (check guild mail, PMs and NOR forums Daily).
5. Develop a Branch addendum to the NOR Standards and Convention that addresses any items in the new game not covered by current NOR documents. This addendum should provide guidance on any rule or content issues identified in the provisional petition. A draft of this document should be e-mailed to the HC and a finalized copy of this document must be presented to the HC and posted as a sticky on the forums or on the NOR Wiki, before the branch can be elevated to full Duchy.
6.Form a branch structure, in the new branch as discussed below. Keep all branch officers apprised of which members fall under them.
7. Transfer on permanent basis to the new branch
8.Ensure all new recruits sign up on the NOR web site and are listed on the online roster, prior to squiring. If a recruit is unable or unwilling to sign up on the web site, obtain the necessary information and manually add them to the roster – see your RL if you are not able to do so. All squired members of the branch should appear on the online roster. Keep a separate list of any recruits that have not signed up and include those numbers with your monthly business report.

The High Council assigns one of its members to act as Realm Leader (RL) in the new branch. The RL will advise the branch on NOR matters and offer assistance on in-game issues. During the provisional period, the RL must enter the game at least 1-2 times per week, attend at least 1 branch meeting per month and attend all officer meetings. (Game time and guild meetings are not required if the game is not Free to Play (F2P) and the RL is unable to obtain an account.) Assuming that the person selected by the HC to lead the branch accepts the job, an announcement of the new branch forming is made on all current realm bulletin boards, and on the *NOR home page.
___

 ]] },

	{ name = "New Branch Structure", text = [[

New Branch Structure:

A Branch is first formed as a Barony. It then grows into a County and finally a full-fledged Duchy. Until the new branch reaches Duchy status the Branch is considered provisional. Each month the HC is required to review the Branch status and determine if it is a functional part of *NOR/, should be expanded and continue to exist.

Guidelines (NOT GUARANTEES) for determining if a branch should be expanded:

1. County – At least 12 members, the Branch is at least one month old. All Counties should have one additional Baron(ess) for each six to eight (6-8) members with a minimum of one Baron(ess).

2. Duchy – At least 24 members, the Branch is at least two months old. All Duchies should have one additional Count(ess) for every three Barons with a minimum of one Count(ess).
___

 ]] },

	{ name = "Closed Realms", text = [[

Closed:

The Closed Realms are games that were previously active sanctioned games, but now no longer have any guild members playing.

Closing a Branch:

In order to be considered an active Realm, a branch must conform to the minimum Barony structure size and have an officer performing the role of Branch Leader. Once the branch has fallen below the Barony level or has no Branch Leader, it is time to consider closing or retiring it. Closing or Retiring is at the discretion of the HC.

Closed: When the HC is unable to maintain control of a realm and/or no one remains to play within the realm, the realm may close and disband the *NOR/ branch within that realm.

Retired: If the HC is able to maintain guild controls and some players still wish to carry the NOR Tag, a realm may be retired from active service and become a NOMAD realm.
___

 ]] },

	{ name = "Transfers, Resignation, Reinstatement", text = [[

Transfers:

Any member may transfer to another Branch of the guild. Inform the officers in both realms of your home game change so the guild roster can be updated.

Resignation:

The burden of ensuring continued membership rests solely with the member. Absent any concrete indication directly from the member, the Officers or HC may be forced to draw its own conclusions.

Members:

Members will typically be placed on MIA status unless overwhelming evidence to the contrary dictates otherwise.

Officers:

* It is the duty of Officers to make their intentions plain. *

1. An officer may resign their commission but remain in the guild (a voluntary demotion);
2. Explicitly communicating a resignation to another, higher ranked Officer or the guild at large by any means;
3. Detagging your Main on any Branch without prior notice and approval or “/ragequitting”. The Officer may have 24 hours to recant their action, but must suffer an automatic, mandatory demotion of one rank;
4. Refusing a re-tag subsequent to a detagging that was accidental or the result of administrative action, server maintenance, merger, migration or error on the part of the host server. Again, the Officer may have 24 hours (from first refusal) to recant their refusal and accept a retag or suffer demotion as in #2 above.

Reinstatement:

Former members may petition the High Council in writing via email or PM or in person at a High Council Meeting for re-admittance to NOR under any special circumstances, provisions, probation, demotions or conditions the HC deems fitting. (norhc@newoutriders.org)
___

 ]] },

	{ name = "Anti-Harassment Policy", text = [[

Anti-Harassment Policy:

The New OutRiders is committed to providing a positive, enjoyable, and respectful climate where everyone in the guild can engage in the games they appreciate with other members of the New OutRiders. It is the policy of the New OutRiders that all of its members shall not harass another guild member. Harassment includes the following:

Racial or ethnic slurs and other verbal, visual, or physical abuse relating to a person’s race, age, religion, color, national origin, ancestry, sex, sexual preference, gender identity, physical or mental handicap, or medical condition;

Any other behavior that interferes with an individual’s ability to engage in guild activities or subjectively creates an intimidating, hostile, or offensive gaming experience; Any other contact virtual or in-person which has the effect of creating an offensive, intimidating, degrading, adverse, or hostile environment; and Any forms of sexual harassment, including unwanted, unwelcome sexual advances; requests for sexual favors; verbal or physical conduct of a sexual nature; or delivery of unsolicited photos, pictures, memes, comics, videos, or other forms of media that are provocative, offensive, or sexual in nature.

The High Council advises all of its members to contact the High Council regarding any experiences of harassment that the guild member feels uncomfortable communicating with the person engaging in the behavior or who cannot achieve resolution with the individual. The High Council shall address any allegations of harassment by one of its members expeditiously and fairly with appropriate consequences including but not limited to the offending member receiving suspension or termination from the New OutRiders.
___

 ]] },

	{ name = "Misconduct", text = [[

Misconduct:

All conduct is evaluated solely on its face ingame or public means of communication between members. Any member, regardless of rank, may be charged with Misconduct by any officer in good standing at any time. The charges should fall under one of the following categories:

Malfeasance:

Any pattern of behavior the guild finds unacceptable. This may include, but not be limited to communications or actions that:

1. Violates the terms of Membership.
2. Constitutes malingering: feigning RL illness, infirmity or medical condition to avoid disciplinary action, shirk responsibilities or “excuse” inappropriate behavior.
3. Is intended to deceive or misrepresent, falsely gain access to the guild or advantage over another member.
4. Is known as: catfishing, trolling, lurking, bullying; or any other term that describes any communication deemed deceptive, inappropriate, hostile or detrimental.
5. Is known as: “griefing”, PK-ing (Player Killing), camping or otherwise flagrantly, openly and notoriously abusing an ingame mechanic or innate advantage for the sole purpose of inflicting unreasonable suffering beyond the scope of RPing or the spirit of the game upon another player.
6. Would be deemed despicable or illegal in RL, including “outing”, discrimination, harassment or threats.

Insubordination:

In matters of guild business only, we expect members to obey. Charges of insubordination may result from:

1. Refusing or failure to obey the lawful order of a superior;
2. Breach of peace, actions or speech designed to incite acrimony or disharmony;
3. Contempt, flagrantly, openly and notoriously denigrating, insulting or undermining the duly appointed authority of any Branch;
4. Sedition, mutiny or any action or speech designed to circumvent the chain of command, seize control, acting with authority they do not have or lure members away from NOR or obedience to this Charter;
___


 ]] },

	{ name = "Officer Misconduct", text = [[

Dereliction:

Applies to Officers only. Dereliction is defined as accepting an officer rank without fulfilling its attendant obligations or failing to abide by the Officer Mandate in a manner that is flagrant, open, or notorious.
An officer shall be considered derelict under any of the following conditions:

1. Failure to provide reasonable notice when anticipating an absence of seven (7) days or more.
Officers are expected to communicate anticipated absences to their Branch Leader or superior officer, to ensure continuity of branch operations.
2. Failure to fulfill the basic responsibilities of the Officer Mandate, including participation in guild activities, communication with branch leadership, and reasonable support of branch operations.
Persistent or habitual failure to perform these duties shall be considered dereliction and may result in retirement from officership.
3. Failure to log in or communicate for a period of thirty (30) consecutive days without prior notice or provision.
Such absence shall result in automatic retirement from officership.
4. Failure to log in for three (3) separate periods of thirty (30) days within a single calendar year, even with prior notice or provision.
Such cumulative absence demonstrates inability to reliably serve and may result in retirement from officership..

Conduct Unbecoming:

Applies to Officers only.

1. Any word or action deemed disruptive or counterproductive, creating a breach of peace or an atmosphere contrary to the harmony of a branch and its members.
2. Any form of “/ragequitting”.
3. Abuse of Power: using one’s rank or position to circumvent established rules or customs or to gain unfair advantage over the membership or other players.
___


 ]] },

	{ name = "Resolution of Misconduct", text = [[

Resolution of Misconduct:

Any member charged has two options available to them for the resolution of charges: Summary judgment by the charging Officer or a formal hearing before the High Council, but not both. Regardless of the member’s decision, the charging officer may have been required to render some intervention which will stand until upheld or overturned.

Summary Judgment:

Submit to the judgment of the officer and accept punishment, typically a reprimand, censure or demotion and that is the end of it.

Hearing:

The member may request a hearing before the High Council.

1. To be convened not more than thirty (30) days after the initial charges have been made.
2. Failure of the High Council to convene in that time will result in summary dismissal of all charges.
3. Failure to appear by either the presiding officer or the accused will result in a summary finding in favor of the attendee.
4. The High Council may endorse, modify or overturn the officer’s decision at its discretion.

All findings by the HC are final.

Notice:

All times and time sensitive conclusions are based on time of Notice to the appropriate parties. Notice may be given verbally via VOIP, by email on record or by PM on the forums or all three. Failure to receive or acknowledge notice may not be a defense against default. It is the responsibility of the individual member to ensure that contact information is current and up to date.
___

 ]] },

	{ name = "Penalties", text = [[

Penalties:

In cases of public records, only the fact of the reprimand, censure or demotion may be stated. Details of the underlying infraction may be withheld.

Reprimand: 
A reprimand will typically include a suspension from some guild privileges for a brief, set period of time.

Censure: 

A Public Reprimand; “name and shame”.

Demotion: 

The reduction may be temporary or have other conditions attached to it at the discretion of the presiding officer. A serious offense short of warranting expulsion from the guild. There will be a public record of the demotion, but perhaps not the underlying cause.

Expulsion: 

Only the most egregious violations should result in expulsion from the guild. This judgment may only be rendered by the HC. There will be a public record of this.

Specious or Retaliatory Charges:

This Charter nor these provisions are to be used as a bludgeon to exact retribution or mitigate personal squabbles or for any other frivolous purpose. Answer to the contrary at your peril. Members deemed to be doing so may be counter-charged with Malfeasance, Conduct Unbecoming or both by the High Council.
___

 ]] },

	{ name = "No Confidence", text = [[

No Confidence:

A call for a Vote of No Confidence is a declaration of a failure or defect in the leadership of a specific member of the High Council but otherwise conforms to the Misconduct section except where explicitly stated.

1. Any individual officer or group of officers in good standing may call for a vote of No Confidence at an Open or Closed High Council Meeting;
2. They must name the specific HC member and cite the charges as outlined under Misconduct.
3. Once called, the Meeting is suspended (not adjourned); thus:
a. Until resolved the HC may not vote on any matter save this one;
b. The remaining members of the HC will moderate the proceedings;
c. The remaining HC must empanel a tribunal composed of the Branch Leaders or the highest ranking officers available;
d. The tribunal and remaining HC must result in an odd number of members;
e. The tribunal must seat at least one officer for each current member of the HC – this includes the accused;
f. The tribunal will have the same powers as the HC on this matter only;
g. The remaining HC members and the tribunal must either dismiss or endorse the specific charges and recommend disciplinary action if appropriate;
h. Once resolved, the tribunal is dismissed.
4. The accused may avail themselves of the same options available to all members under Misconduct;
a. Summary Judgment by the tribunal; or
b. Hearing before the tribunal;
i. Hearing to occur at the earliest possible time for all parties;
ii. The tribunal may dismiss or endorse any or all charges;
iii. The tribunal may take disciplinary action against the accused if necessary.


All findings by the tribunal are final.
___
 ]] },

	{ name = "S&C I - Abbreviations", text = [[

Standards & Conventions:

Abbreviations & Terms

1. HC = High Council
2. NOR or *NOR/ = New OutRiders
3. “*” Shield(Swift) and “/” Sword(Ybarra)
4. CoC = Chain of Command
5. Main or NORname= Primary membership identity, the name by which you are known to NOR.
6. PnP = Postnomial Privileges
7. Realm or Branch = A game where NOR resides.
8. Duchy = A branch of NOR that has a Duke or Duchess as the presiding officer. There may be more than one Duchy on a single Realm.
9. Provisional = Temporary or conditional. In new Realms there may be provisional Baronies and Counties formed (called branches) that report directly to the HC.
10. Good Standing = Any member not charged with any of Misconduct in the previous six (6) month period or found guilty of charges of Misconduct in the previous twelve (12) months.
11. Public = For purposes of this document, meaning, available to the membership-at-large via any means of communication typically employed.
12. Tag or Jacket = This is whatever in-game guild tool distinguishes one as a member of NOR.
___

 ]] },

	{ name = "S&C II - Styles", text = [[

Signatures and Styles:

Guild correspondence between members or with members of other guilds, particularly of a formal nature should be signed, with Rank, Realm and Postnomial Privileges abbreviated following this format:

[Name]
*NOR/[Rank]-[Realm] [Postnomial Privileges]

Colors:

Navy and silver are the official colors of NOR. In heraldic terms, azure and argent.

Heraldry and Symbols:

The sword, shield and star is the accepted Coat of Arms and official symbol of NOR.

Font: 
Stonecross

Motto

“To have fun and help others do the same”
___

 ]] },

	{ name = "S&C III - Websites", text = [[

Web Sites:

1. The official website of NOR is www.newoutriders.org
2. Applies to all out of game assets publicly or privately available on the internet, including websites, blogs, social media pages, news feeds or any other media of a like nature.
3. Members, authors or contributors are hereby noticed that all references to “New OutRiders”, *NOR/, its images, names, ranks, likenesses and audio files are the property of “New OutRiders, Inc.” and may be used only with the permission of the guild.
4. Members must not replicate existing sites.
5. Members must not reproduce any documentation of an official nature, such as the Charter, but should link back to the main site, main documentation or whatever is the official venue for their publication;
6. All guildwide boards will be administered by the HC.
__

 ]] },

	{ name = "S&C IV - Conduct", text = [[

Naming:

All members of New OutRiders must choose their own official “Main” guild name that conforms to the following rules:

1. Must not violate the ToS or EULA of any host game, common decency or sense;
2. Each member is limited to one Main guild name to be listed on the roster;
3. A member may not join another guild using their Main guild name on the same server or in any place where other guilds are in direct competition with NOR for members;
4. Members are permitted to make alternate characters or screen names that may be guild tagged. All tagged alts should be listed or noted by their Main with whatever means is available by the ingame mechanics;
5. Alts may also be listed on the guild roster;
6. Each alternate character will obtain the approval an officer before being tagged;
7. Any alternate character that is inadvertently de-tagged from NOR may be re-tagged without delay;
8.Any changes to your Main name requires prior approval;

Hailing:

A greeting of “Hail *NOR/” should be given to your guildmates upon entering any host. Custom urges one include your main NOR name in the Hail if you are on an Alt.

Family- Friendly Communication:

*NOR/ is a family-friendly community, and our public text spaces, voice channels, and in-party communications are expected to remain suitable for a mixed-age audience. *NOR/ does not permit profanity, vulgar or obscene language, sexual language, slurs, and excessively graphic or crude language. This standard applies even if the language is common in a guild member’s everyday speech or where members are accustomed to hearing it elsewhere in their daily lives. Please keep all communication clean and respectful. When in doubt, err on the side of cleaner language.

Forums/Discord:

We encourage members to participate in all aspects of guild life, in particular the forums. This has been the primary means of communication between members for many years.

Grouping:

When grouping with fellow members of NOR or playing at-large in the game please take care to show courtesy and grace. When in doubt, one may fall back on virtually any lesson acquired in Kindergarten: Wait your turn, share, etc.
___


 ]] },

	{ name = "S&C VI - Events", text = [[

Recruiting:

It is the duty of all members of NOR to recruit. It is also the least savory or gives members the greatest difficulty. As a rule, you need not actively stump for NOR recruiting. As a member, you are an ambassador of NOR to other players by your presence and attitude. Usually, that is sufficient to generate interest. Do not actively “poach” players from other guilds; This does not apply if you are approached by the player. When in doubt, consult a superior;

Events:

It is considered good form and common courtesy to attend guild events. This applies to in-game events, GLUEs and HC meetings. These are not compulsory, unless mandated by your rank, but we encourage members to attend as many as they can reasonably manage.

Real World Topics:

Part of the ongoing harmony and unity in the guild comes from avoiding even the most ordinary real world topics. The idea is to provide an escape from the Real World, not bring its many issues and conflicts into the guild.

Privacy:

Member confidence should be jealously guarded and one should err on the side of caution. You may become privy to personal or confidential information about another member that is not appropriate for public disclosure. Disclose nothing that is not readily available to the public through normal play or use of the games we participate in.
___


 ]] },

	{ name = "Decree/Revisions", text = [[

Decree of Empowerment:

This the 3rd day of March in the year 2024, the High Council of the New OutRiders does ordain and approve this Charter which supersedes and replaces all other Charters or documents.

The 2024 High Council:

Garadian, Ryland, Tundrra, Yavool and Zyera.

Revision History:

Revised by the High Council August 11, 1997
Amended by the High Council December 14, 1997
Amended by the High Council May 10, 1998
Amended by the High Council July 19, 1998
Amended by the High Council April 9, 2000
Amended by the High Council August 13, 2000
Amended by the High Council August 13, 2000
Amended by the High Council March 4, 2001
Amended by the High Council June 1, 2003
Amended by the High Council June 15, 2003
Amended by the High Council April 25, 2004
Amended by the High Council May 02, 2004
Amended by the High Council May 23, 2004
Amended by the High Council September 12, 2004
Amended by the High Council October 19, 2005
Re-written and ratified by the High Council and Emeritus Lasarian April 2nd, 2017
Amended by the High Council March 12, 2023
Amended by the High Council April 23, 2023
Amended by the High Council March 10, 2024 (Updated Harassment Policy)
Amended by the High Council May 5th, 2024 (Realm Advisors)
Amended by the High Council April 12th, 2026 (Revised Ranks)
Amended by the High Council May 31st, 2026 (Revised Officer Ranks) v22
Amended by the High Council September 13th, 2026 (Revised Definitions & Admission Section Revisions) v23

The High Council:
March 2024 – 2026 Current: Lord Garadian, Lord Ryland, Lord Tundrra, Lord Yavool and Lady Zyera
___

 ]] },

        { name = "Extra Commands", text = [[

        Here are some extra text chat slash commands that you can use for shady "purposes".
        
        /steal : Toggle for Prevent Stealing Placed Items.
        /murder :  Toggle for Prevent Attacking Innocents.
        /stealandmurder : Toggle for both of the above.
        /autoloot : Toggles the autoloot setting in game settings.
        /banker : Summon/Dismiss your banking assistant.
        /merchant : Summon/Dismiss your merchant assistant.
        /armory : Summon/Dismiss your armory assistant.
        /smuggler : Summon/Dismiss your Fence.
        /decon : Summon/Dismiss your Deconstruction assistant.

___

 ]] }

}

    -- Create Buttons Dynamically (Inside Scrollable Menu)
    local buttonYOffset = 10
    for _, section in ipairs(sections) do
        local button = WINDOW_MANAGER:CreateControl("NORCharterButton_"..section.name, NORCharterWindow.menuScrollChild, CT_BUTTON)
        button:SetAnchor(TOPLEFT, NORCharterWindow.menuScrollChild, TOPLEFT, 20, buttonYOffset)
        button:SetDimensions(menuWidth - 10, 40)
	    button:SetText(section.name)
        button:SetMouseEnabled(true)

	
	-- Center text in buttons
	button:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 	button:SetVerticalAlignment(TEXT_ALIGN_CENTER)


        -- Styling: Background & Font Visibility
    button:SetFont("ESO_FWNTLG|18|soft-shadow-thick")
	button:SetNormalFontColor(0, 0.5, 1, 1)
	button:SetHandler("OnClicked", function()
    if activeButton then
        activeButton:SetNormalFontColor(0, 0.5, 1, 1) -- Reset previous button to blue
    end
    button:SetNormalFontColor(1, 0.84, 0, 1) -- Gold
    activeButton = button -- Update active button reference
    UpdateCharterText(section.text) -- Update the charter text
    PlaySound(SOUNDS.DEFAULT_CLICK) -- Play click sound
    end)
    buttonYOffset = buttonYOffset + 35 -- Space the buttons correctly
    end

    -- Set Scrollable Height Based on Button Count
    NORCharterWindow.menuScrollChild:SetDimensions(menuWidth - 20, buttonYOffset)

    -- Close Button
NORCharterWindow.closeBtn = WINDOW_MANAGER:CreateControl("NORCharterClose", NORCharterWindow, CT_BUTTON)
NORCharterWindow.closeBtn:SetAnchor(TOPLEFT, NORCharterWindow, TOPLEFT, -10, 10)
NORCharterWindow.closeBtn:SetDimensions(100, 30)
NORCharterWindow.closeBtn:SetText("EXIT")
NORCharterWindow.closeBtn:SetMouseEnabled(true)


-- Ensure font visibility
NORCharterWindow.closeBtn:SetFont("ZoFontWinH3")
NORCharterWindow.closeBtn:SetNormalFontColor(1, 0, 0, 1) -- Red text (RGB: 1, 0, 0)
PlaySound(SOUNDS.DEFAULT_CLICK)

-- Apply button textures
NORCharterWindow.closeBtn:SetNormalTexture("EsoUI/Art/Buttons/ESO_button_normal.dds")
NORCharterWindow.closeBtn:SetPressedTexture("EsoUI/Art/Buttons/ESO_button_pressed.dds")
NORCharterWindow.closeBtn:SetMouseOverTexture("EsoUI/Art/Buttons/ESO_button_mouseover.dds")

NORCharterWindow.closeBtn:SetHidden(false) -- Ensure visibility
NORCharterWindow.closeBtn:SetHandler("OnClicked", function()
    NORCharterWindow:SetHidden(true) -- Hide the window
    SetGameCameraUIMode(false) -- Return to normal camera mode
end)end


local function ShowGuildCharter()
    if NORCharterWindow:IsHidden() then
        NORCharterWindow:SetHidden(false)
        SetGameCameraUIMode(true) -- Activates mouse mode
    else
        NORCharterWindow:SetHidden(true)
        SetGameCameraUIMode(false) -- Returns to normal camera mode
    end
end

local function OnAddonLoaded(event, addonName)
    if addonName == "NORGuildTools" then
        CreateGuildCharterWindow()
        SLASH_COMMANDS["/nor"] = ShowGuildCharter
    end
end

SLASH_COMMANDS["/nor_help"] = function()
    d("=== NOR Guild Tools Commands ===")
    d("/nor : Opens a window for access to Guild Documents")
    d("/nor_trial  : Displays privately in text chat what and when our next trial is.")
    d("/nor_event  : Displays privately in text chat what and when our next event is.")
    d("/nor_holdings : Lists our guild holdings privately in text chat as clickable links for ease of travel.")
    d("/nor_jacket : Dons/Removes the Guild Tabard, showing or hiding your guild tag.")
    d("/nor_recruit : Populates the chat window with a standardized recruiting message you can send to a zone with the applicable guild advertisement link to apply.")
    d("/h : Populates the chat window with a Hail *NOR/!")
    d("/nor_help : Returns this slash command list, but to your chat window.")
    
end

EVENT_MANAGER:RegisterForEvent("NORCharter_Loaded", EVENT_ADD_ON_LOADED, OnAddonLoaded)
