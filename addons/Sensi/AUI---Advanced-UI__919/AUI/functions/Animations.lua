AUI_ANIMATION_VERTICAL = 101
AUI_ANIMATION_HORIZONTAL = 102
AUI_ANIMATION_ECLIPSE = 103
AUI_ANIMATION_POP = 104

AUI_ANIMATION_MODE_FORWARD = 1000
AUI_ANIMATION_MODE_REVERSE_FORWARD = 1001
AUI_ANIMATION_MODE_BACKWARD = 1002
AUI_ANIMATION_MODE_REVERSE_BACKWARD = 1003

AUI.Animations = {}

local tasks = {}
local animationList = {}
local lastAnimations = {}
local taskCount = {}
local animationCount = {}
local animationTaskCount = 0

local function CreateNewAnimationControl(_virtualControl, _parentName, _parent)
	if not animationCount[_parentName] then
		animationCount[_parentName] = 0
	end
	
	if not animationList[_parentName] then
		animationList[_parentName] = {}
	end	
	
	local controlId = animationCount[_parentName]
	local control = animationList[_parentName][controlId]

	if not control then
		control = CreateControlFromVirtual(_parentName .. "_Animation", _parent, _virtualControl, controlId)
		animationList[_parentName][controlId] = control
	end	
	
	animationCount[_parentName] = animationCount[_parentName] + 1
	
	return control
end

local function GetAnimationControl(_virtualControl, _parent, _isVirtual)
	local parentName = _parent:GetName()
	local control = nil
	
	if parentName then
		local animations = animationList[parentName]
		if animations then
			for _, _control in pairs(animations) do
				if not _control.animation.isPlaying then
					control = _control
					break
				end
			end
		end
		
		if not control and _isVirtual then	
			control = CreateNewAnimationControl(_virtualControl, parentName, _parent, _isVirtual)
			control.animation = {}
			control.animation.name = control:GetName()	
		end	

		control.parentName = parentName	
		control.animation.parent = _parent	
		control.animation.isPlaying = true
		control.animation.ms = GetGameTimeMilliseconds()		
		control.animation.parentWidth = _parent:GetWidth()
		control.animation.parentHeight = _parent:GetHeight()
	end
	
	return control
end

local function StopAnimation(_control)
	if _control and _control.animation and _control.animation.name then
		_control:SetAlpha(0)
		_control.animation.isPlaying = false
		EVENT_MANAGER:UnregisterForUpdate("AUI_UPDATE_" .. _control.animation.name)
	end
end

