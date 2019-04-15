script_author('imring')
script_version_number(6.0)
local ffi = require 'ffi'
local memory = require 'memory'
local imgui = require 'imgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local inicfg = require 'inicfg'

ffi.cdef[[
typedef void *PVOID;
typedef uint8_t BYTE;
typedef uint16_t WORD;
typedef uint32_t DWORD;
typedef char CHAR;
typedef CHAR *PCHAR;

typedef void(__thiscall *HOOK_DIALOG)(PVOID this, WORD wID, BYTE iStyle, PCHAR szCaption, PCHAR szText, PCHAR szButton1, PCHAR szButton2, bool bSend);
int GetLocaleInfoA(int Locale, int LCType, PCHAR lpLCData, int cchData);
bool GetKeyboardLayoutNameA(char* pwszKLID);
]]
local layout = ffi.new('char[10]')
local info = ffi.new('char[10]')

local dialoginfo = {}
local input_dialog = imgui.ImBuffer(0xFFFF)
local list_dialog = 0
local dclist = false
local columns = {}
local maxwidth = -1
local maxheight = -1
local dialogs = {}
local is_focused = false
local last_id = -1

local settings = false
local dialog_hider = imgui.ImBool(false)
local save = imgui.ImBool(false)
local fontsize = imgui.ImInt(0)
local fontname = imgui.ImBuffer(256)
local layoute = imgui.ImBool(false)
local imguistart = imgui.ImBool(false)
local screendialog = imgui.ImBool(false)

local ini = inicfg.load(nil, '..\\dialogimgui.ini')

local fontChanged = false

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
	style.WindowPadding = imgui.ImVec2(0.0, 0.0)
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
	layoute.v = ini.main.layout
	imguistart.v = ini.dialog.show
	screendialog.v = ini.dialog.screen

	fontChanged = false
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
	ini.main.layout = layoute.v
	ini.dialog.show = imguistart.v
	ini.dialog.screen = screendialog.v

	inicfg.save(ini, '..\\dialogimgui.ini')

	reload_ini()
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
		local prevclr = colors[1]
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
					imgui.TextColored(colors_[i] or prevclr, u8(text[i]))
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
	local rect = imgui.ImVec2(cursor.x + imgui.GetWindowWidth() - 8, cursor.y + imgui.GetFontSize() + 5)
	if imgui.InvisibleButton('##'..i, imgui.ImVec2(imgui.GetWindowWidth() - 8, imgui.GetFontSize() + 5)) then
		sampSetCurrentDialogListItem(i)
		current = item_active
	end
	if imgui.IsMouseHoveringRect(cursor, rect) then
		current = imgui.IsMouseDown(0) and item_active or item_hover
		if imgui.IsMouseDoubleClicked(0) then
			dclist = true
		end
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
	sampSetCurrentDialogListItem(list_dialog)
	sampCloseCurrentDialogWithButton(bool and 1 or 0)
	last_id = -1
	dialogs[dialoginfo[1]] = { list_dialog, u8:decode(input_dialog.v) }
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

local function vec4_to_float4(vec4)
	local r, g, b, a = vec4.x, vec4.y, vec4.z, vec4.w
	return imgui.ImFloat4(r, g, b, a)
end

local function float4_to_vec4(float4)
	local r, g, b, a = float4.v[1], float4.v[2], float4.v[3], float4.v[4]
	return imgui.ImVec4(r, g, b, a)
end

local func_get_button
local function sampGetDialogButtons()
    local dialog = ffi.cast('void*', getStructElement(sampGetDialogInfoPtr(), 0x1C, 4))
    local b1p = func_get_button(dialog, 20, 0) + 0x4D
    local b2p = func_get_button(dialog, 21, 0) + 0x4D
    return ffi.string(b1p), ffi.string(b2p)
end

