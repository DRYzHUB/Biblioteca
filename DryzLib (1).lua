--[[
    DryzLib  ·  UI Library  ·  v1.0.0
    Visual escuro estilo WindUI (zinc + contornos sutis) com ícones Lucide.

    Uso rápido:
        local Lib    = loadstring(readfile("DryzLib.lua"))()
        local Window = Lib:CreateWindow({ Title = "Meu Hub", Subtitle = "v1.0", Icon = "droplets" })
        local Tab    = Window:Tab({ Title = "Principal", Icon = "zap" })

        Tab:Section("Exemplo")
        Tab:Button({ Title = "Clique", Icon = "zap", Callback = function() print("ok") end })
        Tab:Toggle({ Title = "Ativar", Default = false, Callback = function(v) print(v) end })
        Tab:Slider({ Title = "Valor", Min = 0, Max = 100, Default = 50, Callback = print })
        Tab:Dropdown({ Title = "Escolha", Values = {"A","B"}, Callback = print })
        Tab:Input({ Title = "Texto", Placeholder = "...", Callback = print })
        Tab:Keybind({ Title = "Tecla", Default = Enum.KeyCode.F, Callback = function() end })
        Window:Notify({ Title = "Pronto", Content = "Carregado", Type = "success" })

    Ícones: nome Lucide embutido (ver Library.Icons), "rbxassetid://ID" ou número.
    Adicione mais com  Library:AddIcons({ ["nome"] = "rbxassetid://ID" }).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Library = { Version = "1.0.0", Windows = {} }

--=====================================================================
--  TEMA
--=====================================================================
local Theme = {
    Bg           = Color3.fromHex("#101010"),
    Panel        = Color3.fromHex("#18181b"),
    Element      = Color3.fromHex("#1f1f23"),
    ElementHover = Color3.fromHex("#27272c"),
    ElementPress = Color3.fromHex("#34343a"),
    Outline      = Color3.fromHex("#ffffff"),
    Text         = Color3.fromHex("#f4f4f5"),
    SubText      = Color3.fromHex("#a1a1aa"),
    Placeholder  = Color3.fromHex("#7a7a7a"),
    Track        = Color3.fromHex("#3f3f46"),
    Success      = Color3.fromHex("#30ff6a"),
    Danger       = Color3.fromHex("#f87171"),
    Warn         = Color3.fromHex("#fbbf24"),
    Info         = Color3.fromHex("#60a5fa"),
}
local OUTLINE_T = 0.9
Library.Theme = Theme

--=====================================================================
--  HELPERS
--=====================================================================
local function new(class, props, children)
    local inst = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else inst[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end

local function stroke(transparency, color, thickness)
    return new("UIStroke", {
        Color = color or Theme.Outline,
        Transparency = transparency or OUTLINE_T,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function pad(l, t, r, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t),
    })
end

local function tween(inst, time, props, style)
    local tw = TweenService:Create(inst,
        TweenInfo.new(time, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function label(parent, props)
    props.BackgroundTransparency = 1
    props.Parent = parent
    props.Font = props.Font or Enum.Font.GothamMedium
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    return new("TextLabel", props)
end

local function safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[DryzLib] " .. tostring(err)) end
end

--=====================================================================
--  ÍCONES (Lucide, asset IDs embutidos)
--=====================================================================
Library.Icons = {
    ["droplets"] = "rbxassetid://140111846025180",
    ["x"] = "rbxassetid://110786993356448",
    ["minus"] = "rbxassetid://118026365011536",
    ["plus"] = "rbxassetid://111774323017047",
    ["users"] = "rbxassetid://115398113982385",
    ["user"] = "rbxassetid://81589895647169",
    ["user-x"] = "rbxassetid://139748155894754",
    ["zap"] = "rbxassetid://130551565616516",
    ["settings"] = "rbxassetid://80758916183665",
    ["search"] = "rbxassetid://121018724060431",
    ["check"] = "rbxassetid://93898873302694",
    ["circle-check"] = "rbxassetid://85262178816537",
    ["circle-alert"] = "rbxassetid://83898160590116",
    ["triangle-alert"] = "rbxassetid://125920361880643",
    ["info"] = "rbxassetid://124560466474914",
    ["crosshair"] = "rbxassetid://134242818164054",
    ["power"] = "rbxassetid://96479131758775",
    ["skull"] = "rbxassetid://137726256442333",
    ["flame"] = "rbxassetid://98218034436456",
    ["bomb"] = "rbxassetid://139223800924636",
    ["snowflake"] = "rbxassetid://101235206534566",
    ["activity"] = "rbxassetid://94212016861936",
    ["arrow-down-to-line"] = "rbxassetid://87050478931254",
    ["log-out"] = "rbxassetid://84895399304975",
    ["lock"] = "rbxassetid://134724289526879",
    ["lock-open"] = "rbxassetid://93597915325122",
    ["sun"] = "rbxassetid://110150589884127",
    ["moon"] = "rbxassetid://83380517901735",
    ["image"] = "rbxassetid://112751259236831",
    ["terminal"] = "rbxassetid://106783148545356",
    ["ghost"] = "rbxassetid://113822048130017",
    ["trophy"] = "rbxassetid://131545003268773",
    ["door-open"] = "rbxassetid://91306356501736",
    ["shield-check"] = "rbxassetid://87354736164608",
    ["shield"] = "rbxassetid://110987169760162",
    ["bell"] = "rbxassetid://97392696311902",
    ["sparkles"] = "rbxassetid://138635884129147",
    ["house"] = "rbxassetid://98755624629571",
    ["eye"] = "rbxassetid://100033680381365",
    ["eye-off"] = "rbxassetid://135928786788378",
    ["star"] = "rbxassetid://136141469398409",
    ["heart"] = "rbxassetid://116559368303288",
    ["copy"] = "rbxassetid://78979572434545",
    ["trash-2"] = "rbxassetid://109843431391323",
    ["play"] = "rbxassetid://135609604299893",
    ["pause"] = "rbxassetid://74873705394436",
    ["refresh-cw"] = "rbxassetid://138133190015277",
    ["chevron-down"] = "rbxassetid://134243273101015",
    ["chevron-up"] = "rbxassetid://122444883127455",
    ["chevron-right"] = "rbxassetid://92473583511724",
    ["chevron-left"] = "rbxassetid://73780377692148",
    ["mouse-pointer"] = "rbxassetid://72322454962935",
    ["keyboard"] = "rbxassetid://121474456068237",
    ["palette"] = "rbxassetid://86350350950064",
    ["globe"] = "rbxassetid://114238209622913",
    ["wifi"] = "rbxassetid://104669375183960",
    ["crown"] = "rbxassetid://127843403295538",
    ["code"] = "rbxassetid://107380207681249",
    ["bug"] = "rbxassetid://83626408925438",
    ["wrench"] = "rbxassetid://112148279212860",
    ["sliders-horizontal"] = "rbxassetid://85538382643347",
    ["list"] = "rbxassetid://113179976918783",
    ["layout-dashboard"] = "rbxassetid://139929981863901",
    ["move"] = "rbxassetid://116138709011735",
    ["rocket"] = "rbxassetid://87412317685854",
    ["target"] = "rbxassetid://87563802520297",
    ["save"] = "rbxassetid://126116963775616",
    ["folder"] = "rbxassetid://80846616596607",
    ["download"] = "rbxassetid://134814648082393",
    ["upload"] = "rbxassetid://138212042425501",
    ["map-pin"] = "rbxassetid://84279202219901",
    ["music"] = "rbxassetid://113343203848535",
    ["camera"] = "rbxassetid://79950339943067",
    ["message-circle"] = "rbxassetid://127255077587058",
    ["swords"] = "rbxassetid://81872698913435",
    ["gamepad-2"] = "rbxassetid://92483947987410",
    ["wand-sparkles"] = "rbxassetid://82546429942392",
    ["flag"] = "rbxassetid://78183383236196",
    ["key"] = "rbxassetid://96510194465420",
    ["lock-keyhole"] = "rbxassetid://78672912777756",
    ["link"] = "rbxassetid://131607023382430",
    ["clock"] = "rbxassetid://121808839832144",
    ["layers"] = "rbxassetid://81973586053257",
    ["cpu"] = "rbxassetid://77549309870247",
    ["server"] = "rbxassetid://92188766517878",
    ["database"] = "rbxassetid://126791525623846",
    ["file-text"] = "rbxassetid://90496405707281",
    ["clipboard"] = "rbxassetid://89601995828423",
    ["menu"] = "rbxassetid://77021539815611",
    ["ellipsis"] = "rbxassetid://140019550645825",
    ["circle-user"] = "rbxassetid://136220511671311",
    ["bot"] = "rbxassetid://80451686744860",
    ["box"] = "rbxassetid://101768155599700",
    ["package"] = "rbxassetid://97261141732706",
    ["sword"] = "rbxassetid://124448418211665",
}

local Glyphs = {
    ["users"] = "◉", ["zap"] = "⚡", ["settings"] = "⚙", ["search"] = "⌕",
    ["x"] = "✕", ["minus"] = "–", ["check"] = "✓", ["plus"] = "+",
    ["circle-check"] = "✓", ["circle-alert"] = "!", ["triangle-alert"] = "!",
    ["info"] = "i", ["chevron-down"] = "⌄", ["chevron-right"] = "›",
}

function Library:AddIcons(tbl)
    for k, v in pairs(tbl) do self.Icons[k] = v end
end

local function resolveIconId(name)
    if type(name) == "number" then return "rbxassetid://" .. name end
    if type(name) ~= "string" then return nil end
    if name:find("^rbxassetid://") or name:find("^rbxasset://") then return name end
    return Library.Icons[name]
end

local function makeIcon(parent, name, size, color, props)
    props = props or {}
    local frame = new("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        LayoutOrder = props.LayoutOrder or 0,
        Parent = parent,
    })
    local img = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        ImageColor3 = color, Visible = false, Parent = frame,
    })
    local glyph = new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        TextColor3 = color, TextSize = math.floor(size * 0.9),
        Font = Enum.Font.GothamBold, Visible = false, Parent = frame,
    })
    local obj = { Frame = frame, Image = img, Glyph = glyph }

    function obj:SetColor(c) img.ImageColor3 = c; glyph.TextColor3 = c end
    function obj:SetIcon(n)
        local id = resolveIconId(n)
        if id then
            img.Image = id; img.Visible = true; glyph.Visible = false
        elseif n ~= nil and n ~= "" then
            glyph.Text = Glyphs[n] or "•"; glyph.Visible = true; img.Visible = false
        else
            img.Visible = false; glyph.Visible = false
        end
    end
    obj:SetIcon(name)
    return obj