local function StartAnimation(_virtualControl, _parent, _duration, _animationType, _animationMode, _alignment, _startX, _startY, _endX, _endY, _isVirtual, _callback)
	local control = GetAnimationControl(_virtualControl, _parent, _isVirtual)		

	if control and control.animation then	
		local offsetX = 0	          
		local offsetY = 0			
		local startX = _startX or 0	          
		local startY = _startY or 0	
		local endX = _endX or 0	          
		local endY = _endY or 0			
		local alpha = _startAlpha or 0
		local point = TOP
		local rPoint = TOP		
		
		if _alignment == AUI_ALIGNMENT_CENTER then
			if _animationMode == AUI_ANIMATION_MODE_FORWARD or _animationMode == AUI_ANIMATION_MODE_BACKWARD then
				startX = control.animation.parentWidth / 2
				startY = control.animation.parentHeight / 2
			elseif _animationMode == AUI_ANIMATION_MODE_REVERSE_FORWARD or _animationMode == AUI_ANIMATION_MODE_REVERSE_BACKWARD then				
				endX = control.animation.parentWidth / 2 + endX
				endY = control.animation.parentHeight / 2 + endY		
			end				
		elseif _alignment == AUI_ALIGNMENT_LEFT then
			startX = 0	
		elseif _alignment == AUI_ALIGNMENT_RIGHT then
			startX = control.animation.parentWidth		
		elseif _alignment == AUI_ALIGNMENT_TOP then
			startY = 0	
		elseif _alignment == AUI_ALIGNMENT_BOTTOM then
			startY = control.animation.parentHeight / 2				
		elseif _alignment == AUI_ALIGNMENT_TOPLEFT then
			startX = 0	
			startY = 0
		elseif _alignment == AUI_ALIGNMENT_TOPRIGHT then
			startX = control.animation.parentWidth
			startY = 0			
		elseif _alignment == AUI_ALIGNMENT_BOTTOMLEFT then
			startX = 0
			startY =  control.animation.parentHeight
		elseif _alignment == AUI_ALIGNMENT_BOTTOMRIGHT then
			startX = control.animation.parentWidth
			startY =  control.animation.parentHeight
		end	
		
		if _animationType == AUI_ANIMATION_POP then
			point = TOPLEFT
			rPoint = TOPLEFT	
			offsetX = math.random(control.animation.parentWidth)
			offsetY = math.random(control.animation.parentHeight)					
		end	
			
		EVENT_MANAGER:RegisterForUpdate("AUI_UPDATE_" .. control.animation.name, 0,
		function()
			local taskCount = taskCount[control.parentName]
		
			if taskCount and taskCount > 0 then
				_duration = (_duration - (taskCount * 6)) 
			end
			
			if _duration <= 1000 then
				_duration = 500
			end

			local ms = GetGameTimeMilliseconds()
			local remaining = (ms - control.animation.ms) / _duration		
			local parentWidth = control.animation.parentWidth - (startX + endX)
			local parentHeight = control.animation.parentHeight - (startY + endY)
	
			if _animationMode == AUI_ANIMATION_MODE_FORWARD then
				point = TOPLEFT
				rPoint = TOPLEFT		
		
				if _animationType == AUI_ANIMATION_ECLIPSE then
					offsetX = (-parentWidth * ((2 * (remaining * remaining)) - (2 * remaining))) + startX
					offsetY = ((parentHeight * remaining) + startY)
				
					point = TOPLEFT
					rPoint = TOPLEFT					
				elseif _animationType == AUI_ANIMATION_VERTICAL then
					offsetY = (parentHeight * remaining + startY)
				
					point = TOP
					rPoint = TOP					
				elseif _animationType == AUI_ANIMATION_HORIZONTAL then
					offsetX = (parentWidth * remaining) + startX
				
					point = LEFT
					rPoint = LEFT						
				end					
			elseif _animationMode == AUI_ANIMATION_MODE_REVERSE_FORWARD then
				if _animationType == AUI_ANIMATION_ECLIPSE then
					offsetX = (parentWidth * ((2 * (remaining * remaining)) - (2 * remaining))) - startX
					offsetY = (parentHeight * remaining - startY)
				
					point = TOP
					rPoint = TOP					
				elseif _animationType == AUI_ANIMATION_VERTICAL then
					offsetY = (parentHeight * remaining) + startY
				
					point = TOP
					rPoint = TOP					
				elseif _animationType == AUI_ANIMATION_HORIZONTAL then
					offsetX = (parentWidth * remaining) + startX	
				
					point = LEFT
					rPoint = LEFT					
				end				
			elseif _animationMode == AUI_ANIMATION_MODE_BACKWARD then
				if _animationType == AUI_ANIMATION_ECLIPSE then
					offsetX = (-parentWidth * ((2 * (remaining * remaining)) - (2 * remaining))) - startX
					offsetY = (-parentHeight * remaining) - startY

					point = BOTTOMLEFT
					rPoint = BOTTOMLEFT
				elseif _animationType == AUI_ANIMATION_VERTICAL then
					offsetY = (-parentHeight * remaining) - startY
			
					point = BOTTOM
					rPoint = BOTTOM	
				elseif _animationType == AUI_ANIMATION_HORIZONTAL then				
					offsetX = -(parentWidth * remaining) - startX		
				
					point = RIGHT
					rPoint = RIGHT					
				end					
			elseif _animationMode == AUI_ANIMATION_MODE_REVERSE_BACKWARD then
				if _animationType == AUI_ANIMATION_ECLIPSE then
					offsetX = (parentWidth * ((2 * (remaining * remaining)) - (2 * remaining))) - startX
					offsetY = (-parentHeight * remaining) - startY
			
					point = BOTTOM
					rPoint = BOTTOM	
				elseif _animationType == AUI_ANIMATION_VERTICAL then 
					offsetY = (-parentHeight * remaining) - startY
			
					point = BOTTOM
					rPoint = BOTTOM	
				elseif _animationType == AUI_ANIMATION_HORIZONTAL then
					offsetX = (-parentWidth * remaining) - startX
				
					point = RIGHT
					rPoint = RIGHT					
				end			
			end

			if _callback then
				_callback(control)
			end	
			
			if remaining > 0 then
				alpha = -((remaining * remaining) - remaining) * 4
			end			
			
			if alpha <= 0 then
				StopAnimation(control)	
			end

			control:ClearAnchors()
			control:SetAnchor(point, _parent, rPoint, offsetX, offsetY)
			control:SetAlpha(alpha)
		end)
		
		return control.animation
	end
	
	return nil
