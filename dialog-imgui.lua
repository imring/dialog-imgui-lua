script_author('imring')
script_version_number(2.0)
local ffi = require 'ffi'
local memory = require 'memory'
local imgui = require 'imgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local keys = require 'vkeys'
local inicfg = require 'inicfg'

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
local dialogs = {}
local is_focused = false
local original_shift

local settings = false
local dialog_hider = imgui.ImBool(false)
local save = imgui.ImBool(false)
local fontsize = imgui.ImInt(0)
local fontname = imgui.ImBuffer(256)

local ini = inicfg.load(nil, '..\\dialogimgui.ini')

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

local function is_dark_vec4(vec4)
	local a = vec4.x <= 0.5
	local b = vec4.y <= 0.5
	local c = vec4.z <= 0.5
	return ( a and b ) or ( b and c ) or ( a and c )
end

local function reload_ini()
	-- frame
	local frame = imgui.ImColor(ini.colors.frame):GetVec4()
	local framehover, frameactive = imgui.ImColor(ini.colors.frame):GetVec4(), imgui.ImColor(ini.colors.frame):GetVec4()
	if is_dark_vec4(frame) then
		framehover.x = framehover.x + 0.15
		framehover.y = framehover.y + 0.15
		framehover.z = framehover.z + 0.15
		frameactive.x = frameactive.x + 0.2
		frameactive.y = frameactive.y + 0.2
		frameactive.z = frameactive.z + 0.2
	else
		framehover.x = framehover.x - 0.15
		framehover.y = framehover.y - 0.15
		framehover.z = framehover.z - 0.15
		frameactive.x = frameactive.x - 0.2
		frameactive.y = frameactive.y - 0.2
		frameactive.z = frameactive.z - 0.2
	end

	-- button
	local button = imgui.ImColor(ini.colors.button):GetVec4()
	local buttonhover, buttonactive = imgui.ImColor(ini.colors.button):GetVec4(), imgui.ImColor(ini.colors.button):GetVec4()
	if is_dark_vec4(button) then
		buttonhover.x = buttonhover.x + 0.15
		buttonhover.y = buttonhover.y + 0.15
		buttonhover.z = buttonhover.z + 0.15
		buttonactive.x = buttonactive.x + 0.2
		buttonactive.y = buttonactive.y + 0.2
		buttonactive.z = buttonactive.z + 0.2
	else
		buttonhover.x = buttonhover.x - 0.15
		buttonhover.y = buttonhover.y - 0.15
		buttonhover.z = buttonhover.z - 0.15
		buttonactive.x = buttonactive.x - 0.2
		buttonactive.y = buttonactive.y - 0.2
		buttonactive.z = buttonactive.z - 0.2
	end

	-- title
	local title = imgui.ImColor(ini.colors.title):GetVec4()

	-- background
	local bg = imgui.ImColor(ini.colors.background):GetVec4()

	-- checkmark
	local check = imgui.ImColor(ini.colors.frame):GetVec4()
	check.x = check.x + 0.3
	check.y = check.y + 0.3
	check.z = check.z + 0.3

	-- edit
	colors[clr.FrameBg]                = frame
	colors[clr.FrameBgHovered]         = framehover
	colors[clr.FrameBgActive]          = frameactive
	colors[clr.TitleBgActive]          = title
	colors[clr.Button]                 = button
	colors[clr.ButtonHovered]          = buttonhover
	colors[clr.ButtonActive]           = buttonactive
	colors[clr.WindowBg]               = bg
	colors[clr.ResizeGrip]             = frame
	colors[clr.ResizeGripHovered]      = framehover
	colors[clr.ResizeGripActive]       = frameactive
	colors[clr.ScrollbarGrab]          = frame
	colors[clr.ScrollbarGrabHovered]   = framehover
	colors[clr.ScrollbarGrabActive]    = frameactive
	colors[clr.CheckMark]              = check

	dialog_hider.v = ini.main.hider
	save.v = ini.main.save
	fontsize.v = ini.font.size
	fontname.v = u8(ini.font.name)
end

local function save_ini()
	ini.colors.frame = imgui.ColorConvertFloat4ToU32(colors[clr.FrameBg])
	ini.colors.button = imgui.ColorConvertFloat4ToU32(colors[clr.Button])
	ini.colors.title = imgui.ColorConvertFloat4ToU32(colors[clr.TitleBgActive])
	ini.colors.background = imgui.ColorConvertFloat4ToU32(colors[clr.WindowBg])
	ini.main.hider = dialog_hider.v
	ini.main.save = save.v
	ini.font.size = fontsize.v
	ini.font.name = u8:decode(fontname.v)

	inicfg.save(ini, '..\\dialogimgui.ini')

	reload_ini()
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

-- попытка фикса (работает ток при шрифте cour.ttf)
local function replace_t(str)
	while str:find('\t') do
		local space = 8
		local b = str:find('\t')
		local a = math.floor(space * 1.3) - ( b % space + 1 )
		str = str:gsub('\t', (' '):rep(a), 1)
	end
	return str