local is_screen, original = false, 0
function main()
	if not isSampLoaded() then return end
	reload_ini()

	func_get_button = ffi.cast('char*(__thiscall *)(void* this, int a, int b)', sampGetBase() + 0x82C50)
	original = memory.getuint8(sampGetBase() + 0x6B240, true)
	if imguistart.v then memory.setuint8(sampGetBase() + 0x6B240, 0xC3, true) end -- disable render dxut dialog

	while not isSampAvailable() do wait(0) end

	sampRegisterChatCommand('disettings', function() settings = not settings end)

	while true do wait(0)
		imgui.Process = sampIsDialogActive() or settings
		if sampIsDialogActive() then
			local b1, b2 = sampGetDialogButtons()
			dialoginfo = { sampGetCurrentDialogId(), sampGetCurrentDialogType(), sampGetDialogCaption(), sampGetDialogText():gsub('\n\n', '\n \n'), b1, b2 }
			list_dialog = sampGetCurrentDialogListItem()
			input_dialog.v = u8(sampGetCurrentDialogEditboxText())
			if last_id ~= dialoginfo[1] then
				local id = dialoginfo[1]
				dclist = false
				is_focused = false
				maxwidth, maxheight = -1, -1
				if dialogs[id] and ini.main.save then
					sampSetCurrentDialogEditboxText(dialogs[id][2])
					sampSetCurrentDialogListItem(dialogs[id][1])
				end
				last_id = id
			end
			lockPlayerControl(true)
		else
			last_id = -1
			wait(100)
			lockPlayerControl(false)
		end
		if screendialog.v and sampIsDialogActive() then
			if memory.getuint8(sampGetBase() + 0x119CBC) == 1 and not is_screen then
				memory.setuint8(sampGetBase() + 0x119CBC, 0)
				memory.setuint8(sampGetBase() + 0x6B240, original, true) -- enable render dxut dialog
				imgui.Process = false
				wait(100)
				memory.setuint8(sampGetBase() + 0x119CBC, 1)
				is_screen = true
			elseif memory.getuint8(sampGetBase() + 0x119CBC) == 0 and is_screen then
				memory.setuint8(sampGetBase() + 0x6B240, 0xC3, true) -- disable render dxut dialog
				sampToggleCursor(false)
				imgui.Process = sampIsDialogActive() or settings
				is_screen = false
			end
		end
	end
end

function onScriptTerminate(scr)
	if scr == script.this then
		memory.setuint8(sampGetBase() + 0x6B240, original, true) -- enable render dxut dialog
	end
end

function imgui.BeforeDrawFrame()
	if not fontChanged then
		fontChanged = true
		local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
		imgui.GetIO().Fonts:Clear()
		local path = getFolderPath(0x14) .. '\\' .. u8:decode(fontname.v)
		if not doesFileExist(path) then path = getFolderPath(0x14) .. '\\arial.ttf' end
		imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\' .. u8:decode(fontname.v), fontsize.v, nil, glyph_ranges) -- cour.ttf
		imgui.RebuildFonts()
	end
end

