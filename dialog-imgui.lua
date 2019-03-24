local ffi = require 'ffi'
local memory = require 'memory'
local imgui = require 'imgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local keys = require 'vkeys'

ffi.cdef[[
typedef void *PVOID;
typedef uint8_t BYTE;
typedef uint16_t WORD;
typedef uint32_t DWORD;
typedef char CHAR;
typedef CHAR *PCHAR;

typedef void(__thiscall *HOOK_DIALOG)(PVOID this, WORD wID, BYTE iStyle, PCHAR szCaption, PCHAR szText, PCHAR szButton1, PCHAR szButton2, bool bSend);
]]

local hook_addr, call_addr, detour_addr, inf_addr
local dialoginfo = {}
local input_dialog = imgui.ImBuffer(0xFFFF)
local list_dialog = 0
local dclist = false
local ignore = {}
local columns = {}
local maxwidth = -1
local maxheight = -1

local function GET_POINTER(cdata) return tonumber(ffi.cast('uintptr_t', ffi.cast('PVOID', cdata))) end

local style = imgui.GetStyle()
local colors = style.Colors
local clr = imgui.Col
local ImVec4 = imgui.ImVec4

local function apply_custom_style()
	imgui.SwitchContext()

	style.WindowRounding = 2.0
	style.WindowTitleAlign = imgui.ImVec2(0.5, 0.84)
	style.ChildWindowRounding = 2.0
	style.FrameRounding = 2.0
	style.ItemSpacing = imgui.ImVec2(5.0, 4.0)
	style.ScrollbarSize = 13.0
	style.ScrollbarRounding = 0
	style.GrabMinSize = 8.0
	style.GrabRounding = 1.0

	colors[clr.FrameBg]                = ImVec4(0.16, 0.29, 0.48, 0.54)
	colors[clr.FrameBgHovered]         = ImVec4(0.26, 0.59, 0.98, 0.40)
	colors[clr.FrameBgActive]          = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[clr.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
	colors[clr.TitleBgActive]          = ImVec4(0.16, 0.29, 0.48, 1.00)
	colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
	colors[clr.CheckMark]              = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.SliderGrab]             = ImVec4(0.24, 0.52, 0.88, 1.00)
	colors[clr.SliderGrabActive]       = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.Button]                 = ImVec4(0.26, 0.59, 0.98, 0.40)
	colors[clr.ButtonHovered]          = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.ButtonActive]           = ImVec4(0.06, 0.53, 0.98, 1.00)
	colors[clr.Header]                 = ImVec4(0.26, 0.59, 0.98, 0.31)
	colors[clr.HeaderHovered]          = ImVec4(0.26, 0.59, 0.98, 0.80)
	colors[clr.HeaderActive]           = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.Separator]              = colors[clr.Border]
	colors[clr.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
	colors[clr.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.ResizeGrip]             = ImVec4(0.26, 0.59, 0.98, 0.25)
	colors[clr.ResizeGripHovered]      = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[clr.ResizeGripActive]       = ImVec4(0.26, 0.59, 0.98, 0.95)
	colors[clr.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
	colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
	colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
	colors[clr.ChildWindowBg]          = ImVec4(1.00, 1.00, 1.00, 0.00)
	colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
	colors[clr.ComboBg]                = colors[clr.PopupBg]
	colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
	colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
	colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
	colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
	colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
	colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
	colors[clr.CloseButton]            = ImVec4(0.41, 0.41, 0.41, 0.50)
	colors[clr.CloseButtonHovered]     = ImVec4(0.98, 0.39, 0.36, 1.00)
	colors[clr.CloseButtonActive]      = ImVec4(0.98, 0.39, 0.36, 1.00)
	colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
	colors[clr.ModalWindowDarkening]   = ImVec4(0.80, 0.80, 0.80, 0.35)
end

local function returnFunc(h, i, bool)
	if bool then
		local p = memory.unprotect(h, 6)
		ffi.copy(ffi.cast('void*', h), i, 6)
		memory.protect(h, 6, p)
	else
		memory.setuint8(h, 0xE9, true)
		memory.setuint32(h + 1, i - h - 5, true)
		memory.setuint8(h + 5, 0xC3, true)
	end
end

local function enableDialog(bool)
	local memory = require 'memory'
	memory.setint32(sampGetDialogInfoPtr()+40, bool and 1 or 0, true)
	sampToggleCursor(bool)
end

local function cmdhook(this, id, style, caption, text, button1, button2, send)
	returnFunc(hook_addr, inf_addr, true)
	call_addr(this, id, style, caption, text, button1, button2, send)
	returnFunc(hook_addr, detour_addr, false)
	caption, text, button1 = ffi.string(caption), ffi.string(text), ffi.string(button1)
	if GET_POINTER(button2) ~= 0 then button2 = ffi.string(button2) else button2 = nil end
	if not caption:find('%S+') and not text:find('%S+') and not button1:find('%S+') then return end
	dialoginfo = { id, style, caption, text:gsub('\n\n', '\n \n'):gsub('\t\t', '\t'), button1, button2, 0 }
	while dialoginfo[4]:find('\t\t') do dialoginfo[4] = dialoginfo[4]:gsub('\t\t', '\t') end
	dclist = false
	maxwidth, maxheight = -1, -1
	imgui.Process = true
	input_dialog.v = ''
	list_dialog = 0
	enableDialog(false)
end

local function imguiTextColoredRGB(text)
	local style = imgui.GetStyle()
	local colors = style.Colors
	local ImVec4 = imgui.ImVec4

	local explode_argb = function(argb)
		local a = bit.band(bit.rshift(argb, 24), 0xFF)
		local r = bit.band(bit.rshift(argb, 16), 0xFF)
		local g = bit.band(bit.rshift(argb, 8), 0xFF)
		local b = bit.band(argb, 0xFF)
		return a, r, g, b
	end

	local getcolor = function(color)
		if color:sub(1, 6):upper() == 'SSSSSS' then
			local r, g, b = colors[1].x, colors[1].y, colors[1].z
			local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
			return ImVec4(r, g, b, a / 255)
		end
		local color = type(color) == 'string' and tonumber(color, 16) or color
		if type(color) ~= 'number' then return end
		local r, g, b, a = explode_argb(color)
		return imgui.ImColor(r, g, b, a):GetVec4()
	end

	local render_text = function(text_)
		for w in text_:gmatch('[^\r\n]+') do
			local text, colors_, m = {}, {}, 1
			w = w:gsub('{(......)}', '{%1FF}')
			while w:find('{........}') do
				local n, k = w:find('{........}')
				local color = getcolor(w:sub(n + 1, k - 1))
				if color then
					text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
					colors_[#colors_ + 1] = color
					m = n
				end
				w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
			end
			if text[0] then
				for i = 0, #text do
					imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
					imgui.SameLine(nil, 0)
				end
				imgui.NewLine()
			else imgui.Text(u8(w)) end
		end
	end

	render_text(text:gsub('\n\n', '\n \n'))
end

local function sampSetCurrentDialogListItem(number)
	number = tonumber(number)
	local list = getStructElement(sampGetDialogInfoPtr(), 0x20, 4)
	return setStructElement(list, 0x143 --[[m_nSelected]], 4, number or 0)
end

local function render_selectable(i)
	local cursor = imgui.GetCursorScreenPos()
	local item, item_hover, item_active = imgui.ColorConvertFloat4ToU32(colors[clr.FrameBg]),
		imgui.ColorConvertFloat4ToU32(colors[clr.FrameBgHovered]),
		imgui.ColorConvertFloat4ToU32(colors[clr.FrameBgActive])
	if list_dialog ~= i then item = 0x0 end
	local current = item
	if imgui.InvisibleButton('##'..i, imgui.ImVec2(imgui.GetWindowWidth() - 18, imgui.GetFontSize() + 5)) then
		list_dialog = i
		current = item_active
	end
	if imgui.IsMouseHoveringRect(cursor, imgui.ImVec2(cursor.x + imgui.GetWindowWidth() - 18, cursor.y + imgui.GetFontSize() + 5)) then
		current = imgui.IsMouseDown(0) and item_active or item_hover
		if imgui.IsMouseDoubleClicked(0) then
			dclist = true
		end
	end
	imgui.GetWindowDrawList():AddRectFilled(cursor, imgui.ImVec2(cursor.x + imgui.GetWindowWidth() - 18, cursor.y + imgui.GetFontSize() + 5), 
		current, 2)
end

local function render_button(i, text)
	local cursor = imgui.GetCursorScreenPos()
	local item, item_hover, item_active = imgui.ColorConvertFloat4ToU32(colors[clr.Button]),
		imgui.ColorConvertFloat4ToU32(colors[clr.ButtonHovered]),
		imgui.ColorConvertFloat4ToU32(colors[clr.ButtonActive])
	local ntext = text:gsub('{%x%x%x%x%x%x}', '')
	local current = item
	local size_text = imgui.CalcTextSize(u8(ntext)).x
	local c = imgui.GetCursorPos()
	local res = imgui.InvisibleButton('##'..i, imgui.ImVec2(size_text + 8, imgui.GetFontSize() + 5))
	if res then current = item_active end
	if imgui.IsMouseHoveringRect(cursor, imgui.ImVec2(cursor.x + size_text + 8, cursor.y + imgui.GetFontSize() + 5)) then
		current = imgui.IsMouseDown(0) and item_active or item_hover
	end
	imgui.GetWindowDrawList():AddRectFilled(cursor, imgui.ImVec2(cursor.x + size_text + 8, cursor.y + imgui.GetFontSize() + 5), 
		current, 2)
	c.x = c.x + 4
	c.y = c.y + 2
	imgui.SetCursorPos(c)
	imguiTextColoredRGB(text)
	return res
end

local function run_button(bool)
	enableDialog(true)
	sampSetCurrentDialogEditboxText(u8:decode(input_dialog.v))
	sampSetCurrentDialogListItem(list_dialog)
	sampCloseCurrentDialogWithButton(bool and 1 or 0)
	imgui.Process = false
end

local function isKeyCheckAvailable()
	if not isSampfuncsLoaded() then
		return not isPauseMenuActive()
	end
	local result = not isSampfuncsConsoleActive() and not isPauseMenuActive()
	if isSampLoaded() and isSampAvailable() then
		result = result and not sampIsChatInputActive() and not sampIsDialogActive()
	end
	return result
end
  

function main()
	if not isSampLoaded() then return end

	local callback = ffi.cast('HOOK_DIALOG', cmdhook)
	detour_addr = GET_POINTER(callback)

	local samp = getModuleHandle('samp.dll')
	hook_addr = samp + 0x6B9C0
	inf_addr = ffi.new('BYTE[6]')
	ffi.copy(inf_addr, ffi.cast('void*', hook_addr), 6)
	call_addr = ffi.cast('HOOK_DIALOG', hook_addr)
	returnFunc(hook_addr, detour_addr, false)
	wait(-1)
end

function onScriptTerminate(scr)
	if scr == script.this then
		returnFunc(hook_addr, inf_addr, true)
	end
end

local fontChanged = false
function imgui.BeforeDrawFrame()
	if not fontChanged then
		fontChanged = true
		local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
		imgui.GetIO().Fonts:Clear()
		imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\arialbd.ttf', math.floor(getScreenResolution() / 113), nil, glyph_ranges)
		imgui.RebuildFonts()
	end
end

apply_custom_style()
function imgui.OnDrawFrame()
	-- size
	local x, y = getScreenResolution()
	if maxwidth == -1 and maxheight == -1 then
		local title = dialoginfo[3]:gsub('{%x%x%x%x%x%x}', '')
		maxwidth = imgui.CalcTextSize(u8(title)).x
		if dialoginfo[2] == 4 or dialoginfo[2] == 5 then
			local i = 0
			for w in dialoginfo[4]:gmatch('[^\r\n]+') do
				i = i + 1
				local l = 0
				w = w:gsub('{%x%x%x%x%x%x}', '')
				local size = imgui.CalcTextSize(u8(w))
				for m in w:gmatch('[^\t]+') do
					l = l + 1
					if not columns[l] then columns[l] = 0 end
					local size = imgui.CalcTextSize(u8(m))
					if columns[l] < size.x then columns[l] = size.x + 20 end
				end
				maxheight = maxheight + size.y + style.ItemSpacing.y
			end
			for i = 1, #columns do maxwidth = maxwidth + columns[i] end
			maxheight = maxheight + 4 * i + 12
		else
			local i = 0
			for w in dialoginfo[4]:gmatch('[^\r\n]+') do
				w = w:gsub('{%x%x%x%x%x%x}', '')
				i = i + 1
				local size = imgui.CalcTextSize(u8(w))
				if maxwidth < size.x then maxwidth = size.x end
				maxheight = maxheight + size.y + style.ItemSpacing.y
			end
			if dialoginfo[2] == 1 or dialoginfo[2] == 3 then
				maxheight = maxheight + imgui.GetFontSize() + 10
			elseif dialoginfo[2] == 2 then
				maxheight = maxheight + 4 * i + 12
			end
		end
		maxheight = maxheight + style.ItemSpacing.y + ( imgui.GetFontSize() + 5 ) * 3 + 10
		maxwidth = maxwidth + 22
		if maxwidth < 350 then maxwidth = 350 elseif maxwidth > x / 1.5 then maxwidth = math.floor(x / 1.5) end
		if maxheight < 150 then maxheight = 150 elseif maxheight > y / 1.5 then maxheight = math.floor(y / 1.5) end
	end

	imgui.SetNextWindowPos(imgui.ImVec2(x/2, y/2), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(maxwidth, maxheight), imgui.Cond.Appearing)
	imgui.Begin(u8(dialoginfo[3]), nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar --[[+ imgui.WindowFlags.HorizontalScrollbar]])
	local sw, sy = imgui.GetWindowWidth(), imgui.GetWindowHeight()
	
	-- header
	local cursor = imgui.GetCursorScreenPos()
	cursor.x = cursor.x - 4
	cursor.y = cursor.y - 3
	imgui.GetWindowDrawList():AddRectFilled(cursor, imgui.ImVec2(cursor.x + sw - 9, cursor.y + imgui.GetFontSize() + 5), 
		imgui.ColorConvertFloat4ToU32(colors[clr.TitleBgActive]))
	imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX() + 2, imgui.GetCursorPosY() - 1))
	imguiTextColoredRGB(dialoginfo[3])
	imgui.SetCursorPosY(imgui.GetCursorPosY() + 5)
	imgui.Separator()
	imgui.SetCursorPosY(imgui.GetCursorPosY() + 5)
	if dialoginfo[2] == 2 then
		local i = -1
		for w in dialoginfo[4]:gmatch('[^\r\n]+') do
			i = i + 1
			local cursor_item = imgui.GetCursorPos()
			render_selectable(i)
			imgui.SetCursorPosY(cursor_item.y + 2)
			imgui.SetCursorPosX(cursor_item.x + 2)
			imguiTextColoredRGB(w)
			imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
		end
		dialoginfo[8] = i
	elseif dialoginfo[2] == 4 or dialoginfo[2] == 5 then
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 5)
		local info = dialoginfo[4]:gsub('\t\t', '\t \t')
		local a = info:match('^(.-)\n')
		local _, c = a:gsub('\t', '')
		if dialoginfo[2] == 5 then
			info = info:match('^.-\n(.*)')
			imgui.Columns(c + 1)
			for i = 1, #columns do imgui.SetColumnWidth(i - 1, columns[i]) end
			for w in a:gmatch('[^\t]+') do
				imguiTextColoredRGB(w)
				imgui.NextColumn()
			end
			imgui.Columns(1)
			imgui.Separator()
		end
		local cursor = imgui.GetCursorPos()
		local i = -1
		for w in info:gmatch('[^\r\n]+') do
			i = i + 1
			local cursor_item = imgui.GetCursorPos()
			render_selectable(i)
			imgui.SetCursorPosY(cursor_item.y + imgui.GetFontSize() + 10)
		end
		imgui.Columns(c + 1)
		imgui.SetCursorPos(cursor)
		for w in info:gmatch('[^\r\n]+') do
			local i = 0
			imgui.SetCursorPosX(cursor.x + 2)
			for l in w:gmatch('[^\t]+') do
				i = i + 1
				imguiTextColoredRGB(l)
				imgui.NextColumn()
				imgui.SetCursorPosY(cursor.y)
			end
			while i <= c do imgui.NextColumn(); i = i + 1 end
			cursor.y = cursor.y + imgui.GetFontSize() + 10
			imgui.SetCursorPosY(cursor.y)
		end
		imgui.Columns(1)
	else imguiTextColoredRGB(dialoginfo[4]) end
	if dialoginfo[2] == 1 or dialoginfo[2] == 3 then
		imgui.PushItemWidth(sw - 15)
		imgui.InputText('##input', input_dialog, dialoginfo[2] == 3 and imgui.InputTextFlags.Password or 0)
		imgui.PopItemWidth()
	end

	-- button
	if sy == 150 then imgui.SetCursorPosY(sy - 30) end
	local b1, b2 = dialoginfo[5]:gsub('{%x%x%x%x%x%x}', ''), dialoginfo[6]:gsub('{%x%x%x%x%x%x}', '')
	local sb = imgui.CalcTextSize(u8(b1)).x
	if dialoginfo[6] and #dialoginfo[6] > 0 then
		sb = sb + imgui.CalcTextSize('  ' .. u8(b2)).x
	end
	imgui.SetCursorPos(imgui.ImVec2((sw - sb) / 2 - 4, imgui.GetCursorPosY() + 5))
	if render_button(999, dialoginfo[5]) or dclist then run_button(true) end
	if dialoginfo[6] and #dialoginfo[6] > 0 then 
		imgui.SameLine(nil, 7)
		imgui.SetCursorPosY(imgui.GetCursorPosY() - 2)
		if render_button(998, dialoginfo[6]) then run_button(false) end
	end
	imgui.End()