end

local function IsAnimationApproved(_taskData)
	local lastAnimation = lastAnimations[_taskData.panelName]	
	if lastAnimation then
		local currentMS = GetGameTimeMilliseconds() - lastAnimation.ms	
		local durationMS = _taskData.duration / 1000
		local interval = (durationMS * (_taskData.distance + durationMS))

		if currentMS >= interval then
			return true	
		end
	else
		return true
	end
	
	return false
end

local function ExecuteTasks()
	if animationTaskCount > 0 then
		EVENT_MANAGER:UnregisterForUpdate("AUI_UPDATE_SCROLLING_TEXT_TASKS")	

		for taskId, taskData in pairs(tasks) do		
			local panelName = taskData.parent:GetName()	
			if panelName then	
				if IsAnimationApproved(taskData) then
					lastAnimations[panelName] = StartAnimation(taskData.virtualControl, taskData.parent, taskData.duration, taskData.animationType, taskData.animationMode, taskData.alignment, taskData.startX, taskData.startY, taskData.endX, taskData.endY, taskData.isVirtual, taskData.callback)
					
					tasks[taskId] = nil	
					animationTaskCount = animationTaskCount - 1
					
					if taskCount[panelName] then
						taskCount[panelName] = taskCount[panelName] - 1
					end
				end
			end
		end
		
		EVENT_MANAGER:RegisterForUpdate("AUI_UPDATE_SCROLLING_TEXT_TASKS", 50, ExecuteTasks)
	end
end

function AUI.Animations.RemoveFrom(_panel)
	if not _panel then
		return
	end

	local panelName = _panel:GetName()
	
	for taskId, taskData in pairs(tasks) do	
		local taskDataParentName = taskData.parent:GetName()
		if taskDataParentName == panelName then
			tasks[taskId] = nil
		end
	end
	
	if taskCount[panelName] then
		taskCount[panelName] = 0
	end
	
	lastAnimations[panelName] = nil
	
	if animationList[panelName] then
		for id, control in pairs(animationList[panelName]) do	
			control:SetAlpha(0)
			StopAnimation(control)	
		end
	end
end

function AUI.Animations.IsPlaying(_control)
	if _control and _control.animation then
		return _control.animation.isPlaying
	end
end

function AUI.Animations.StopAnimation(_control)
	if _control and _control.animation then
		StopAnimation(_control)	
	end
end

function AUI.Animations.StartAnimation(_virtualControl, _parent, _duration, _animationType, _animationMode, _alignment, _distance, _startX, _startY, _endX, _endY, _isVirtual, _callback)
	if not _virtualControl or not _parent or not _duration or not _animationType or not _animationMode then
		return
	end
	
	if _isVirtual then
		local panelName = _parent:GetName()
	
		if not taskCount[panelName] then
			taskCount[panelName] = 0
		end
		
		if not _distance then
			_distance = 0
		end
	
		table.insert(tasks, {virtualControl = _virtualControl, panelName = panelName, parent = _parent, duration = _duration or 1, animationType = _animationType, animationMode = _animationMode, alignment = _alignment, distance = _distance, isVirtual = _isVirtual, startX = _startX, startY = _startY, endX = _endX, _endY = _endY, callback = _callback})
		taskCount[panelName] = taskCount[panelName] + 1
		animationTaskCount = animationTaskCount + 1
	else
		StartAnimation(_virtualControl, _parent, _duration, _animationType, _animationMode, _alignment, _startX, _startY, _endX, _endY, _isVirtual, _callback)
	end
end

EVENT_MANAGER:RegisterForUpdate("AUI_UPDATE_SCROLLING_TEXT_TASKS", 50, ExecuteTasks)