apply_custom_style()
function imgui.OnDrawFrame()
	local x, y = getScreenResolution()
	if sampIsDialogActive() and imguistart.v and not sampIsChatInputActive() and not sampIsScoreboardOpen() then
		-- size
		if maxwidth == -1 and maxheight == -1 then
			local title = dialoginfo[3]:gsub('{%x%x%x%x%x%x}', '')
			maxwidth = imgui.CalcTextSize(u8(title)).x
			maxheight = imgui.GetFontSize() + 13
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
					maxheight = maxheight + imgui.GetFontSize() + 5 + style.ItemSpacing.y + 1.5
				end
				local mw = 0
				for i = 1, #columns do mw = mw + columns[i] end
				if mw > maxwidth then maxwidth = mw end
				maxheight = maxheight + 5
			else
				local i = 0
				for w in replace_t(dialoginfo[4]:gsub('{%x%x%x%x%x%x}', '')):gmatch('[^\r\n]+') do
					i = i + 1
					local size = imgui.CalcTextSize(u8(w))
					if maxwidth < size.x then maxwidth = size.x end
					if dialoginfo[2] == 2 then maxheight = maxheight + imgui.GetFontSize() + 8
					else maxheight = maxheight + imgui.GetFontSize() + style.ItemSpacing.y + 1 end
				end
				if dialoginfo[2] == 2 then maxheight = maxheight + 15 end
				-- if dialoginfo[2] == 2 then maxheight = maxheight + 5 * i end
				if dialoginfo[2] == 1 or dialoginfo[2] == 3 then
					maxheight = maxheight + style.ItemSpacing.y + imgui.GetFontSize() * 2 + 5
				end
			end
			maxheight = maxheight + style.ItemSpacing.y + imgui.GetFontSize()
			-- maxheight = maxheight + style.ItemSpacing.y + ( imgui.GetFontSize() + 5 ) * 3 + 15
			maxwidth = maxwidth + 8
			if maxwidth < 300 then maxwidth = 300 --[[elseif maxwidth > x / 1.2 then maxwidth = math.floor(x / 1.5)]] end
			if maxheight < 100 then maxheight = 100 elseif maxheight > y / 1.1 then maxheight = math.floor(y / 1.1) end
		end

		imgui.SetNextWindowPos(imgui.ImVec2(x/2, y/2), imgui.Cond.Once, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(maxwidth, maxheight), imgui.Cond.Always)
		imgui.Begin(u8(dialoginfo[3]), nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar --[[+ imgui.WindowFlags.HorizontalScrollbar]])
		local sw, sy = imgui.GetWindowWidth(), imgui.GetWindowHeight()
		
		-- header 
		local cursor = imgui.GetCursorScreenPos() 
		cursor.x = cursor.x - 4 
		cursor.y = cursor.y - 3 
		imgui.GetWindowDrawList():AddRectFilled(cursor, imgui.ImVec2(cursor.x + sw + 4, cursor.y + imgui.GetFontSize() + 5 + 3), 
		imgui.ColorConvertFloat4ToU32(colors[clr.TitleBgActive])) 
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX() + 3, imgui.GetCursorPosY() + 2)) 
		imguiTextColoredRGB(dialoginfo[3]) 
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 5) 
		imgui.Indent(4)

		-- info
		imgui.BeginChild('##info', imgui.ImVec2(maxwidth, maxheight - ( imgui.GetFontSize() + 5 ) * 3))
		if dialoginfo[2] == 2 then
			local i = -1
			for w in dialoginfo[4]:gmatch('[^\r\n]+') do
				i = i + 1
				local cursor_item = imgui.GetCursorPos()
				render_selectable(i)
				imgui.SetCursorPosY(cursor_item.y + 1)
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
				if not columns[c + 1] then c = c - 1 end
				imgui.Columns(c + 1)
				local i = 0
				for w in a:gmatch('[^\t]+') do
					i = i + 1
					if i ~= c then imgui.SetColumnWidth(imgui.GetColumnIndex(), columns[i]) end
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
			dialoginfo[8] = i
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
			-- get layout
			ffi.C.GetKeyboardLayoutNameA(layout)
			ffi.C.GetLocaleInfoA(tonumber(ffi.string(layout), 16), 0x3, info, ffi.sizeof(info))
			local res = ffi.string(info):sub(1, 2)
			local cur = imgui.GetCursorPosY()
			local off = 0
			if ini.main.layout then
				--[[imgui.SetCursorPosY(cur + 1)
				imgui.Text(res)
				imgui.SameLine()]]
				off = style.ItemSpacing.y + imgui.CalcTextSize(res).x
			end

			imgui.SetCursorPosY(cur)
			imgui.PushItemWidth(sw - 10 - ( off > 0 and off + 5 or 0))
			if imgui.InputText('##input', input_dialog, dialoginfo[2] == 3 and imgui.InputTextFlags.Password or 0) then
				sampSetCurrentDialogEditboxText(u8:decode(input_dialog.v))
			end
			if not is_focused then
				imgui.SetKeyboardFocusHere()
				is_focused = true
			end
			if ini.main.layout then
				imgui.SameLine()
				local bgnew = imgui.ImVec4(colors[clr.WindowBg].x + 0.1, colors[clr.WindowBg].y + 0.1, colors[clr.WindowBg].z + 0.1, colors[clr.WindowBg].w)
				local cursor = imgui.GetCursorScreenPos()
				cursor.x = cursor.x - 2
				imgui.GetWindowDrawList():AddRectFilled(cursor, imgui.ImVec2(cursor.x + off, cursor.y + imgui.GetFontSize() + 5), 
					imgui.ColorConvertFloat4ToU32(bgnew), 2)
				imgui.SetCursorPosY(cur - 2)
				imgui.Text(res)
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
		imgui.SetCursorPos(imgui.ImVec2((sw - sb) / 2 - 4, imgui.GetCursorPosY()))
		if render_button(999, dialoginfo[5]) or dclist then run_button(true) end
		if dialoginfo[6] and #dialoginfo[6] > 0 then 
			imgui.SameLine(nil, 7)
			imgui.SetCursorPosY(imgui.GetCursorPosY() - 2)
			if render_button(998, dialoginfo[6]) then run_button(false) end
		end
		imgui.Unindent(4)
		imgui.End()
	end
	if settings then
		imgui.SetNextWindowPos(imgui.ImVec2(x/2, y/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(500, 277), imgui.Cond.FirstUseEver)
		imgui.Begin('Dialog ImGui | Settings', nil, imgui.WindowFlags.NoTitleBar --[[+ imgui.WindowFlags.HorizontalScrollbar]])
		local sw, sy = imgui.GetWindowWidth(), imgui.GetWindowHeight()
		
		-- header
		local cursor = imgui.GetCursorScreenPos() 
		cursor.x = cursor.x - 4 
		cursor.y = cursor.y - 3 
		imgui.GetWindowDrawList():AddRectFilled(cursor, imgui.ImVec2(cursor.x + sw + 4, cursor.y + imgui.GetFontSize() + 5 + 3), 
		imgui.ColorConvertFloat4ToU32(colors[clr.TitleBgActive])) 
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX() + 3, imgui.GetCursorPosY() + 1)) 
		imgui.Text('Dialog ImGui | Settings')
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 5) 
		imgui.PushStyleVar(imgui.StyleVar.WindowPadding, imgui.ImVec2(8, 8))
		imgui.Indent(4)

		-- info
		if imgui.Checkbox(u8'Включить Dialog ImGui', imguistart) then
			if imguistart.v then memory.setuint8(sampGetBase() + 0x6B240, 0xC3, true)
			else memory.setuint8(sampGetBase() + 0x6B240, original, true) end
		end
		if imguistart.v then
			imgui.Checkbox(u8'Возвращать стандарт. диалог при нажатие F8', screendialog)
			imgui.Checkbox(u8'Включить сохранение элементов после закрытия', save)
			imgui.Checkbox(u8'Включить показ раскладки', layoute)
			local win = vec4_to_float4(colors[clr.WindowBg])
			if imgui.ColorEdit4(u8'Цвет фона', win, imgui.ColorEditFlags.AlphaBar) then
				colors[clr.WindowBg] = float4_to_vec4(win)
			end
			local but = vec4_to_float4(colors[clr.Button])
			if imgui.ColorEdit4(u8'Цвет кнопок', but, imgui.ColorEditFlags.AlphaBar) then
				colors[clr.Button] = float4_to_vec4(but)
			end
			local tit = vec4_to_float4(colors[clr.TitleBgActive])
			if imgui.ColorEdit4(u8'Цвет заголовка', tit, imgui.ColorEditFlags.AlphaBar) then
				colors[clr.TitleBgActive] = float4_to_vec4(tit)
			end
			local frame = vec4_to_float4(colors[clr.FrameBg])
			if imgui.ColorEdit4(u8'Цвет выбранного элемента', frame, imgui.ColorEditFlags.AlphaBar) then
				colors[clr.FrameBg] = float4_to_vec4(frame)
			end
			imgui.InputInt(u8'Размер шрифта', fontsize, 0)
			imgui.InputText(u8'Название шрифта', fontname)
		end
		if imgui.Button(u8('Применить')) then save_ini() end
		imgui.Unindent(4)
		imgui.PopStyleVar()
		imgui.End()
	end
end

-- fucking shift
function onSendRpc(id, bs)
	local str = memory.getuint32(sampGetBase() + 0x21A18C)
	if ( id == 128 or id == 129 ) and memory.getuint8(str + 0x13) == 1 and sampIsDialogActive() then return false end
end