end

local function cmdhook(this, id, style, caption, text, button1, button2, send)
	returnFunc(hook_addr, inf_addr, true)
	call_addr(this, id, style, caption, text, button1, button2, send)
	returnFunc(hook_addr, detour_addr, false)
	caption, text, button1 = ffi.string(caption), ffi.string(text), ffi.string(button1)
	if GET_POINTER(button2) ~= 0 then button2 = ffi.string(button2) else button2 = nil end
	if id == 65535 or not text:find('%S+') then return enableDialog(false) end
	dialoginfo = { id, style, caption, text:gsub('\n\n', '\n \n'), button1, button2, 0 }
	if dialoginfo[2] == 4 or dialoginfo[2] == 5 then
		while dialoginfo[4]:find('\t\t') do dialoginfo[4] = dialoginfo[4]:gsub('\t\t', '\t') end
	end
	dclist = false
	is_focused = false
	maxwidth, maxheight = -1, -1
	dialogenable = true
	if dialogs[id] and ini.main.save then
		input_dialog.v = u8(dialogs[id][2])
		list_dialog = dialogs[id][1]
	else
		input_dialog.v = ''
		list_dialog = 0
	end
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
			w = replace_t(w)
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
	local rect = imgui.ImVec2(cursor.x + imgui.GetWindowWidth() - 18, cursor.y + imgui.GetFontSize() + 5)
	if imgui.IsMouseHoveringRect(cursor, rect) then
		if imgui.IsMouseClicked(0) then
			list_dialog = i
		end
		if imgui.IsMouseDoubleClicked(0) then
			dclist = true
		end
		current = imgui.IsMouseDown(0) and item_active or item_hover
	end
	imgui.GetWindowDrawList():AddRectFilled(cursor, rect, current, 2)
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
	local rect = imgui.ImVec2(cursor.x + size_text + 8, cursor.y + imgui.GetFontSize() + 5)
	if res then current = item_active end
	if imgui.IsMouseHoveringRect(cursor, rect) then
		current = imgui.IsMouseDown(0) and item_active or item_hover
	end
	imgui.GetWindowDrawList():AddRectFilled(cursor, rect, current, 2)
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
	dialogenable = false
	dialogs[dialoginfo[1]] = { list_dialog, u8:decode(input_dialog.v) }
	--memory.hex2bin(original_shift, sampGetBase() + 0x85860, 3)
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
  
local function getKeyPressed()
	for i = 0x1, 0xFF do
		if wasKeyPressed(i) then return i end
	end
end

local function HelpMarker(desc)
	imgui.TextDisabled('(?)')
	if imgui.IsItemHovered() then
		imgui.BeginTooltip()
		imgui.PushTextWrapPos(imgui.GetFontSize() * 35.0)
		imgui.TextUnformatted(desc)
		imgui.PopTextWrapPos()
		imgui.EndTooltip()
	end
end

function main()
	if not isSampLoaded() then return end
	while not isSampAvailable() do wait(0) end

	local callback = ffi.cast('HOOK_DIALOG', cmdhook)
	detour_addr = GET_POINTER(callback)

	local samp = getModuleHandle('samp.dll')
	hook_addr = samp + 0x6B9C0
	inf_addr = ffi.new('BYTE[6]')
	ffi.copy(inf_addr, ffi.cast('void*', hook_addr), 6)
	call_addr = ffi.cast('HOOK_DIALOG', hook_addr)
	returnFunc(hook_addr, detour_addr, false)

	sampRegisterChatCommand('disettings', function() settings = not settings end)
	reload_ini()

	while true do wait(0)
		if wasKeyPressed(ini.main.hide) and ini.main.hider and dialogenable then
			dialogenable = false
		elseif wasKeyPressed(ini.main.show) and ini.main.hider and #dialoginfo > 0 then
			dialogenable = true
		end
		imgui.Process = dialogenable or settings
	end
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
		imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\' .. u8:decode(fontname.v), fontsize.v, nil, glyph_ranges) -- cour.ttf
		imgui.RebuildFonts()
	end
end

