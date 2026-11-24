-- Native LibAddonMenu author/footer links. No automatic messages or donations.
local A=CompanionSidekick
local EM=EVENT_MANAGER
local title="Companion Sidekick"
local website="https://www.esoui.com/downloads/info5072-CompanionSidekick.html"
local coffee="https://buymeacoffee.com/foulmouthxamazon"
local recipient="@FoulMouthxAmazon"
function A.TipGold()
    local sender=MAIL_SEND
    if IsInGamepadPreferredMode() and MAIL_MANAGER_GAMEPAD then sender=MAIL_MANAGER_GAMEPAD:GetSend()end
    if sender and sender.ComposeMailTo then
        sender:ComposeMailTo(recipient)
    else
        A.Say("To leave a gold tip, open Mail and address it to "..recipient..". Thank you!")
    end
end
function A.CreateJournalSupportFooter(parent,y,width)
    A.journalSupportFooters=A.journalSupportFooters or {}
    if A.journalSupportFooters[parent] then return A.journalSupportFooters[parent]end
    local WM=WINDOW_MANAGER
    local root=WM:CreateControl(nil,parent,CT_CONTROL)
    root:SetAnchor(TOPLEFT,parent,TOPLEFT,20,y);root:SetDimensions(width,22)
    local label=WM:CreateControl(nil,root,CT_LABEL)
    label:SetAnchor(TOPLEFT,root,TOPLEFT,0,0);label:SetDimensions(325,22)
    label:SetFont("ZoFontGameSmall");label:SetColor(.67,.67,.67,1);label:SetMaxLineCount(1)
    label:SetText("Author: FoulMouthxAmazon | v"..A.version)
    root.authorLabel=label;root.links={}
    local links={
        {"Website",330,80,function()RequestOpenUnsafeURL(website)end},
        {"Feedback",418,88,function()RequestOpenUnsafeURL(website.."#comments")end},
        {"Buy Me a Coffee",514,146,function()RequestOpenUnsafeURL(coffee)end},
        {"Tip ESO Gold",668,125,A.TipGold},
    }
    for _,entry in ipairs(links)do
        local button=WM:CreateControl(nil,root,CT_BUTTON)
        button:SetAnchor(TOPLEFT,root,TOPLEFT,entry[2],0);button:SetDimensions(entry[3],22)
        button:SetFont("ZoFontGameSmall");button:SetText(entry[1])
        button:SetNormalFontColor(.77,.75,.58,1);button:SetMouseOverFontColor(1,1,1,1)
        button:SetMouseEnabled(true);button:SetHandler("OnClicked",entry[4])
        root.links[#root.links+1]=button
    end
    A.journalSupportFooters[parent]=root
    return root
end
function A.RegisterAuthorInfo()
    local LAM=LibAddonMenu2
    if not LAM or A.authorPanel then return end
    A.authorPanel=LAM:RegisterAddonPanel(A.name.."AuthorOptions",{
        type="panel",name=title,displayName=title,author="FoulMouthxAmazon",
        version=A.version,website=website,feedback=website.."#comments",donation=coffee,
    })
    LAM:RegisterOptionControls(A.name.."AuthorOptions",{
        {type="description",text="Type /csidekick to use "..title..". Appearance and tracking controls are available in the addon window."},
        {type="header",name="Support the author"},
        {type="description",text="Enjoying "..title.."? Tips are optional. Thank you for using my addons, sharing ideas and helping squash bugs!"},
        {type="button",name="Tip ESO Gold",width="half",func=A.TipGold,
            tooltip="Opens a mail draft to "..recipient..". Add any amount you like, then send it yourself."},
        {type="button",name="Buy Me a Coffee",width="half",func=function()RequestOpenUnsafeURL(coffee)end},
    })
end
local function Loaded(_,name)
    if name~=A.name then return end
    EM:UnregisterForEvent(A.name.."AuthorInfo",EVENT_ADD_ON_LOADED)
    A.RegisterAuthorInfo()
end
EM:RegisterForEvent(A.name.."AuthorInfo",EVENT_ADD_ON_LOADED,Loaded)