end

--=====================================================================
--  JANELA
--=====================================================================
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local Window = { Flags = {}, Tabs = {}, _conns = {}, _visible = true, _minimized = false }

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(Window._conns, c)
        return c
    end
    Window._connect = connect

    local WIDTH = (cfg.Size and cfg.Size.X) or 640
    local HEIGHT = (cfg.Size and cfg.Size.Y) or 420
    local HEADER = 52
    local guiName = cfg.Name or "DryzLibUI"
    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    local showProfile = cfg.ShowProfile ~= false
    local animations = cfg.Animations ~= false
    local notifications = cfg.Notifications ~= false

    local parentGui = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
    local old = parentGui:FindFirstChild(guiName)
    if old then old:Destroy() end

    local gui = new("ScreenGui", {
        Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
        Parent = parentGui,
    })
    Window.Gui = gui

    local main = new("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WIDTH, HEIGHT),
        BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.04,
        BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
    }, { corner(16), stroke(0.88) })
    Window.Main = main

    local uiScale = new("UIScale", { Parent = main })
    local function baseScale()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        return math.clamp(math.min(vp.X / (WIDTH + 60), vp.Y / (HEIGHT + 60)), 0.55, 1)
    end
    uiScale.Scale = baseScale()

    ---------------------------------------------------------------- header
    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, HEADER), BackgroundTransparency = 1, Parent = main,
    })
    new("Frame", {
        Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Outline, BackgroundTransparency = OUTLINE_T,
        BorderSizePixel = 0, Parent = header,
    })
    local logoBox = new("Frame", {
        Position = UDim2.new(0, 16, 0.5, -16), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Theme.Element, Parent = header,
    }, { corner(9), stroke(OUTLINE_T) })
    makeIcon(logoBox, cfg.Icon or "droplets", 18, Theme.Text, { Position = UDim2.new(0.5, -9, 0.5, -9) })

    local titleLabel = label(header, {
        Position = UDim2.new(0, 58, 0, 9), Size = UDim2.new(0, 300, 0, 18),
        Text = cfg.Title or "Window", TextColor3 = Theme.Text, TextSize = 15, Font = Enum.Font.GothamBold,
    })
    local subtitleLabel = label(header, {
        Position = UDim2.new(0, 58, 0, 28), Size = UDim2.new(0, 300, 0, 14),
        Text = cfg.Subtitle or "", TextColor3 = Theme.SubText, TextSize = 11, Font = Enum.Font.Gotham,
    })
    function Window:SetTitle(t) titleLabel.Text = t end
    function Window:SetSubtitle(t) subtitleLabel.Text = t end

    local function headerButton(iconName, xOffset, hoverColor)
        local b = new("TextButton", {
            Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, xOffset, 0.5, -15),
            BackgroundColor3 = Theme.Outline, BackgroundTransparency = 1,
            AutoButtonColor = false, Text = "", Parent = header,
        }, { corner(8) })
        local ic = makeIcon(b, iconName, 16, Theme.SubText, { Position = UDim2.new(0.5, -8, 0.5, -8) })
        b.MouseEnter:Connect(function()
            tween(b, 0.15, { BackgroundTransparency = 0.92 }); ic:SetColor(hoverColor or Theme.Text)
        end)
        b.MouseLeave:Connect(function()
            tween(b, 0.15, { BackgroundTransparency = 1 }); ic:SetColor(Theme.SubText)
        end)
        return b, ic
    end
    local closeBtn = headerButton("x", -42, Theme.Danger)
    local minBtn, minIcon = headerButton("minus", -76)

    do -- arrastar
        local dragging, dragStart, startPos
        connect(header.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, input.Position, main.Position
                local c; c = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false; c:Disconnect()
                    end
                end)
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
    end

    ---------------------------------------------------------------- corpo
    local body = new("Frame", {
        Position = UDim2.new(0, 0, 0, HEADER), Size = UDim2.new(1, 0, 1, -HEADER),
        BackgroundTransparency = 1, Parent = main,
    })
    local sidebar = new("Frame", {
        Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 150, 1, -40),
        BackgroundTransparency = 1, Parent = body,
    })
    local tabList = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, showProfile and -54 or 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = sidebar,
    }, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
    local pages = new("Frame", {
        Position = UDim2.new(0, 170, 0, 10), Size = UDim2.new(1, -180, 1, -40),
        BackgroundTransparency = 1, Parent = body,
    })

    -- rodapé
    local footer = new("Frame", {
        Position = UDim2.new(0, 14, 1, -26), Size = UDim2.new(1, -28, 0, 18),
        BackgroundTransparency = 1, Parent = body,
    })
    local footerLeft = label(footer, {
        Size = UDim2.new(0.6, 0, 1, 0), Text = "", TextColor3 = Theme.SubText, TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local footerRight = label(footer, {
        Position = UDim2.fromScale(0.6, 0), Size = UDim2.fromScale(0.4, 1), Text = "",
        TextColor3 = Theme.SubText, TextSize = 11, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    function Window:SetFooter(left, right)
        if left ~= nil then footerLeft.Text = left end
        if right ~= nil then footerRight.Text = right end
    end

    if showProfile then
        local profile = new("Frame", {
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Element, Parent = sidebar,
        }, { corner(12), stroke(OUTLINE_T) })
        local av = new("ImageLabel", {
            Position = UDim2.new(0, 7, 0.5, -16), Size = UDim2.fromOffset(32, 32),
            BackgroundColor3 = Theme.Bg, Parent = profile,
        }, { corner(16) })
        task.spawn(function()
            local ok, img = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            if ok and av.Parent then av.Image = img end
        end)
        label(profile, {
            Position = UDim2.new(0, 46, 0, 7), Size = UDim2.new(1, -52, 0, 16),
            Text = LocalPlayer.DisplayName, TextColor3 = Theme.Text, TextSize = 12,
            Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        label(profile, {
            Position = UDim2.new(0, 46, 0, 24), Size = UDim2.new(1, -52, 0, 14),
            Text = "@" .. LocalPlayer.Name, TextColor3 = Theme.SubText, TextSize = 10,
            Font = Enum.Font.Gotham, TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end

    ---------------------------------------------------------------- notificações
    local toastHolder = new("Frame", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(280, 360), BackgroundTransparency = 1, Parent = gui,
    }, {
        new("UIListLayout", {
            Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local ToastStyle = {
        error   = { Theme.Danger,  "circle-alert" },
        success = { Theme.Success, "circle-check" },
        warn    = { Theme.Warn,    "triangle-alert" },
        info    = { Theme.Info,    "info" },
    }

    --- Window:Notify("texto", "success")  ou  Window:Notify({Title=, Content=, Type=, Duration=})
    function Window:Notify(a, b)
        if not notifications then return end
        local n = type(a) == "table" and a or { Content = a, Type = b }
        local style = ToastStyle[n.Type or "info"] or ToastStyle.info
        local hasTitle = n.Title and n.Title ~= ""
        local height = hasTitle and 56 or 44

        local toast = new("CanvasGroup", {
            Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Theme.Panel,
            GroupTransparency = 1, Parent = toastHolder,
        }, { corner(12), stroke(0.85) })
        makeIcon(toast, n.Icon or style[2], 18, style[1], { Position = UDim2.new(0, 14, 0.5, -9) })
        if hasTitle then
            label(toast, {
                Position = UDim2.new(0, 42, 0, 9), Size = UDim2.new(1, -52, 0, 16),
                Text = n.Title, TextColor3 = Theme.Text, TextSize = 13, Font = Enum.Font.GothamBold,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            label(toast, {
                Position = UDim2.new(0, 42, 0, 27), Size = UDim2.new(1, -52, 0, 16),
                Text = n.Content or "", TextColor3 = Theme.SubText, TextSize = 12, Font = Enum.Font.Gotham,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        else
            label(toast, {
                Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -52, 1, 0),
                Text = n.Content or "", TextColor3 = Theme.Text, TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end
        tween(toast, 0.25, { GroupTransparency = 0 })
        task.delay(n.Duration or 2.6, function()
            if toast.Parent then
                tween(toast, 0.3, { GroupTransparency = 1 }).Completed:Wait()
                toast:Destroy()
            end
        end)
    end

    ---------------------------------------------------------------- abas
    local activeTab
    function Window:SelectTab(tab)
        for _, t in ipairs(Window.Tabs) do
            local on = (t == tab)
            t.Page.Visible = on
            tween(t._btn, 0.18, { BackgroundTransparency = on and 0.92 or 1 })
            t._label.TextColor3 = on and Theme.Text or Theme.SubText
            t._icon:SetColor(on and Theme.Text or Theme.SubText)
        end
        activeTab = tab
    end

    function Window:Tab(tcfg)
        tcfg = tcfg or {}
        local Tab = { Window = Window, _order = 0 }
        local name = tcfg.Title or "Tab"

        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Outline,
            BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
            LayoutOrder = #Window.Tabs + 1, Parent = tabList,
        }, { corner(10) })
        local ic = makeIcon(btn, tcfg.Icon, 16, Theme.SubText, { Position = UDim2.new(0, 12, 0.5, -8) })
        local lbl = label(btn, {
            Position = UDim2.new(0, tcfg.Icon and 38 or 14, 0, 0),
            Size = UDim2.new(1, -42, 1, 0), Text = name, TextColor3 = Theme.SubText, TextSize = 13,
        })
        btn.MouseEnter:Connect(function()
            if activeTab ~= Tab then tween(btn, 0.15, { BackgroundTransparency = 0.96 }) end
        end)
        btn.MouseLeave:Connect(function()
            if activeTab ~= Tab then tween(btn, 0.15, { BackgroundTransparency = 1 }) end
        end)
        btn.MouseButton1Click:Connect(function() Window:SelectTab(Tab) end)

        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.SubText, ScrollBarImageTransparency = 0.5,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
            Visible = false, Parent = pages,
        }, {
            new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
            pad(0, 0, 6, 8),
        })

        Tab.Page, Tab._btn, Tab._label, Tab._icon = page, btn, lbl, ic
        table.insert(Window.Tabs, Tab)
        if #Window.Tabs == 1 then Window:SelectTab(Tab) end

        function Tab:Select() Window:SelectTab(Tab) end

        ------------------------------------------------------------ base de elementos
        local function nextOrder()
            Tab._order = Tab._order + 1
            return Tab._order
        end

        local function makeRow(height)
            return new("Frame", {
                Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Theme.Element,
                LayoutOrder = nextOrder(), Parent = page,
            }, { corner(12), stroke(OUTLINE_T) })
        end

        -- título + descrição; retorna (title, desc, height)
        local function rowText(row, ecfg, left, right, hasDesc)
            local title = label(row, {
                Position = UDim2.new(0, left, 0, hasDesc and 10 or 0),
                Size = UDim2.new(1, -(left + right), 0, hasDesc and 16 or 42),
                Text = ecfg.Title or "", TextColor3 = ecfg.Danger and Theme.Danger or Theme.Text,
                TextSize = 13, Font = hasDesc and Enum.Font.GothamBold or Enum.Font.GothamMedium,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local desc
            if hasDesc then
                desc = label(row, {
                    Position = UDim2.new(0, left, 0, 28), Size = UDim2.new(1, -(left + right), 0, 14),
                    Text = ecfg.Desc, TextColor3 = Theme.SubText, TextSize = 11, Font = Enum.Font.Gotham,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                })
            end
            return title, desc
        end

        local function leftOffset(ecfg) return ecfg.Icon and 44 or 14 end

        local function baseObject(row, title, desc)
            local obj = { Row = row }
            function obj:SetTitle(t) title.Text = t end
            function obj:SetDesc(t) if desc then desc.Text = t end end
            function obj:SetVisible(v) row.Visible = v end
            function obj:Destroy() row:Destroy() end
            return obj
        end

        ------------------------------------------------------------ Section / Label / Paragraph
        function Tab:Section(text)
            local l = label(page, {
                Size = UDim2.new(1, 0, 0, 22), Text = text, TextColor3 = Theme.SubText,
                TextSize = 12, LayoutOrder = nextOrder(), TextYAlignment = Enum.TextYAlignment.Bottom,
            })
            l.Parent = page
            new("UIPadding", { PaddingLeft = UDim.new(0, 2), Parent = l })
            return { SetText = function(_, t) l.Text = t end, Destroy = function() l:Destroy() end }
        end

        function Tab:Label(text)
            local row = makeRow(34)
            local l = label(row, {
                Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -28, 1, 0),
                Text = text, TextColor3 = Theme.SubText, TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            return { Row = row, SetText = function(_, t) l.Text = t end, Destroy = function() row:Destroy() end }
        end

        function Tab:Paragraph(ecfg)
            local row = makeRow(0)
            row.AutomaticSize = Enum.AutomaticSize.Y
            row.Size = UDim2.new(1, 0, 0, 0)
            new("UIPadding", {
                PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = row,
            })
            new("UIListLayout", { Padding = UDim.new(0, 4), Parent = row })
            local t = label(row, {
                Size = UDim2.new(1, 0, 0, 16), Text = ecfg.Title or "", TextColor3 = Theme.Text,
                TextSize = 13, Font = Enum.Font.GothamBold, LayoutOrder = 1,
            })
            local d = label(row, {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                Text = ecfg.Content or ecfg.Desc or "", TextColor3 = Theme.SubText, TextSize = 12,
                Font = Enum.Font.Gotham, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
                LayoutOrder = 2,
            })
            return {
                Row = row,
                SetTitle = function(_, v) t.Text = v end,
                SetContent = function(_, v) d.Text = v end,
                Destroy = function() row:Destroy() end,
            }
        end

        ------------------------------------------------------------ Button
        function Tab:Button(ecfg)
            local hasDesc = ecfg.Desc and ecfg.Desc ~= ""
            local row = makeRow(hasDesc and 56 or 42)
            local tint = ecfg.Danger and Theme.Danger or Theme.SubText
            local ic = makeIcon(row, ecfg.Icon, 16, tint, { Position = UDim2.new(0, 14, 0.5, -8) })
            local title, desc = rowText(row, ecfg, leftOffset(ecfg), 14, hasDesc)

            local btn = new("TextButton", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
                AutoButtonColor = false, ZIndex = 5, Parent = row,
            })
            local busy = false
            btn.MouseEnter:Connect(function()
                tween(row, 0.15, { BackgroundColor3 = Theme.ElementHover })
                ic:SetColor(ecfg.Danger and Theme.Danger or Theme.Text)
            end)
            btn.MouseLeave:Connect(function()
                tween(row, 0.15, { BackgroundColor3 = Theme.Element }); ic:SetColor(tint)
            end)
            btn.MouseButton1Click:Connect(function()
                if busy then return end
                busy = true
                row.BackgroundColor3 = Theme.ElementPress
                tween(row, 0.3, { BackgroundColor3 = Theme.ElementHover })
                safe(ecfg.Callback)
                task.wait(ecfg.Cooldown or 0.3)
                busy = false
            end)
            local obj = baseObject(row, title, desc)
            function obj:Fire() safe(ecfg.Callback) end
            return obj
        end

        ------------------------------------------------------------ Toggle
        function Tab:Toggle(ecfg)
            local hasDesc = ecfg.Desc and ecfg.Desc ~= ""
            local row = makeRow(hasDesc and 56 or 42)
            makeIcon(row, ecfg.Icon, 16, Theme.SubText, { Position = UDim2.new(0, 14, 0.5, -8) })
            local title, desc = rowText(row, ecfg, leftOffset(ecfg), 70, hasDesc)

            local ON, OFF = Theme.Success, Theme.Track
            local state = ecfg.Default == true
            local track = new("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
                Size = UDim2.fromOffset(40, 22), BackgroundColor3 = state and ON or OFF,
                AutoButtonColor = false, Text = "", Parent = row,
            }, { corner(11) })
            local knob = new("Frame", {
                Position = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8),
                Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
            }, { corner(8) })

            local obj = baseObject(row, title, desc)
            local function render(animate)
                local t = animate and 0.2 or 0
                tween(track, t, { BackgroundColor3 = state and ON or OFF })
                tween(knob, t, { Position = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8) })
            end
            function obj:Set(v, silent)
                state = v and true or false
                if ecfg.Flag then Window.Flags[ecfg.Flag] = state end
                render(true)
                if not silent then safe(ecfg.Callback, state) end
            end
            function obj:Get() return state end
            if ecfg.Flag then Window.Flags[ecfg.Flag] = state end
            track.MouseButton1Click:Connect(function() obj:Set(not state) end)

            local hit = new("TextButton", {
                Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Text = "", Parent = row,
            })
            hit.MouseButton1Click:Connect(function() obj:Set(not state) end)
            return obj
        end

        ------------------------------------------------------------ Slider
        function Tab:Slider(ecfg)
            local min, max, step = ecfg.Min or 0, ecfg.Max or 100, ecfg.Step or 1
            local suffix = ecfg.Suffix or ""
            local row = makeRow(58)
            local title = label(row, {
                Position = UDim2.new(0, 14, 0, 9), Size = UDim2.new(1, -110, 0, 16),
                Text = ecfg.Title or "", TextColor3 = Theme.Text, TextSize = 13, Font = Enum.Font.GothamMedium,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local valueLabel = label(row, {
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 9),
                Size = UDim2.fromOffset(90, 16), TextColor3 = Theme.SubText, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
            local track = new("Frame", {
                Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 6),
                BackgroundColor3 = Theme.Track, Parent = row,
            }, { corner(3) })
            local fill = new("Frame", {
                Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Text, Parent = track,
            }, { corner(3) })
            local knob = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
            }, { corner(7) })

            local value = min
            local obj = baseObject(row, title, nil)
            local function fmt(v) return tostring(math.floor(v * 1000 + 0.5) / 1000) .. suffix end
            local function render(animate)
                local a = (max == min) and 0 or (value - min) / (max - min)
                local t = animate and 0.08 or 0
                tween(fill, t, { Size = UDim2.fromScale(a, 1) })
                tween(knob, t, { Position = UDim2.fromScale(a, 0.5) })
                valueLabel.Text = fmt(value)
            end
            function obj:Set(v, silent)
                v = math.clamp(tonumber(v) or min, min, max)
                v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
                local changed = v ~= value
                value = v
                if ecfg.Flag then Window.Flags[ecfg.Flag] = value end
                render(true)
                if changed and not silent then safe(ecfg.Callback, value) end
            end
            function obj:Get() return value end
            value = math.clamp(ecfg.Default or min, min, max)
            render(false)
            if ecfg.Flag then Window.Flags[ecfg.Flag] = value end

            local dragging = false
            local function fromInput(input)
                local a = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                obj:Set(min + (max - min) * a)
            end
            local hit = new("TextButton", {
                Position = UDim2.new(0, 8, 0, 28), Size = UDim2.new(1, -16, 0, 26),
                BackgroundTransparency = 1, Text = "", Parent = row,
            })
            hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    fromInput(input)
                    local c; c = input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                            dragging = false; c:Disconnect()
                        end
                    end)
                end
            end)
            connect(UserInputService.InputChanged, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    fromInput(input)
                end
            end)
            return obj
        end

        ------------------------------------------------------------ Input
        function Tab:Input(ecfg)
            local hasDesc = ecfg.Desc and ecfg.Desc ~= ""
            local row = makeRow(hasDesc and 56 or 42)
            makeIcon(row, ecfg.Icon, 16, Theme.SubText, { Position = UDim2.new(0, 14, 0.5, -8) })
            local title, desc = rowText(row, ecfg, leftOffset(ecfg), 170, hasDesc)

            local box = new("TextBox", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(150, 28), BackgroundColor3 = Theme.Panel,
                PlaceholderText = ecfg.Placeholder or "...", PlaceholderColor3 = Theme.Placeholder,
                Text = ecfg.Default or "", TextColor3 = Theme.Text, TextSize = 12, Font = Enum.Font.Gotham,
                ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
            }, { corner(8), stroke(OUTLINE_T), pad(8, 0) })
            local boxStroke = box:FindFirstChildOfClass("UIStroke")
            box.Focused:Connect(function() tween(boxStroke, 0.15, { Transparency = 0.6 }) end)
            box.FocusLost:Connect(function(enter)
                tween(boxStroke, 0.15, { Transparency = OUTLINE_T })
                if ecfg.Numeric then
                    local n = tonumber(box.Text)
                    if n then safe(ecfg.Callback, n) else box.Text = "" end
                elseif enter or ecfg.CallbackOnBlur then
                    safe(ecfg.Callback, box.Text)
                end
                if ecfg.ClearOnSubmit and enter then box.Text = "" end
            end)

            local obj = baseObject(row, title, desc)
            function obj:Set(v) box.Text = tostring(v) end
            function obj:Get() return box.Text end
            return obj
        end

        ------------------------------------------------------------ Keybind
        function Tab:Keybind(ecfg)
            local hasDesc = ecfg.Desc and ecfg.Desc ~= ""
            local row = makeRow(hasDesc and 56 or 42)
            makeIcon(row, ecfg.Icon, 16, Theme.SubText, { Position = UDim2.new(0, 14, 0.5, -8) })
            local title, desc = rowText(row, ecfg, leftOffset(ecfg), 110, hasDesc)

            local key = ecfg.Default or Enum.KeyCode.Unknown
            local listening = false
            local btn = new("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(90, 28), BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
                Text = "", Parent = row,
            }, { corner(8), stroke(OUTLINE_T) })
            local keyLabel = label(btn, {
                Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
                TextColor3 = Theme.Text, TextSize = 12,
            })
            local function render()
                keyLabel.Text = listening and "..." or (key == Enum.KeyCode.Unknown and "Nenhuma" or key.Name)
            end
            render()

            local obj = baseObject(row, title, desc)
            function obj:Set(k) key = k or Enum.KeyCode.Unknown; render() end
            function obj:Get() return key end
            btn.MouseButton1Click:Connect(function() listening = true; render() end)
            connect(UserInputService.InputBegan, function(input, processed)
                if listening then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        key = (input.KeyCode == Enum.KeyCode.Escape) and Enum.KeyCode.Unknown or input.KeyCode
                        listening = false
                        render()
                        if ecfg.Changed then safe(ecfg.Changed, key) end
                    end
                elseif not processed and key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
                    safe(ecfg.Callback, key)
                end
            end)
            return obj
        end

        ------------------------------------------------------------ Dropdown
        function Tab:Dropdown(ecfg)
            local values = ecfg.Values or {}
            local multi = ecfg.Multi == true
            local MAXVISIBLE, OPT_H = 6, 30
            local selected = multi and {} or nil
            local open = false

            local row = makeRow(42)
            row.ClipsDescendants = true
            makeIcon(row, ecfg.Icon, 16, Theme.SubText, { Position = UDim2.new(0, 14, 0, 13) })
            local title = label(row, {
                Position = UDim2.new(0, leftOffset(ecfg), 0, 0),
                Size = UDim2.new(0.5, -leftOffset(ecfg), 0, 42), Text = ecfg.Title or "",
                TextColor3 = Theme.Text, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local valueLabel = label(row, {
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 0),
                Size = UDim2.new(0.5, -50, 0, 42), TextColor3 = Theme.SubText, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local chevron = makeIcon(row, "chevron-down", 16, Theme.SubText,
                { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 13) })

            local header = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Text = "",
                AutoButtonColor = false, ZIndex = 5, Parent = row,
            })
            local list = new("ScrollingFrame", {
                Position = UDim2.new(0, 8, 0, 48), Size = UDim2.new(1, -16, 0, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
                ScrollBarImageColor3 = Theme.SubText, ScrollBarImageTransparency = 0.5,
                AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = row,
            }, { new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

            local obj = baseObject(row, title, nil)

            local function isSelected(v)
                if multi then return selected[v] == true end
                return selected == v
            end
            local function renderValue()
                if multi then
                    local names = {}
                    for _, v in ipairs(values) do if selected[v] then table.insert(names, tostring(v)) end end
                    valueLabel.Text = #names > 0 and table.concat(names, ", ") or (ecfg.Placeholder or "Selecionar")
                else
                    valueLabel.Text = selected ~= nil and tostring(selected) or (ecfg.Placeholder or "Selecionar")
                end
                valueLabel.TextColor3 = (multi and next(selected) or (not multi and selected ~= nil))
                    and Theme.Text or Theme.SubText
            end

            local function openHeight()
                return 42 + 8 + math.min(#values, MAXVISIBLE) * (OPT_H + 2) + 6
            end
            local function setOpen(v)
                open = v
                tween(row, 0.22, { Size = UDim2.new(1, 0, 0, open and openHeight() or 42) })
                tween(list, 0.22, { Size = UDim2.new(1, -16, 0, math.min(#values, MAXVISIBLE) * (OPT_H + 2)) })
                tween(chevron.Frame, 0.2, { Rotation = open and 180 or 0 })
            end

            local function build()
                for _, c in ipairs(list:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                for i, v in ipairs(values) do
                    local opt = new("TextButton", {
                        Size = UDim2.new(1, -6, 0, OPT_H), BackgroundColor3 = Theme.Outline,
                        BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
                        LayoutOrder = i, Parent = list,
                    }, { corner(8) })
                    local txt = label(opt, {
                        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -40, 1, 0),
                        Text = tostring(v), TextSize = 12,
                        TextColor3 = isSelected(v) and Theme.Text or Theme.SubText,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                    })
                    local check = makeIcon(opt, "check", 14, Theme.Text,
                        { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) })
                    check.Frame.Visible = isSelected(v)
                    if isSelected(v) then opt.BackgroundTransparency = 0.94 end

                    opt.MouseEnter:Connect(function() tween(opt, 0.12, { BackgroundTransparency = 0.92 }) end)
                    opt.MouseLeave:Connect(function()
                        tween(opt, 0.12, { BackgroundTransparency = isSelected(v) and 0.94 or 1 })
                    end)
                    opt.MouseButton1Click:Connect(function()
                        if multi then
                            selected[v] = (not selected[v]) or nil
                            check.Frame.Visible = selected[v] == true
                            txt.TextColor3 = selected[v] and Theme.Text or Theme.SubText
                            renderValue()
                            local out = {}
                            for _, x in ipairs(values) do if selected[x] then table.insert(out, x) end end
                            if ecfg.Flag then Window.Flags[ecfg.Flag] = out end
                            safe(ecfg.Callback, out)
                        else
                            selected = v
                            if ecfg.Flag then Window.Flags[ecfg.Flag] = v end
                            renderValue()
                            build()
                            setOpen(false)
                            safe(ecfg.Callback, v)
                        end
                    end)
                end
            end

            function obj:Get()
                if multi then
                    local out = {}
                    for _, x in ipairs(values) do if selected[x] then table.insert(out, x) end end
                    return out
                end
                return selected
            end
            function obj:Set(v, silent)
                if multi then
                    selected = {}
                    for _, x in ipairs(type(v) == "table" and v or { v }) do selected[x] = true end
                else
                    selected = v
                end
                renderValue(); build()
                if not silent then safe(ecfg.Callback, obj:Get()) end
            end
            function obj:Refresh(newValues)
                values = newValues or {}
                if multi then
                    for k in pairs(selected) do if not table.find(values, k) then selected[k] = nil end end
                elseif selected ~= nil and not table.find(values, selected) then
                    selected = nil
                end
                renderValue(); build()
                if open then setOpen(true) end
            end
            function obj:Open() setOpen(true) end
            function obj:Close() setOpen(false) end

            header.MouseEnter:Connect(function() if not open then tween(row, 0.15, { BackgroundColor3 = Theme.ElementHover }) end end)
            header.MouseLeave:Connect(function() tween(row, 0.15, { BackgroundColor3 = Theme.Element }) end)
            header.MouseButton1Click:Connect(function() setOpen(not open) end)

            if ecfg.Default ~= nil then
                if multi then
                    for _, x in ipairs(type(ecfg.Default) == "table" and ecfg.Default or { ecfg.Default }) do selected[x] = true end
                else
                    selected = ecfg.Default
                end
            end
            renderValue(); build()
            return obj
        end

        return Tab
    end

    ---------------------------------------------------------------- visibilidade / ciclo de vida
    function Window:SetVisible(v)
        if v == Window._visible then return end
        Window._visible = v
        local target = baseScale()
        if v then
            main.Visible = true
            if animations then
                uiScale.Scale = target * 0.96
                tween(uiScale, 0.25, { Scale = target })
            else
                uiScale.Scale = target
            end
        else
            if animations then tween(uiScale, 0.15, { Scale = target * 0.96 }).Completed:Wait() end
            if not Window._visible then main.Visible = false end
        end
    end
    function Window:Toggle() Window:SetVisible(not Window._visible) end

    function Window:Destroy()
        if Window._destroyed then return end
        Window._destroyed = true
        if animations and gui.Parent then
            tween(uiScale, 0.15, { Scale = baseScale() * 0.94 }).Completed:Wait()
        end
        for _, c in ipairs(Window._conns) do c:Disconnect() end
        gui:Destroy()
        if cfg.OnClose then safe(cfg.OnClose) end
    end

    closeBtn.MouseButton1Click:Connect(function() Window:Destroy() end)
    minBtn.MouseButton1Click:Connect(function()
        Window._minimized = not Window._minimized
        minIcon:SetIcon(Window._minimized and "plus" or "minus")
        if Window._minimized then
            body.Visible = false
            tween(main, 0.2, { Size = UDim2.fromOffset(WIDTH, HEADER) })
        else
            body.Visible = true
            tween(main, 0.2, { Size = UDim2.fromOffset(WIDTH, HEIGHT) })
        end
    end)

    connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == toggleKey then Window:Toggle() end
    end)

    if animations then
        local target = uiScale.Scale
        uiScale.Scale = target * 0.95
        tween(uiScale, 0.35, { Scale = target })
    end

    table.insert(Library.Windows, Window)
    return Window
end

pcall(function()
    local env = (getgenv and getgenv()) or _G
    env.DryzLib = Library
end)

return Library