end

function onWindowMessage(msg, wparam, lparam)
	if msg == 0x100 or msg == 0x101 then
		if wparam == keys.VK_ESCAPE and imgui.Process and isKeyCheckAvailable() then
			consumeWindowMessage(true, false)
			if msg == 0x101 then run_button(false) end
		elseif wparam == keys.VK_RETURN and imgui.Process and isKeyCheckAvailable() then
			consumeWindowMessage(true, false)
			if msg == 0x101 then run_button(true) end
		elseif ( wparam == keys.VK_UP or keys.VK_DOWN ) and imgui.Process and isKeyCheckAvailable() and ( dialoginfo[2] == 2 or dialoginfo[2] == 4 or dialoginfo[2] == 5 ) then
			if msg == 0x100 then
				consumeWindowMessage(true, false)
				if wparam == keys.VK_DOWN then
					if list_dialog ~= dialoginfo[8] then
						list_dialog = list_dialog + 1
					--[[else list_dialog = 0]] end
				elseif wparam == keys.VK_UP then
					if list_dialog ~= 0 then
						list_dialog = list_dialog - 1
					--[[else list_dialog = dialoginfo[8]] end
				end
			end
		end

	-- попытка фикса
	elseif msg == 0x102 then
		if wparam == keys.VK_SHIFT and isKeyCheckAvailable() then
			consumeWindowMessage(true, false)
		end
	end
end
