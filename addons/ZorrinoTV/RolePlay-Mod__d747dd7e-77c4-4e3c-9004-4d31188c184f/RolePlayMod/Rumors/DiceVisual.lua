if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- A rendered icosahedron: real mesh perspective, numbered faces, tumble, bounce and result-specific settling.
-- Playback is a local texture atlas; the die result is drawn and saved once by the game logic.
local V={duration=5000,landAt=4000};IHR_Runtime.Beta.DiceVisual=V
function V.Create(parent)
    local root=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL)
    V.gamepadControl=root
    -- The shared 640 px conversation canvas handles viewport/16:9 scaling.
    -- Keep the native-style NPC name above this dedicated content area.
    root:SetDimensions(604,370);root:SetAnchor(TOPLEFT,parent,TOPLEFT,18,44)
    local texture=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE)
    texture:SetDimensions(256,256);texture:SetAnchor(TOPLEFT,root,TOPLEFT,174,0);texture:SetMouseEnabled(false)
    local label=WINDOW_MANAGER:CreateControl(nil,root,CT_LABEL)
    label:SetFont('ZoFontGamepad22');label:SetDimensions(604,36);label:SetAnchor(TOPLEFT,root,TOPLEFT,0,234);label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local caption=WINDOW_MANAGER:CreateControl(nil,root,CT_LABEL)
    caption:SetFont('ZoFontGamepad18');caption:SetDimensions(604,44);caption:SetAnchor(TOPLEFT,root,TOPLEFT,0,274);caption:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local continue=WINDOW_MANAGER:CreateControl(nil,root,CT_BUTTON)
    continue:SetDimensions(260,42);continue:SetAnchor(TOPLEFT,root,TOPLEFT,172,322)
    continue:SetFont('ZoFontGamepad22');continue:SetText('Continuer')
    continue:SetNormalFontColor(.95,.86,.65,1);continue:SetMouseOverFontColor(1,1,1,1)
    continue:SetMouseEnabled(true);continue:SetClickSound('Click');continue:SetHidden(true)
    root.continueButton=continue
    root.texture=texture;root.resultLabel=label;root.caption=caption
    return root
end
local function cell(root,file,index,columns,rows)
    if root.file~=file then root.texture:SetTexture('RolePlayMod/Rumors/ui/dice/'..file..'.dds');root.file=file end
    local x,y=index%columns,math.floor(index/columns)
    root.texture:SetTextureCoords(x/columns,(x+1)/columns,y/rows,(y+1)/rows)
end
function V.Paint(root,elapsed,result)
    local clock=elapsed*5000/V.duration
    -- Keep the original atlas geometry, with a longer tumble and slower landing.
    if clock<3200 then elapsed=clock*1440/3200
    elseif clock<4000 then elapsed=1440+(clock-3200)*320/(4000-3200)
    else elapsed=1760 end
    if elapsed<1440 then cell(root,'throw',math.min(47,math.floor(elapsed/30)),8,8)
    elseif elapsed<1760 then
        local frame=(result.die-1)*8+math.min(7,math.floor((elapsed-1440)/40))
        cell(root,'settle-'..(math.floor(frame/64)+1),frame%64,8,8)
    else cell(root,'results',result.die-1,8,4) end
    root.resultLabel:SetText(clock>=4000 and ('D20 : '..result.die..' — '..(result.success and 'Réussite' or 'Échec')) or 'Lancer du d20…')
    root.continueButton:SetHidden(clock<5000)
    local caption='Difficulté : '..result.dd..' · Confiance : '..result.confidence..'/100'
    if result.inquiryDepth and result.inquiryDepth>1 then caption='Indice '..result.inquiryDepth..' · DD : '..result.baseDD..' +'..result.inquiryBonus..' = '..result.dd..' · Confiance : '..result.confidence..'/100' end
    root.caption:SetText(caption)
end