apply_custom_style()
function imgui.OnDrawFrame()
	local x, y = getScreenResolution()
	if dialogenable and not sampIsChatInputActive() and not sampIsScoreboardOpen() then
		-- size
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
						if columns[l] - 20 < size.x then columns[l] = size.x + 20 end
					end
					maxheight = maxheight + size.y + style.ItemSpacing.y
				end
				for i = 1, #columns do maxwidth = maxwidth + columns[i] end
				maxheight = maxheight + 4 * i + 12
			else
				local i = 0
				for w in replace_t(dialoginfo[4]):gmatch('[^\r\n]+') do
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
			maxheight = maxheight + style.ItemSpacing.y + ( imgui.GetFontSize() + 5 ) * 3 + 15
			maxwidth = maxwidth + 22
			if maxwidth < 350 then maxwidth = 350 elseif maxwidth > x / 1.5 then maxwidth = math.floor(x / 1.5) end
			if maxheight < 150 then maxheight = 150 elseif maxheight > y / 1.5 then maxheight = math.floor(y / 1.5) end
		end

		imgui.SetNextWindowPos(imgui.ImVec2(x/2, y/2), imgui.Cond.Once, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(maxwidth, maxheight), imgui.Cond.Always)
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

		-- info
		imgui.BeginChild('##info', imgui.ImVec2(maxwidth, maxheight - ( imgui.GetFontSize() + 5 ) * 4))
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
			imgui.SetCursorPosY(imgui.GetCursorPosY() - 3)
			local info = dialoginfo[4]:gsub('\t\t', '\t \t')
			local a = info:match('^(.-)\n')
			local _, c = a:gsub('\t', '')
			if dialoginfo[2] == 5 then
				info = info:match('^.-\n(.*)')
				imgui.Columns(c + 1)
				for i = 1, #columns - 1 do imgui.SetColumnWidth(i - 1, columns[i]) end
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
			if not is_focused then
				imgui.SetKeyboardFocusHere()
				is_focused = true
			end
			imgui.PopItemWidth()
		end
		imgui.EndChild()

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
	if settings then
		imgui.SetNextWindowPos(imgui.ImVec2(x/2, y/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(500, 293), imgui.Cond.FirstUseEver)
		imgui.Begin('Dialog ImGui | Settings', nil, imgui.WindowFlags.NoTitleBar --[[+ imgui.WindowFlags.HorizontalScrollbar]])
		local sw, sy = imgui.GetWindowWidth(), imgui.GetWindowHeight()
		
		-- header
		local cursor = imgui.GetCursorScreenPos()
		cursor.x = cursor.x - 4
		cursor.y = cursor.y - 3
		imgui.GetWindowDrawList():AddRectFilled(cursor, imgui.ImVec2(cursor.x + sw - 9, cursor.y + imgui.GetFontSize() + 5), 
			imgui.ColorConvertFloat4ToU32(colors[clr.TitleBgActive]))
		print('title', imgui.ColorConvertFloat4ToU32(colors[clr.TitleBgActive]))
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX() + 2, imgui.GetCursorPosY() - 1))
		imgui.Text('Dialog ImGui | Settings')
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 5)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 5)

		-- info
		imgui.Checkbox(u8'Включить Dialog Hider', dialog_hider)
		if dialog_hider.v then
			imgui.Indent(25)
			imgui.Text(u8('Кнопка скрытия: ' .. keys.id_to_name(ini.main.hide)))
			imgui.SameLine()
			if imgui.Button(u8('Изменить##1')) then
				lua_thread.create(function()
					while not getKeyPressed() do wait(0) end
					ini.main.hide = getKeyPressed()
				end)
			end
			imgui.Text(u8('Кнопка показа: ' .. keys.id_to_name(ini.main.show)))
			imgui.SameLine()
			if imgui.Button(u8('Изменить##2')) then
				lua_thread.create(function()
					while not getKeyPressed() do wait(0) end
					ini.main.show = getKeyPressed()
				end)
			end
			imgui.Unindent(25)
		end
		imgui.Checkbox(u8'Включить сохранение элементов после закрытия', save)
		imgui.ColorEdit4(u8'Цвет фона', colors[clr.WindowBg])
		imgui.ColorEdit4(u8'Цвет кнопок', colors[clr.Button])
		imgui.ColorEdit4(u8'Цвет заголовка', colors[clr.TitleBgActive])
		imgui.ColorEdit4(u8'Цвет выбранного элемента', colors[clr.FrameBg])
		imgui.InputInt(u8'Размер шрифта', fontsize, 0)
		imgui.SameLine()
		HelpMarker(u8'Измениться после перезапуска скрипта/игры.')
		imgui.InputText(u8'Название шрифта', fontname)
		imgui.SameLine()
		HelpMarker(u8'Измениться после перезапуска скрипта/игры.')
		if imgui.Button(u8('Применить')) then save_ini() end
		imgui.End()
	end
end

function onWindowMessage(msg, wparam, lparam)
	if msg == 0x100 or msg == 0x101 then
		if wparam == keys.VK_ESCAPE and dialogenable and msg == 0x101 and isKeyCheckAvailable() then
			consumeWindowMessage(true, false)
			if msg == 0x101 then run_button(false) end
		elseif wparam == keys.VK_RETURN and dialogenable and msg == 0x101 and isKeyCheckAvailable() then
			consumeWindowMessage(true, false)
			if msg == 0x101 then run_button(true) end
		elseif ( wparam == keys.VK_UP or keys.VK_DOWN ) and dialogenable and isKeyCheckAvailable() and ( dialoginfo[2] == 2 or dialoginfo[2] == 4 or dialoginfo[2] == 5 ) then
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
	end
end

-- fucking shift
function onSendRpc(id, bs)
	local str = memory.getuint32(sampGetBase() + 0x21A18C)
	if ( id == 128 or id == 129 ) and memory.getuint8(str + 0x13) == 1 and imgui.Process then return false end
end
