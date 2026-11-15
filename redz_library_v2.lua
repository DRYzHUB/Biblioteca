--[[
	redz library V5 - Remastered
	Version 2.0.0

	Highlights
	  * Full touch + mouse support (drag, resize, sliders, color picker)
	  * Animated theme switching, 10 built-in themes and :AddTheme()
	  * Notifications, Keybind, ColorPicker, Divider, Label, Config Manager
	  * Dropdown rewrite (single / multi select, search, live refresh)
	  * Slider rewrite (decimals, typed input, clamped values)
	  * Element search bar, per-element locking, toggle key, mobile button
	  * Safe file IO (auto folders, Color3/KeyCode serialization, debounce)
	  * Proper cleanup of every connection (Window:Destroy)
	  * Backwards compatible with the original V5 API
]]

local cloneref = cloneref or function(Obj)
	return Obj
end

local function GetService(Name)
	return cloneref(game:GetService(Name))
end

local UserInputService = GetService("UserInputService")
local TweenService = GetService("TweenService")
local HttpService = GetService("HttpService")
local Players = GetService("Players")

local Player = Players.LocalPlayer

-- Executor functions (every one of them is optional)
local Env = {
	ReadFile = readfile,
	WriteFile = writefile,
	IsFile = isfile,
	IsFolder = isfolder,
	MakeFolder = makefolder,
	ListFiles = listfiles,
	DelFile = delfile,
	SetClipboard = setclipboard or toclipboard or (syn and syn.write_clipboard),
	Request = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request),
	ProtectGui = (syn and syn.protect_gui) or protect_gui,
}

local function GetGuiParent()
	local Candidates = {
		function()
			return gethui and gethui()
		end,
		function()
			return GetService("CoreGui")
		end,
	}

	for _, Get in ipairs(Candidates) do
		local Ok, Parent = pcall(Get)
		if Ok and Parent then
			local Probe = Instance.new("Folder")
			local CanParent = pcall(function()
				Probe.Parent = Parent
			end)
			Probe:Destroy()
			if CanParent then
				return Parent
			end
		end
	end

	return Player:WaitForChild("PlayerGui")
end

-- ThemeData: Edge / Center are the gradient colors of the window
local function NewTheme(Edge, Center, Hub2, Stroke, Accent, Text, DarkText)
	return {
		["Color Hub 1"] = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Edge),
			ColorSequenceKeypoint.new(0.50, Center),
			ColorSequenceKeypoint.new(1.00, Edge)
		}),
		["Color Hub 2"] = Hub2,
		["Color Stroke"] = Stroke,
		["Color Theme"] = Accent,
		["Color Text"] = Text,
		["Color Dark Text"] = DarkText
	}
end

local redzlib = {
	Themes = {
		-- Original themes
		Darker = NewTheme(Color3.fromRGB(25, 25, 25), Color3.fromRGB(32.5, 32.5, 32.5), Color3.fromRGB(30, 30, 30), Color3.fromRGB(40, 40, 40), Color3.fromRGB(88, 101, 242), Color3.fromRGB(243, 243, 243), Color3.fromRGB(180, 180, 180)),
		Dark = NewTheme(Color3.fromRGB(40, 40, 40), Color3.fromRGB(47.5, 47.5, 47.5), Color3.fromRGB(45, 45, 45), Color3.fromRGB(65, 65, 65), Color3.fromRGB(65, 150, 255), Color3.fromRGB(245, 245, 245), Color3.fromRGB(190, 190, 190)),
		Purple = NewTheme(Color3.fromRGB(27.5, 25, 30), Color3.fromRGB(32.5, 32.5, 32.5), Color3.fromRGB(30, 30, 30), Color3.fromRGB(40, 40, 40), Color3.fromRGB(150, 0, 255), Color3.fromRGB(240, 240, 240), Color3.fromRGB(180, 180, 180)),
		-- New themes
		Midnight = NewTheme(Color3.fromRGB(12, 14, 24), Color3.fromRGB(18, 21, 36), Color3.fromRGB(22, 26, 44), Color3.fromRGB(34, 40, 66), Color3.fromRGB(96, 130, 255), Color3.fromRGB(235, 238, 250), Color3.fromRGB(150, 158, 185)),
		Ocean = NewTheme(Color3.fromRGB(12, 24, 30), Color3.fromRGB(16, 34, 42), Color3.fromRGB(20, 40, 50), Color3.fromRGB(32, 62, 76), Color3.fromRGB(0, 190, 210), Color3.fromRGB(235, 248, 250), Color3.fromRGB(150, 180, 188)),
		Rose = NewTheme(Color3.fromRGB(28, 18, 22), Color3.fromRGB(36, 22, 28), Color3.fromRGB(42, 26, 33), Color3.fromRGB(66, 40, 50), Color3.fromRGB(255, 90, 140), Color3.fromRGB(250, 238, 242), Color3.fromRGB(190, 160, 170)),
		Emerald = NewTheme(Color3.fromRGB(14, 26, 20), Color3.fromRGB(18, 34, 26), Color3.fromRGB(22, 40, 30), Color3.fromRGB(34, 62, 46), Color3.fromRGB(46, 204, 113), Color3.fromRGB(236, 250, 242), Color3.fromRGB(154, 186, 166)),
		Amoled = NewTheme(Color3.fromRGB(0, 0, 0), Color3.fromRGB(6, 6, 6), Color3.fromRGB(14, 14, 14), Color3.fromRGB(30, 30, 30), Color3.fromRGB(140, 110, 255), Color3.fromRGB(245, 245, 245), Color3.fromRGB(160, 160, 160)),
		Light = NewTheme(Color3.fromRGB(238, 238, 242), Color3.fromRGB(248, 248, 250), Color3.fromRGB(228, 228, 234), Color3.fromRGB(205, 205, 214), Color3.fromRGB(64, 120, 255), Color3.fromRGB(28, 28, 34), Color3.fromRGB(100, 100, 112)),
	},
	Info = {
		Version = "2.0.0"
	},
	Save = {
		UISize = {550, 380},
		TabSize = 160,
		Theme = "Darker",
		Scale = false
	},
	Settings = {
		FileName = "redz library V5.json",
		ConfigFolder = "redz library/configs",
		ScriptFile = false
	},
	Connection = {},
	Instances = setmetatable({}, {__mode = "k"}),
	Elements = {},
	Options = {},
	Flags = {},
	Setters = {},
	Tabs = {},
	Icons = (function()
	  -- This file was @generated by Tarmac. It is not intended for manual editing.
		return {
			["accessibility"] = "rbxassetid://10709751939",
			["activity"] = "rbxassetid://10709752035",
			["airvent"] = "rbxassetid://10709752131",
			["airplay"] = "rbxassetid://10709752254",
			["alarmcheck"] = "rbxassetid://10709752405",
			["alarmclock"] = "rbxassetid://10709752630",
			["alarmclockoff"] = "rbxassetid://10709752508",
			["alarmminus"] = "rbxassetid://10709752732",
			["alarmplus"] = "rbxassetid://10709752825",
			["album"] = "rbxassetid://10709752906",
			["alertcircle"] = "rbxassetid://10709752996",
			["alertoctagon"] = "rbxassetid://10709753064",
			["alerttriangle"] = "rbxassetid://10709753149",
			["aligncenter"] = "rbxassetid://10709753570",
			["aligncenterhorizontal"] = "rbxassetid://10709753272",
			["aligncentervertical"] = "rbxassetid://10709753421",
			["alignendhorizontal"] = "rbxassetid://10709753692",
			["alignendvertical"] = "rbxassetid://10709753808",
			["alignhorizontaldistributecenter"] = "rbxassetid://10747779791",
			["alignhorizontaldistributeend"] = "rbxassetid://10747784534",
			["alignhorizontaldistributestart"] = "rbxassetid://10709754118",
			["alignhorizontaljustifycenter"] = "rbxassetid://10709754204",
			["alignhorizontaljustifyend"] = "rbxassetid://10709754317",
			["alignhorizontaljustifystart"] = "rbxassetid://10709754436",
			["alignhorizontalspacearound"] = "rbxassetid://10709754590",
			["alignhorizontalspacebetween"] = "rbxassetid://10709754749",
			["alignjustify"] = "rbxassetid://10709759610",
			["alignleft"] = "rbxassetid://10709759764",
			["alignright"] = "rbxassetid://10709759895",
			["alignstarthorizontal"] = "rbxassetid://10709760051",
			["alignstartvertical"] = "rbxassetid://10709760244",
			["alignverticaldistributecenter"] = "rbxassetid://10709760351",
			["alignverticaldistributeend"] = "rbxassetid://10709760434",
			["alignverticaldistributestart"] = "rbxassetid://10709760612",
			["alignverticaljustifycenter"] = "rbxassetid://10709760814",
			["alignverticaljustifyend"] = "rbxassetid://10709761003",
			["alignverticaljustifystart"] = "rbxassetid://10709761176",
			["alignverticalspacearound"] = "rbxassetid://10709761324",
			["alignverticalspacebetween"] = "rbxassetid://10709761434",
			["anchor"] = "rbxassetid://10709761530",
			["angry"] = "rbxassetid://10709761629",
			["annoyed"] = "rbxassetid://10709761722",
			["aperture"] = "rbxassetid://10709761813",
			["apple"] = "rbxassetid://10709761889",
			["archive"] = "rbxassetid://10709762233",
			["archiverestore"] = "rbxassetid://10709762058",
			["armchair"] = "rbxassetid://10709762327",
			["arrowbigdown"] = "rbxassetid://10747796644",
			["arrowbigleft"] = "rbxassetid://10709762574",
			["arrowbigright"] = "rbxassetid://10709762727",
			["arrowbigup"] = "rbxassetid://10709762879",
			["arrowdown"] = "rbxassetid://10709767827",
			["arrowdowncircle"] = "rbxassetid://10709763034",
			["arrowdownleft"] = "rbxassetid://10709767656",
			["arrowdownright"] = "rbxassetid://10709767750",
			["arrowleft"] = "rbxassetid://10709768114",
			["arrowleftcircle"] = "rbxassetid://10709767936",
			["arrowleftright"] = "rbxassetid://10709768019",
			["arrowright"] = "rbxassetid://10709768347",
			["arrowrightcircle"] = "rbxassetid://10709768226",
			["arrowup"] = "rbxassetid://10709768939",
			["arrowupcircle"] = "rbxassetid://10709768432",
			["arrowupdown"] = "rbxassetid://10709768538",
			["arrowupleft"] = "rbxassetid://10709768661",
			["arrowupright"] = "rbxassetid://10709768787",
			["asterisk"] = "rbxassetid://10709769095",
			["atsign"] = "rbxassetid://10709769286",
			["award"] = "rbxassetid://10709769406",
			["axe"] = "rbxassetid://10709769508",
			["axis3d"] = "rbxassetid://10709769598",
			["baby"] = "rbxassetid://10709769732",
			["backpack"] = "rbxassetid://10709769841",
			["baggageclaim"] = "rbxassetid://10709769935",
			["banana"] = "rbxassetid://10709770005",
			["banknote"] = "rbxassetid://10709770178",
			["barchart"] = "rbxassetid://10709773755",
			["barchart2"] = "rbxassetid://10709770317",
			["barchart3"] = "rbxassetid://10709770431",
			["barchart4"] = "rbxassetid://10709770560",
			["barcharthorizontal"] = "rbxassetid://10709773669",
			["barcode"] = "rbxassetid://10747360675",
			["baseline"] = "rbxassetid://10709773863",
			["bath"] = "rbxassetid://10709773963",
			["battery"] = "rbxassetid://10709774640",
			["batterycharging"] = "rbxassetid://10709774068",
			["batteryfull"] = "rbxassetid://10709774206",
			["batterylow"] = "rbxassetid://10709774370",
			["batterymedium"] = "rbxassetid://10709774513",
			["beaker"] = "rbxassetid://10709774756",
			["bed"] = "rbxassetid://10709775036",
			["beddouble"] = "rbxassetid://10709774864",
			["bedsingle"] = "rbxassetid://10709774968",
			["beer"] = "rbxassetid://10709775167",
			["bell"] = "rbxassetid://10709775704",
			["bellminus"] = "rbxassetid://10709775241",
			["belloff"] = "rbxassetid://10709775320",
			["bellplus"] = "rbxassetid://10709775448",
			["bellring"] = "rbxassetid://10709775560",
			["bike"] = "rbxassetid://10709775894",
			["binary"] = "rbxassetid://10709776050",
			["bitcoin"] = "rbxassetid://10709776126",
			["bluetooth"] = "rbxassetid://10709776655",
			["bluetoothconnected"] = "rbxassetid://10709776240",
			["bluetoothoff"] = "rbxassetid://10709776344",
			["bluetoothsearching"] = "rbxassetid://10709776501",
			["bold"] = "rbxassetid://10747813908",
			["bomb"] = "rbxassetid://10709781460",
			["bone"] = "rbxassetid://10709781605",
			["book"] = "rbxassetid://10709781824",
			["bookopen"] = "rbxassetid://10709781717",
			["bookmark"] = "rbxassetid://10709782154",
			["bookmarkminus"] = "rbxassetid://10709781919",
			["bookmarkplus"] = "rbxassetid://10709782044",
			["bot"] = "rbxassetid://10709782230",
			["box"] = "rbxassetid://10709782497",
			["boxselect"] = "rbxassetid://10709782342",
			["boxes"] = "rbxassetid://10709782582",
			["briefcase"] = "rbxassetid://10709782662",
			["brush"] = "rbxassetid://10709782758",
			["bug"] = "rbxassetid://10709782845",
			["building"] = "rbxassetid://10709783051",
			["building2"] = "rbxassetid://10709782939",
			["bus"] = "rbxassetid://10709783137",
			["cake"] = "rbxassetid://10709783217",
			["calculator"] = "rbxassetid://10709783311",
			["calendar"] = "rbxassetid://10709789505",
			["calendarcheck"] = "rbxassetid://10709783474",
			["calendarcheck2"] = "rbxassetid://10709783392",
			["calendarclock"] = "rbxassetid://10709783577",
			["calendardays"] = "rbxassetid://10709783673",
			["calendarheart"] = "rbxassetid://10709783835",
			["calendarminus"] = "rbxassetid://10709783959",
			["calendaroff"] = "rbxassetid://10709788784",
			["calendarplus"] = "rbxassetid://10709788937",
			["calendarrange"] = "rbxassetid://10709789053",
			["calendarsearch"] = "rbxassetid://10709789200",
			["calendarx"] = "rbxassetid://10709789407",
			["calendarx2"] = "rbxassetid://10709789329",
			["camera"] = "rbxassetid://10709789686",
			["cameraoff"] = "rbxassetid://10747822677",
			["car"] = "rbxassetid://10709789810",
			["carrot"] = "rbxassetid://10709789960",
			["cast"] = "rbxassetid://10709790097",
			["charge"] = "rbxassetid://10709790202",
			["check"] = "rbxassetid://10709790644",
			["checkcircle"] = "rbxassetid://10709790387",
			["checkcircle2"] = "rbxassetid://10709790298",
			["checksquare"] = "rbxassetid://10709790537",
			["chefhat"] = "rbxassetid://10709790757",
			["cherry"] = "rbxassetid://10709790875",
			["chevrondown"] = "rbxassetid://10709790948",
			["chevronfirst"] = "rbxassetid://10709791015",
			["chevronlast"] = "rbxassetid://10709791130",
			["chevronleft"] = "rbxassetid://10709791281",
			["chevronright"] = "rbxassetid://10709791437",
			["chevronup"] = "rbxassetid://10709791523",
			["chevronsdown"] = "rbxassetid://10709796864",
			["chevronsdownup"] = "rbxassetid://10709791632",
			["chevronsleft"] = "rbxassetid://10709797151",
			["chevronsleftright"] = "rbxassetid://10709797006",
			["chevronsright"] = "rbxassetid://10709797382",
			["chevronsrightleft"] = "rbxassetid://10709797274",
			["chevronsup"] = "rbxassetid://10709797622",
			["chevronsupdown"] = "rbxassetid://10709797508",
			["chrome"] = "rbxassetid://10709797725",
			["circle"] = "rbxassetid://10709798174",
			["circledot"] = "rbxassetid://10709797837",
			["circleellipsis"] = "rbxassetid://10709797985",
			["circleslashed"] = "rbxassetid://10709798100",
			["citrus"] = "rbxassetid://10709798276",
			["clapperboard"] = "rbxassetid://10709798350",
			["clipboard"] = "rbxassetid://10709799288",
			["clipboardcheck"] = "rbxassetid://10709798443",
			["clipboardcopy"] = "rbxassetid://10709798574",
			["clipboardedit"] = "rbxassetid://10709798682",
			["clipboardlist"] = "rbxassetid://10709798792",
			["clipboardsignature"] = "rbxassetid://10709798890",
			["clipboardtype"] = "rbxassetid://10709798999",
			["clipboardx"] = "rbxassetid://10709799124",
			["clock"] = "rbxassetid://10709805144",
			["clock1"] = "rbxassetid://10709799535",
			["clock10"] = "rbxassetid://10709799718",
			["clock11"] = "rbxassetid://10709799818",
			["clock12"] = "rbxassetid://10709799962",
			["clock2"] = "rbxassetid://10709803876",
			["clock3"] = "rbxassetid://10709803989",
			["clock4"] = "rbxassetid://10709804164",
			["clock5"] = "rbxassetid://10709804291",
			["clock6"] = "rbxassetid://10709804435",
			["clock7"] = "rbxassetid://10709804599",
			["clock8"] = "rbxassetid://10709804784",
			["clock9"] = "rbxassetid://10709804996",
			["cloud"] = "rbxassetid://10709806740",
			["cloudcog"] = "rbxassetid://10709805262",
			["clouddrizzle"] = "rbxassetid://10709805371",
			["cloudfog"] = "rbxassetid://10709805477",
			["cloudhail"] = "rbxassetid://10709805596",
			["cloudlightning"] = "rbxassetid://10709805727",
			["cloudmoon"] = "rbxassetid://10709805942",
			["cloudmoonrain"] = "rbxassetid://10709805838",
			["cloudoff"] = "rbxassetid://10709806060",
			["cloudrain"] = "rbxassetid://10709806277",
			["cloudrainwind"] = "rbxassetid://10709806166",
			["cloudsnow"] = "rbxassetid://10709806374",
			["cloudsun"] = "rbxassetid://10709806631",
			["cloudsunrain"] = "rbxassetid://10709806475",
			["cloudy"] = "rbxassetid://10709806859",
			["clover"] = "rbxassetid://10709806995",
			["code"] = "rbxassetid://10709810463",
			["code2"] = "rbxassetid://10709807111",
			["codepen"] = "rbxassetid://10709810534",
			["codesandbox"] = "rbxassetid://10709810676",
			["coffee"] = "rbxassetid://10709810814",
			["cog"] = "rbxassetid://10709810948",
			["coins"] = "rbxassetid://10709811110",
			["columns"] = "rbxassetid://10709811261",
			["command"] = "rbxassetid://10709811365",
			["compass"] = "rbxassetid://10709811445",
			["component"] = "rbxassetid://10709811595",
			["conciergebell"] = "rbxassetid://10709811706",
			["connection"] = "rbxassetid://10747361219",
			["contact"] = "rbxassetid://10709811834",
			["contrast"] = "rbxassetid://10709811939",
			["cookie"] = "rbxassetid://10709812067",
			["copy"] = "rbxassetid://10709812159",
			["copyleft"] = "rbxassetid://10709812251",
			["copyright"] = "rbxassetid://10709812311",
			["cornerdownleft"] = "rbxassetid://10709812396",
			["cornerdownright"] = "rbxassetid://10709812485",
			["cornerleftdown"] = "rbxassetid://10709812632",
			["cornerleftup"] = "rbxassetid://10709812784",
			["cornerrightdown"] = "rbxassetid://10709812939",
			["cornerrightup"] = "rbxassetid://10709813094",
			["cornerupleft"] = "rbxassetid://10709813185",
			["cornerupright"] = "rbxassetid://10709813281",
			["cpu"] = "rbxassetid://10709813383",
			["croissant"] = "rbxassetid://10709818125",
			["crop"] = "rbxassetid://10709818245",
			["cross"] = "rbxassetid://10709818399",
			["crosshair"] = "rbxassetid://10709818534",
			["crown"] = "rbxassetid://10709818626",
			["cupsoda"] = "rbxassetid://10709818763",
			["curlybraces"] = "rbxassetid://10709818847",
			["currency"] = "rbxassetid://10709818931",
			["database"] = "rbxassetid://10709818996",
			["delete"] = "rbxassetid://10709819059",
			["diamond"] = "rbxassetid://10709819149",
			["dice1"] = "rbxassetid://10709819266",
			["dice2"] = "rbxassetid://10709819361",
			["dice3"] = "rbxassetid://10709819508",
			["dice4"] = "rbxassetid://10709819670",
			["dice5"] = "rbxassetid://10709819801",
			["dice6"] = "rbxassetid://10709819896",
			["dices"] = "rbxassetid://10723343321",
			["diff"] = "rbxassetid://10723343416",
			["disc"] = "rbxassetid://10723343537",
			["divide"] = "rbxassetid://10723343805",
			["dividecircle"] = "rbxassetid://10723343636",
			["dividesquare"] = "rbxassetid://10723343737",
			["dollarsign"] = "rbxassetid://10723343958",
			["download"] = "rbxassetid://10723344270",
			["downloadcloud"] = "rbxassetid://10723344088",
			["droplet"] = "rbxassetid://10723344432",
			["droplets"] = "rbxassetid://10734883356",
			["drumstick"] = "rbxassetid://10723344737",
			["edit"] = "rbxassetid://10734883598",
			["edit2"] = "rbxassetid://10723344885",
			["edit3"] = "rbxassetid://10723345088",
			["egg"] = "rbxassetid://10723345518",
			["eggfried"] = "rbxassetid://10723345347",
			["electricity"] = "rbxassetid://10723345749",
			["electricityoff"] = "rbxassetid://10723345643",
			["equal"] = "rbxassetid://10723345990",
			["equalnot"] = "rbxassetid://10723345866",
			["eraser"] = "rbxassetid://10723346158",
			["euro"] = "rbxassetid://10723346372",
			["expand"] = "rbxassetid://10723346553",
			["externallink"] = "rbxassetid://10723346684",
			["eye"] = "rbxassetid://10723346959",
			["eyeoff"] = "rbxassetid://10723346871",
			["factory"] = "rbxassetid://10723347051",
			["fan"] = "rbxassetid://10723354359",
			["fastforward"] = "rbxassetid://10723354521",
			["feather"] = "rbxassetid://10723354671",
			["figma"] = "rbxassetid://10723354801",
			["file"] = "rbxassetid://10723374641",
			["filearchive"] = "rbxassetid://10723354921",
			["fileaudio"] = "rbxassetid://10723355148",
			["fileaudio2"] = "rbxassetid://10723355026",
			["fileaxis3d"] = "rbxassetid://10723355272",
			["filebadge"] = "rbxassetid://10723355622",
			["filebadge2"] = "rbxassetid://10723355451",
			["filebarchart"] = "rbxassetid://10723355887",
			["filebarchart2"] = "rbxassetid://10723355746",
			["filebox"] = "rbxassetid://10723355989",
			["filecheck"] = "rbxassetid://10723356210",
			["filecheck2"] = "rbxassetid://10723356100",
			["fileclock"] = "rbxassetid://10723356329",
			["filecode"] = "rbxassetid://10723356507",
			["filecog"] = "rbxassetid://10723356830",
			["filecog2"] = "rbxassetid://10723356676",
			["filediff"] = "rbxassetid://10723357039",
			["filedigit"] = "rbxassetid://10723357151",
			["filedown"] = "rbxassetid://10723357322",
			["fileedit"] = "rbxassetid://10723357495",
			["fileheart"] = "rbxassetid://10723357637",
			["fileimage"] = "rbxassetid://10723357790",
			["fileinput"] = "rbxassetid://10723357933",
			["filejson"] = "rbxassetid://10723364435",
			["filejson2"] = "rbxassetid://10723364361",
			["filekey"] = "rbxassetid://10723364605",
			["filekey2"] = "rbxassetid://10723364515",
			["filelinechart"] = "rbxassetid://10723364725",
			["filelock"] = "rbxassetid://10723364957",
			["filelock2"] = "rbxassetid://10723364861",
			["fileminus"] = "rbxassetid://10723365254",
			["fileminus2"] = "rbxassetid://10723365086",
			["fileoutput"] = "rbxassetid://10723365457",
			["filepiechart"] = "rbxassetid://10723365598",
			["fileplus"] = "rbxassetid://10723365877",
			["fileplus2"] = "rbxassetid://10723365766",
			["filequestion"] = "rbxassetid://10723365987",
			["filescan"] = "rbxassetid://10723366167",
			["filesearch"] = "rbxassetid://10723366550",
			["filesearch2"] = "rbxassetid://10723366340",
			["filesignature"] = "rbxassetid://10723366741",
			["filespreadsheet"] = "rbxassetid://10723366962",
			["filesymlink"] = "rbxassetid://10723367098",
			["fileterminal"] = "rbxassetid://10723367244",
			["filetext"] = "rbxassetid://10723367380",
			["filetype"] = "rbxassetid://10723367606",
			["filetype2"] = "rbxassetid://10723367509",
			["fileup"] = "rbxassetid://10723367734",
			["filevideo"] = "rbxassetid://10723373884",
			["filevideo2"] = "rbxassetid://10723367834",
			["filevolume"] = "rbxassetid://10723374172",
			["filevolume2"] = "rbxassetid://10723374030",
			["filewarning"] = "rbxassetid://10723374276",
			["filex"] = "rbxassetid://10723374544",
			["filex2"] = "rbxassetid://10723374378",
			["files"] = "rbxassetid://10723374759",
			["film"] = "rbxassetid://10723374981",
			["filter"] = "rbxassetid://10723375128",
			["fingerprint"] = "rbxassetid://10723375250",
			["flag"] = "rbxassetid://10723375890",
			["flagoff"] = "rbxassetid://10723375443",
			["flagtriangleleft"] = "rbxassetid://10723375608",
			["flagtriangleright"] = "rbxassetid://10723375727",
			["flame"] = "rbxassetid://10723376114",
			["flashlight"] = "rbxassetid://10723376471",
			["flashlightoff"] = "rbxassetid://10723376365",
			["flaskconical"] = "rbxassetid://10734883986",
			["flaskround"] = "rbxassetid://10723376614",
			["fliphorizontal"] = "rbxassetid://10723376884",
			["fliphorizontal2"] = "rbxassetid://10723376745",
			["flipvertical"] = "rbxassetid://10723377138",
			["flipvertical2"] = "rbxassetid://10723377026",
			["flower"] = "rbxassetid://10747830374",
			["flower2"] = "rbxassetid://10723377305",
			["focus"] = "rbxassetid://10723377537",
			["folder"] = "rbxassetid://10723387563",
			["folderarchive"] = "rbxassetid://10723384478",
			["foldercheck"] = "rbxassetid://10723384605",
			["folderclock"] = "rbxassetid://10723384731",
			["folderclosed"] = "rbxassetid://10723384893",
			["foldercog"] = "rbxassetid://10723385213",
			["foldercog2"] = "rbxassetid://10723385036",
			["folderdown"] = "rbxassetid://10723385338",
			["folderedit"] = "rbxassetid://10723385445",
			["folderheart"] = "rbxassetid://10723385545",
			["folderinput"] = "rbxassetid://10723385721",
			["folderkey"] = "rbxassetid://10723385848",
			["folderlock"] = "rbxassetid://10723386005",
			["folderminus"] = "rbxassetid://10723386127",
			["folderopen"] = "rbxassetid://10723386277",
			["folderoutput"] = "rbxassetid://10723386386",
			["folderplus"] = "rbxassetid://10723386531",
			["foldersearch"] = "rbxassetid://10723386787",
			["foldersearch2"] = "rbxassetid://10723386674",
			["foldersymlink"] = "rbxassetid://10723386930",
			["foldertree"] = "rbxassetid://10723387085",
			["folderup"] = "rbxassetid://10723387265",
			["folderx"] = "rbxassetid://10723387448",
			["folders"] = "rbxassetid://10723387721",
			["forminput"] = "rbxassetid://10723387841",
			["forward"] = "rbxassetid://10723388016",
			["frame"] = "rbxassetid://10723394389",
			["framer"] = "rbxassetid://10723394565",
			["frown"] = "rbxassetid://10723394681",
			["fuel"] = "rbxassetid://10723394846",
			["functionsquare"] = "rbxassetid://10723395041",
			["gamepad"] = "rbxassetid://10723395457",
			["gamepad2"] = "rbxassetid://10723395215",
			["gauge"] = "rbxassetid://10723395708",
			["gavel"] = "rbxassetid://10723395896",
			["gem"] = "rbxassetid://10723396000",
			["ghost"] = "rbxassetid://10723396107",
			["gift"] = "rbxassetid://10723396402",
			["giftcard"] = "rbxassetid://10723396225",
			["gitbranch"] = "rbxassetid://10723396676",
			["gitbranchplus"] = "rbxassetid://10723396542",
			["gitcommit"] = "rbxassetid://10723396812",
			["gitcompare"] = "rbxassetid://10723396954",
			["gitfork"] = "rbxassetid://10723397049",
			["gitmerge"] = "rbxassetid://10723397165",
			["gitpullrequest"] = "rbxassetid://10723397431",
			["gitpullrequestclosed"] = "rbxassetid://10723397268",
			["gitpullrequestdraft"] = "rbxassetid://10734884302",
			["glass"] = "rbxassetid://10723397788",
			["glass2"] = "rbxassetid://10723397529",
			["glasswater"] = "rbxassetid://10723397678",
			["glasses"] = "rbxassetid://10723397895",
			["globe"] = "rbxassetid://10723404337",
			["globe2"] = "rbxassetid://10723398002",
			["grab"] = "rbxassetid://10723404472",
			["graduationcap"] = "rbxassetid://10723404691",
			["grape"] = "rbxassetid://10723404822",
			["grid"] = "rbxassetid://10723404936",
			["griphorizontal"] = "rbxassetid://10723405089",
			["gripvertical"] = "rbxassetid://10723405236",
			["hammer"] = "rbxassetid://10723405360",
			["hand"] = "rbxassetid://10723405649",
			["handmetal"] = "rbxassetid://10723405508",
			["harddrive"] = "rbxassetid://10723405749",
			["hardhat"] = "rbxassetid://10723405859",
			["hash"] = "rbxassetid://10723405975",
			["haze"] = "rbxassetid://10723406078",
			["headphones"] = "rbxassetid://10723406165",
			["heart"] = "rbxassetid://10723406885",
			["heartcrack"] = "rbxassetid://10723406299",
			["hearthandshake"] = "rbxassetid://10723406480",
			["heartoff"] = "rbxassetid://10723406662",
			["heartpulse"] = "rbxassetid://10723406795",
			["helpcircle"] = "rbxassetid://10723406988",
			["hexagon"] = "rbxassetid://10723407092",
			["highlighter"] = "rbxassetid://10723407192",
			["history"] = "rbxassetid://10723407335",
			["home"] = "rbxassetid://10723407389",
			["hourglass"] = "rbxassetid://10723407498",
			["icecream"] = "rbxassetid://10723414308",
			["image"] = "rbxassetid://10723415040",
			["imageminus"] = "rbxassetid://10723414487",
			["imageoff"] = "rbxassetid://10723414677",
			["imageplus"] = "rbxassetid://10723414827",
			["import"] = "rbxassetid://10723415205",
			["inbox"] = "rbxassetid://10723415335",
			["indent"] = "rbxassetid://10723415494",
			["indianrupee"] = "rbxassetid://10723415642",
			["infinity"] = "rbxassetid://10723415766",
			["info"] = "rbxassetid://10723415903",
			["inspect"] = "rbxassetid://10723416057",
			["italic"] = "rbxassetid://10723416195",
			["japaneseyen"] = "rbxassetid://10723416363",
			["joystick"] = "rbxassetid://10723416527",
			["key"] = "rbxassetid://10723416652",
			["keyboard"] = "rbxassetid://10723416765",
			["lamp"] = "rbxassetid://10723417513",
			["lampceiling"] = "rbxassetid://10723416922",
			["lampdesk"] = "rbxassetid://10723417016",
			["lampfloor"] = "rbxassetid://10723417131",
			["lampwalldown"] = "rbxassetid://10723417240",
			["lampwallup"] = "rbxassetid://10723417356",
			["landmark"] = "rbxassetid://10723417608",
			["languages"] = "rbxassetid://10723417703",
			["laptop"] = "rbxassetid://10723423881",
			["laptop2"] = "rbxassetid://10723417797",
			["lasso"] = "rbxassetid://10723424235",
			["lassoselect"] = "rbxassetid://10723424058",
			["laugh"] = "rbxassetid://10723424372",
			["layers"] = "rbxassetid://10723424505",
			["layout"] = "rbxassetid://10723425376",
			["layoutdashboard"] = "rbxassetid://10723424646",
			["layoutgrid"] = "rbxassetid://10723424838",
			["layoutlist"] = "rbxassetid://10723424963",
			["layouttemplate"] = "rbxassetid://10723425187",
			["leaf"] = "rbxassetid://10723425539",
			["library"] = "rbxassetid://10723425615",
			["lifebuoy"] = "rbxassetid://10723425685",
			["lightbulb"] = "rbxassetid://10723425852",
			["lightbulboff"] = "rbxassetid://10723425762",
			["linechart"] = "rbxassetid://10723426393",
			["link"] = "rbxassetid://10723426722",
			["link2"] = "rbxassetid://10723426595",
			["link2off"] = "rbxassetid://10723426513",
			["list"] = "rbxassetid://10723433811",
			["listchecks"] = "rbxassetid://10734884548",
			["listend"] = "rbxassetid://10723426886",
			["listminus"] = "rbxassetid://10723426986",
			["listmusic"] = "rbxassetid://10723427081",
			["listordered"] = "rbxassetid://10723427199",
			["listplus"] = "rbxassetid://10723427334",
			["liststart"] = "rbxassetid://10723427494",
			["listvideo"] = "rbxassetid://10723427619",
			["listx"] = "rbxassetid://10723433655",
			["loader"] = "rbxassetid://10723434070",
			["loader2"] = "rbxassetid://10723433935",
			["locate"] = "rbxassetid://10723434557",
			["locatefixed"] = "rbxassetid://10723434236",
			["locateoff"] = "rbxassetid://10723434379",
			["lock"] = "rbxassetid://10723434711",
			["login"] = "rbxassetid://10723434830",
			["logout"] = "rbxassetid://10723434906",
			["luggage"] = "rbxassetid://10723434993",
			["magnet"] = "rbxassetid://10723435069",
			["mail"] = "rbxassetid://10734885430",
			["mailcheck"] = "rbxassetid://10723435182",
			["mailminus"] = "rbxassetid://10723435261",
			["mailopen"] = "rbxassetid://10723435342",
			["mailplus"] = "rbxassetid://10723435443",
			["mailquestion"] = "rbxassetid://10723435515",
			["mailsearch"] = "rbxassetid://10734884739",
			["mailwarning"] = "rbxassetid://10734885015",
			["mailx"] = "rbxassetid://10734885247",
			["mails"] = "rbxassetid://10734885614",
			["map"] = "rbxassetid://10734886202",
			["mappin"] = "rbxassetid://10734886004",
			["mappinoff"] = "rbxassetid://10734885803",
			["maximize"] = "rbxassetid://10734886735",
			["maximize2"] = "rbxassetid://10734886496",
			["medal"] = "rbxassetid://10734887072",
			["megaphone"] = "rbxassetid://10734887454",
			["megaphoneoff"] = "rbxassetid://10734887311",
			["meh"] = "rbxassetid://10734887603",
			["menu"] = "rbxassetid://10734887784",
			["messagecircle"] = "rbxassetid://10734888000",
			["messagesquare"] = "rbxassetid://10734888228",
			["mic"] = "rbxassetid://10734888864",
			["mic2"] = "rbxassetid://10734888430",
			["micoff"] = "rbxassetid://10734888646",
			["microscope"] = "rbxassetid://10734889106",
			["microwave"] = "rbxassetid://10734895076",
			["milestone"] = "rbxassetid://10734895310",
			["minimize"] = "rbxassetid://10734895698",
			["minimize2"] = "rbxassetid://10734895530",
			["minus"] = "rbxassetid://10734896206",
			["minuscircle"] = "rbxassetid://10734895856",
			["minussquare"] = "rbxassetid://10734896029",
			["monitor"] = "rbxassetid://10734896881",
			["monitoroff"] = "rbxassetid://10734896360",
			["monitorspeaker"] = "rbxassetid://10734896512",
			["moon"] = "rbxassetid://10734897102",
			["morehorizontal"] = "rbxassetid://10734897250",
			["morevertical"] = "rbxassetid://10734897387",
			["mountain"] = "rbxassetid://10734897956",
			["mountainsnow"] = "rbxassetid://10734897665",
			["mouse"] = "rbxassetid://10734898592",
			["mousepointer"] = "rbxassetid://10734898476",
			["mousepointer2"] = "rbxassetid://10734898194",
			["mousepointerclick"] = "rbxassetid://10734898355",
			["move"] = "rbxassetid://10734900011",
			["move3d"] = "rbxassetid://10734898756",
			["movediagonal"] = "rbxassetid://10734899164",
			["movediagonal2"] = "rbxassetid://10734898934",
			["movehorizontal"] = "rbxassetid://10734899414",
			["movevertical"] = "rbxassetid://10734899821",
			["music"] = "rbxassetid://10734905958",
			["music2"] = "rbxassetid://10734900215",
			["music3"] = "rbxassetid://10734905665",
			["music4"] = "rbxassetid://10734905823",
			["navigation"] = "rbxassetid://10734906744",
			["navigation2"] = "rbxassetid://10734906332",
			["navigation2off"] = "rbxassetid://10734906144",
			["navigationoff"] = "rbxassetid://10734906580",
			["network"] = "rbxassetid://10734906975",
			["newspaper"] = "rbxassetid://10734907168",
			["octagon"] = "rbxassetid://10734907361",
			["option"] = "rbxassetid://10734907649",
			["outdent"] = "rbxassetid://10734907933",
			["package"] = "rbxassetid://10734909540",
			["package2"] = "rbxassetid://10734908151",
			["packagecheck"] = "rbxassetid://10734908384",
			["packageminus"] = "rbxassetid://10734908626",
			["packageopen"] = "rbxassetid://10734908793",
			["packageplus"] = "rbxassetid://10734909016",
			["packagesearch"] = "rbxassetid://10734909196",
			["packagex"] = "rbxassetid://10734909375",
			["paintbucket"] = "rbxassetid://10734909847",
			["paintbrush"] = "rbxassetid://10734910187",
			["paintbrush2"] = "rbxassetid://10734910030",
			["palette"] = "rbxassetid://10734910430",
			["palmtree"] = "rbxassetid://10734910680",
			["paperclip"] = "rbxassetid://10734910927",
			["partypopper"] = "rbxassetid://10734918735",
			["pause"] = "rbxassetid://10734919336",
			["pausecircle"] = "rbxassetid://10735024209",
			["pauseoctagon"] = "rbxassetid://10734919143",
			["pentool"] = "rbxassetid://10734919503",
			["pencil"] = "rbxassetid://10734919691",
			["percent"] = "rbxassetid://10734919919",
			["personstanding"] = "rbxassetid://10734920149",
			["phone"] = "rbxassetid://10734921524",
			["phonecall"] = "rbxassetid://10734920305",
			["phoneforwarded"] = "rbxassetid://10734920508",
			["phoneincoming"] = "rbxassetid://10734920694",
			["phonemissed"] = "rbxassetid://10734920845",
			["phoneoff"] = "rbxassetid://10734921077",
			["phoneoutgoing"] = "rbxassetid://10734921288",
			["piechart"] = "rbxassetid://10734921727",
			["piggybank"] = "rbxassetid://10734921935",
			["pin"] = "rbxassetid://10734922324",
			["pinoff"] = "rbxassetid://10734922180",
			["pipette"] = "rbxassetid://10734922497",
			["pizza"] = "rbxassetid://10734922774",
			["plane"] = "rbxassetid://10734922971",
			["play"] = "rbxassetid://10734923549",
			["playcircle"] = "rbxassetid://10734923214",
			["plus"] = "rbxassetid://10734924532",
			["pluscircle"] = "rbxassetid://10734923868",
			["plussquare"] = "rbxassetid://10734924219",
			["podcast"] = "rbxassetid://10734929553",
			["pointer"] = "rbxassetid://10734929723",
			["poundsterling"] = "rbxassetid://10734929981",
			["power"] = "rbxassetid://10734930466",
			["poweroff"] = "rbxassetid://10734930257",
			["printer"] = "rbxassetid://10734930632",
			["puzzle"] = "rbxassetid://10734930886",
			["quote"] = "rbxassetid://10734931234",
			["radio"] = "rbxassetid://10734931596",
			["radioreceiver"] = "rbxassetid://10734931402",
			["rectanglehorizontal"] = "rbxassetid://10734931777",
			["rectanglevertical"] = "rbxassetid://10734932081",
			["recycle"] = "rbxassetid://10734932295",
			["redo"] = "rbxassetid://10734932822",
			["redo2"] = "rbxassetid://10734932586",
			["refreshccw"] = "rbxassetid://10734933056",
			["refreshcw"] = "rbxassetid://10734933222",
			["refrigerator"] = "rbxassetid://10734933465",
			["regex"] = "rbxassetid://10734933655",
			["repeat"] = "rbxassetid://10734933966",
			["repeat1"] = "rbxassetid://10734933826",
			["reply"] = "rbxassetid://10734934252",
			["replyall"] = "rbxassetid://10734934132",
			["rewind"] = "rbxassetid://10734934347",
			["rocket"] = "rbxassetid://10734934585",
			["rockingchair"] = "rbxassetid://10734939942",
			["rotate3d"] = "rbxassetid://10734940107",
			["rotateccw"] = "rbxassetid://10734940376",
			["rotatecw"] = "rbxassetid://10734940654",
			["rss"] = "rbxassetid://10734940825",
			["ruler"] = "rbxassetid://10734941018",
			["russianruble"] = "rbxassetid://10734941199",
			["sailboat"] = "rbxassetid://10734941354",
			["save"] = "rbxassetid://10734941499",
			["scale"] = "rbxassetid://10734941912",
			["scale3d"] = "rbxassetid://10734941739",
			["scaling"] = "rbxassetid://10734942072",
			["scan"] = "rbxassetid://10734942565",
			["scanface"] = "rbxassetid://10734942198",
			["scanline"] = "rbxassetid://10734942351",
			["scissors"] = "rbxassetid://10734942778",
			["screenshare"] = "rbxassetid://10734943193",
			["screenshareoff"] = "rbxassetid://10734942967",
			["scroll"] = "rbxassetid://10734943448",
			["search"] = "rbxassetid://10734943674",
			["send"] = "rbxassetid://10734943902",
			["separatorhorizontal"] = "rbxassetid://10734944115",
			["separatorvertical"] = "rbxassetid://10734944326",
			["server"] = "rbxassetid://10734949856",
			["servercog"] = "rbxassetid://10734944444",
			["servercrash"] = "rbxassetid://10734944554",
			["serveroff"] = "rbxassetid://10734944668",
			["settings"] = "rbxassetid://10734950309",
			["settings2"] = "rbxassetid://10734950020",
			["share"] = "rbxassetid://10734950813",
			["share2"] = "rbxassetid://10734950553",
			["sheet"] = "rbxassetid://10734951038",
			["shield"] = "rbxassetid://10734951847",
			["shieldalert"] = "rbxassetid://10734951173",
			["shieldcheck"] = "rbxassetid://10734951367",
			["shieldclose"] = "rbxassetid://10734951535",
			["shieldoff"] = "rbxassetid://10734951684",
			["shirt"] = "rbxassetid://10734952036",
			["shoppingbag"] = "rbxassetid://10734952273",
			["shoppingcart"] = "rbxassetid://10734952479",
			["shovel"] = "rbxassetid://10734952773",
			["showerhead"] = "rbxassetid://10734952942",
			["shrink"] = "rbxassetid://10734953073",
			["shrub"] = "rbxassetid://10734953241",
			["shuffle"] = "rbxassetid://10734953451",
			["sidebar"] = "rbxassetid://10734954301",
			["sidebarclose"] = "rbxassetid://10734953715",
			["sidebaropen"] = "rbxassetid://10734954000",
			["sigma"] = "rbxassetid://10734954538",
			["signal"] = "rbxassetid://10734961133",
			["signalhigh"] = "rbxassetid://10734954807",
			["signallow"] = "rbxassetid://10734955080",
			["signalmedium"] = "rbxassetid://10734955336",
			["signalzero"] = "rbxassetid://10734960878",
			["siren"] = "rbxassetid://10734961284",
			["skipback"] = "rbxassetid://10734961526",
			["skipforward"] = "rbxassetid://10734961809",
			["skull"] = "rbxassetid://10734962068",
			["slack"] = "rbxassetid://10734962339",
			["slash"] = "rbxassetid://10734962600",
			["slice"] = "rbxassetid://10734963024",
			["sliders"] = "rbxassetid://10734963400",
			["slidershorizontal"] = "rbxassetid://10734963191",
			["smartphone"] = "rbxassetid://10734963940",
			["smartphonecharging"] = "rbxassetid://10734963671",
			["smile"] = "rbxassetid://10734964441",
			["smileplus"] = "rbxassetid://10734964188",
			["snowflake"] = "rbxassetid://10734964600",
			["sofa"] = "rbxassetid://10734964852",
			["sortasc"] = "rbxassetid://10734965115",
			["sortdesc"] = "rbxassetid://10734965287",
			["speaker"] = "rbxassetid://10734965419",
			["sprout"] = "rbxassetid://10734965572",
			["square"] = "rbxassetid://10734965702",
			["star"] = "rbxassetid://10734966248",
			["starhalf"] = "rbxassetid://10734965897",
			["staroff"] = "rbxassetid://10734966097",
			["stethoscope"] = "rbxassetid://10734966384",
			["sticker"] = "rbxassetid://10734972234",
			["stickynote"] = "rbxassetid://10734972463",
			["stopcircle"] = "rbxassetid://10734972621",
			["stretchhorizontal"] = "rbxassetid://10734972862",
			["stretchvertical"] = "rbxassetid://10734973130",
			["strikethrough"] = "rbxassetid://10734973290",
			["subscript"] = "rbxassetid://10734973457",
			["sun"] = "rbxassetid://10734974297",
			["sundim"] = "rbxassetid://10734973645",
			["sunmedium"] = "rbxassetid://10734973778",
			["sunmoon"] = "rbxassetid://10734973999",
			["sunsnow"] = "rbxassetid://10734974130",
			["sunrise"] = "rbxassetid://10734974522",
			["sunset"] = "rbxassetid://10734974689",
			["superscript"] = "rbxassetid://10734974850",
			["swissfranc"] = "rbxassetid://10734975024",
			["switchcamera"] = "rbxassetid://10734975214",
			["sword"] = "rbxassetid://10734975486",
			["swords"] = "rbxassetid://10734975692",
			["syringe"] = "rbxassetid://10734975932",
			["table"] = "rbxassetid://10734976230",
			["table2"] = "rbxassetid://10734976097",
			["tablet"] = "rbxassetid://10734976394",
			["tag"] = "rbxassetid://10734976528",
			["tags"] = "rbxassetid://10734976739",
			["target"] = "rbxassetid://10734977012",
			["tent"] = "rbxassetid://10734981750",
			["terminal"] = "rbxassetid://10734982144",
			["terminalsquare"] = "rbxassetid://10734981995",
			["textcursor"] = "rbxassetid://10734982395",
			["textcursorinput"] = "rbxassetid://10734982297",
			["thermometer"] = "rbxassetid://10734983134",
			["thermometersnowflake"] = "rbxassetid://10734982571",
			["thermometersun"] = "rbxassetid://10734982771",
			["thumbsdown"] = "rbxassetid://10734983359",
			["thumbsup"] = "rbxassetid://10734983629",
			["ticket"] = "rbxassetid://10734983868",
			["timer"] = "rbxassetid://10734984606",
			["timeroff"] = "rbxassetid://10734984138",
			["timerreset"] = "rbxassetid://10734984355",
			["toggleleft"] = "rbxassetid://10734984834",
			["toggleright"] = "rbxassetid://10734985040",
			["tornado"] = "rbxassetid://10734985247",
			["toybrick"] = "rbxassetid://10747361919",
			["train"] = "rbxassetid://10747362105",
			["trash"] = "rbxassetid://10747362393",
			["trash2"] = "rbxassetid://10747362241",
			["treedeciduous"] = "rbxassetid://10747362534",
			["treepine"] = "rbxassetid://10747362748",
			["trees"] = "rbxassetid://10747363016",
			["trendingdown"] = "rbxassetid://10747363205",
			["trendingup"] = "rbxassetid://10747363465",
			["triangle"] = "rbxassetid://10747363621",
			["trophy"] = "rbxassetid://10747363809",
			["truck"] = "rbxassetid://10747364031",
			["tv"] = "rbxassetid://10747364593",
			["tv2"] = "rbxassetid://10747364302",
			["type"] = "rbxassetid://10747364761",
			["umbrella"] = "rbxassetid://10747364971",
			["underline"] = "rbxassetid://10747365191",
			["undo"] = "rbxassetid://10747365484",
			["undo2"] = "rbxassetid://10747365359",
			["unlink"] = "rbxassetid://10747365771",
			["unlink2"] = "rbxassetid://10747397871",
			["unlock"] = "rbxassetid://10747366027",
			["upload"] = "rbxassetid://10747366434",
			["uploadcloud"] = "rbxassetid://10747366266",
			["usb"] = "rbxassetid://10747366606",
			["user"] = "rbxassetid://10747373176",
			["usercheck"] = "rbxassetid://10747371901",
			["usercog"] = "rbxassetid://10747372167",
			["userminus"] = "rbxassetid://10747372346",
			["userplus"] = "rbxassetid://10747372702",
			["userx"] = "rbxassetid://10747372992",
			["users"] = "rbxassetid://10747373426",
			["utensils"] = "rbxassetid://10747373821",
			["utensilscrossed"] = "rbxassetid://10747373629",
			["venetianmask"] = "rbxassetid://10747374003",
			["verified"] = "rbxassetid://10747374131",
			["vibrate"] = "rbxassetid://10747374489",
			["vibrateoff"] = "rbxassetid://10747374269",
			["video"] = "rbxassetid://10747374938",
			["videooff"] = "rbxassetid://10747374721",
			["view"] = "rbxassetid://10747375132",
			["voicemail"] = "rbxassetid://10747375281",
			["volume"] = "rbxassetid://10747376008",
			["volume1"] = "rbxassetid://10747375450",
			["volume2"] = "rbxassetid://10747375679",
			["volumex"] = "rbxassetid://10747375880",
			["wallet"] = "rbxassetid://10747376205",
			["wand"] = "rbxassetid://10747376565",
			["wand2"] = "rbxassetid://10747376349",
			["watch"] = "rbxassetid://10747376722",
			["waves"] = "rbxassetid://10747376931",
			["webcam"] = "rbxassetid://10747381992",
			["wifi"] = "rbxassetid://10747382504",
			["wifioff"] = "rbxassetid://10747382268",
			["wind"] = "rbxassetid://10747382750",
			["wraptext"] = "rbxassetid://10747383065",
			["wrench"] = "rbxassetid://10747383470",
			["x"] = "rbxassetid://10747384394",
			["xcircle"] = "rbxassetid://10747383819",
			["xoctagon"] = "rbxassetid://10747384037",
			["xsquare"] = "rbxassetid://10747384217",
			["zoomin"] = "rbxassetid://10747384552",
			["zoomout"] = "rbxassetid://10747384679"
		}
	end)()

}

local Settings = redzlib.Settings
local Flags = redzlib.Flags
local FlagSetters = redzlib.Setters

-- ////////////////////////////////////////////////////////////////// --
--  Maid (connection / instance cleanup)
-- ////////////////////////////////////////////////////////////////// --
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({Tasks = {}}, Maid)
end

function Maid:Give(Task)
	table.insert(self.Tasks, Task)
	return Task
end

function Maid:Clean()
	local Tasks = self.Tasks
	self.Tasks = {}

	for _, Task in ipairs(Tasks) do
		local Kind = typeof(Task)
		if Kind == "RBXScriptConnection" then
			Task:Disconnect()
		elseif Kind == "Instance" then
			Task:Destroy()
		elseif Kind == "function" then
			pcall(Task)
		elseif Kind == "table" then
			if type(Task.Clean) == "function" then
				pcall(Task.Clean, Task)
			elseif type(Task.Disconnect) == "function" then
				pcall(Task.Disconnect, Task)
			elseif type(Task.Destroy) == "function" then
				pcall(Task.Destroy, Task)
			end
		end
	end
end

local LibMaid = Maid.new()

-- Maid that is cleaned when the library dies or when `Frame` is destroyed
local function ElementMaid(Frame)
	local ElMaid = Maid.new()
	LibMaid:Give(ElMaid)
	if Frame then
		Frame.Destroying:Connect(function()
			ElMaid:Clean()
		end)
	end
	return ElMaid
end

-- ////////////////////////////////////////////////////////////////// --
--  File IO + serialization
-- ////////////////////////////////////////////////////////////////// --
local function EnsureFolder(FilePath)
	if not (Env.MakeFolder and Env.IsFolder) then return end

	local Folder = FilePath:match("^(.*)[/\\][^/\\]*$")
	if not Folder or Folder == "" then return end

	local Built = ""
	for Segment in Folder:gmatch("[^/\\]+") do
		Built = (Built == "") and Segment or (Built .. "/" .. Segment)
		local Ok, Exists = pcall(Env.IsFolder, Built)
		if Ok and not Exists then
			pcall(Env.MakeFolder, Built)
		end
	end
end

local function WriteRaw(Path, Text)
	if not Env.WriteFile or type(Path) ~= "string" then return false end
	EnsureFolder(Path)
	return (pcall(Env.WriteFile, Path, Text))
end

local function ReadRaw(Path)
	if not (Env.ReadFile and Env.IsFile) or type(Path) ~= "string" then return nil end

	local Ok, Exists = pcall(Env.IsFile, Path)
	if not (Ok and Exists) then return nil end

	local Ok2, Raw = pcall(Env.ReadFile, Path)
	if Ok2 and type(Raw) == "string" then
		return Raw
	end
end

local function Serialize(Value)
	local Kind = typeof(Value)

	if Kind == "Color3" then
		return {
			__redz = "Color3",
			R = math.floor(Value.R * 255 + 0.5),
			G = math.floor(Value.G * 255 + 0.5),
			B = math.floor(Value.B * 255 + 0.5)
		}
	elseif Kind == "EnumItem" then
		return {__redz = "Enum", EnumType = tostring(Value.EnumType), Name = Value.Name}
	elseif Kind == "table" then
		local Out = {}
		for Key, Val in pairs(Value) do
			Out[Key] = Serialize(Val)
		end
		return Out
	end

	return Value
end

local function Deserialize(Value)
	if type(Value) ~= "table" then return Value end

	if Value.__redz == "Color3" then
		return Color3.fromRGB(tonumber(Value.R) or 0, tonumber(Value.G) or 0, tonumber(Value.B) or 0)
	elseif Value.__redz == "Enum" then
		local Ok, Item = pcall(function()
			return Enum[Value.EnumType][Value.Name]
		end)
		return Ok and Item or nil
	end

	local Out = {}
	for Key, Val in pairs(Value) do
		Out[Key] = Deserialize(Val)
	end
	return Out
end

local function EncodeJson(Data)
	local Ok, Encoded = pcall(function()
		return HttpService:JSONEncode(Serialize(Data))
	end)
	return Ok and Encoded or nil
end

local function DecodeJson(Raw)
	if type(Raw) ~= "string" then return nil end
	local Ok, Decoded = pcall(function()
		return HttpService:JSONDecode(Raw)
	end)
	if Ok then
		return Deserialize(Decoded)
	end
end

local function VerifyTheme(Name)
	return type(Name) == "string" and redzlib.Themes[Name] ~= nil
end

local function SaveSettings()
	local Encoded = EncodeJson(redzlib.Save)
	if Encoded then
		WriteRaw(Settings.FileName, Encoded)
	end
end

do -- load persisted UI settings
	local Data = DecodeJson(ReadRaw(Settings.FileName))
	local Save = redzlib.Save

	if type(Data) == "table" then
		if type(Data.UISize) == "table" and tonumber(Data.UISize[1]) and tonumber(Data.UISize[2]) then
			Save.UISize = {
				math.clamp(tonumber(Data.UISize[1]), 430, 1100),
				math.clamp(tonumber(Data.UISize[2]), 240, 700)
			}
		end
		if tonumber(Data.TabSize) then
			Save.TabSize = math.clamp(tonumber(Data.TabSize), 135, 250)
		end
		if VerifyTheme(Data.Theme) then
			Save.Theme = Data.Theme
		end
		if tonumber(Data.Scale) then
			Save.Scale = math.clamp(tonumber(Data.Scale), 300, 2000)
		end
	end
end

-- ////////////////////////////////////////////////////////////////// --
--  Instance helpers
-- ////////////////////////////////////////////////////////////////// --
local function SetProps(Obj, Props)
	if Props then
		for Prop, Value in pairs(Props) do
			Obj[Prop] = Value
		end
	end
	return Obj
end

local function SetChildren(Obj, Children)
	if Children then
		for _, Child in pairs(Children) do
			Child.Parent = Obj
		end
	end
	return Obj
end

-- Create("Class", {Props}, {Children})  or  Create("Class", Parent, {Props}, {Children})
local function Create(ClassName, ...)
	local Args = {...}
	local Obj = Instance.new(ClassName)

	if Obj:IsA("GuiObject") then
		Obj.BorderSizePixel = 0
	end
	if Obj:IsA("GuiButton") then
		Obj.AutoButtonColor = false
	end

	local Parent, Props, Children
	if type(Args[1]) == "table" then
		Props, Children = Args[1], Args[2]
	else
		Parent, Props, Children = Args[1], Args[2], Args[3]
	end

	SetProps(Obj, Props)
	SetChildren(Obj, Children)
	if Parent then
		Obj.Parent = Parent
	end
	return Obj
end

-- ////////////////////////////////////////////////////////////////// --
--  Connections (public events)
-- ////////////////////////////////////////////////////////////////// --
local Funcs = {}
local Connections = {}
local Connection = redzlib.Connection

function Funcs:InsertCallback(List, Func)
	if type(Func) == "function" then
		table.insert(List, Func)
		return Func
	end
	return nil
end

function Funcs:ReplaceCallback(List, Func)
	table.clear(List)
	if type(Func) == "function" then
		table.insert(List, Func)
	end
end

function Funcs:FireCallback(List, ...)
	for _, Func in ipairs(table.clone(List)) do
		if type(Func) == "function" then
			task.spawn(Func, ...)
		end
	end
end

-- Accepts: function | {Table, "Key"} | nil
function Funcs:GetCallback(Configs, Index)
	local Func = Configs[Index] or Configs.Callback or function() end

	if type(Func) == "table" then
		local Target, Key = Func[1], Func[2]
		return {function(Value)
			Target[Key] = Value
		end}
	end
	return {Func}
end

function Funcs:GetConnectionFunctions(ConnectedFuncs, Func)
	local Connected = {Function = Func, Connected = true}

	function Connected:Disconnect()
		if self.Connected then
			self.Connected = false
			local Index = table.find(ConnectedFuncs, self.Function)
			if Index then
				table.remove(ConnectedFuncs, Index)
			end
		end
	end

	function Connected:Fire(...)
		if self.Connected then
			task.spawn(self.Function, ...)
		end
	end

	return Connected
end

do
	local function NewConnectionList(List)
		for _, CoName in ipairs(List) do
			local ConnectedFuncs, Signal = {}, {Name = CoName}
			Connection[CoName] = Signal
			Connections[CoName] = ConnectedFuncs

			function Signal:Connect(Func)
				if type(Func) == "function" then
					table.insert(ConnectedFuncs, Func)
					return Funcs:GetConnectionFunctions(ConnectedFuncs, Func)
				end
			end

			function Signal:Once(Func)
				if type(Func) ~= "function" then return end

				local Connected
				local Wrapper = function(...)
					Connected:Disconnect()
					Func(...)
				end

				table.insert(ConnectedFuncs, Wrapper)
				Connected = Funcs:GetConnectionFunctions(ConnectedFuncs, Wrapper)
				return Connected
			end
		end
	end

	function Connection:FireConnection(CoName, ...)
		local Name = type(CoName) == "string" and CoName or (type(CoName) == "table" and CoName.Name)
		local List = Name and Connections[Name]
		if not List then return end

		for _, Func in ipairs(table.clone(List)) do
			task.spawn(Func, ...)
		end
	end

	NewConnectionList({"FlagsChanged", "ThemeChanged", "FileSaved", "ThemeChanging", "OptionAdded", "ConfigLoaded", "WindowDestroyed"})
end

-- ////////////////////////////////////////////////////////////////// --
--  Flags
-- ////////////////////////////////////////////////////////////////// --
local GetFlag, SetFlag, CheckFlag, RegisterFlag

do
	local SavePending = false

	local function QueueFlagSave()
		if SavePending or type(Settings.ScriptFile) ~= "string" or not Env.WriteFile then return end
		SavePending = true

		task.delay(0.3, function()
			SavePending = false

			local File = Settings.ScriptFile
			if type(File) ~= "string" then return end

			local Encoded = EncodeJson(Flags)
			if Encoded and WriteRaw(File, Encoded) then
				Connection:FireConnection("FileSaved", "Script-Flags", File, Encoded)
			end
		end)
	end

	CheckFlag = function(Name)
		return type(Name) == "string" and Flags[Name] ~= nil
	end

	GetFlag = function(Name)
		if type(Name) == "string" then
			return Flags[Name]
		end
	end

	SetFlag = function(Flag, Value)
		if Flag and (Value ~= Flags[Flag] or type(Value) == "table") then
			Flags[Flag] = Value
			Connection:FireConnection("FlagsChanged", Flag, Value)
			QueueFlagSave()
		end
	end

	-- Registers a setter so configs can be applied to live elements
	RegisterFlag = function(Flag, Setter)
		if type(Flag) == "string" and type(Setter) == "function" then
			FlagSetters[Flag] = Setter
		end
	end
end

-- ////////////////////////////////////////////////////////////////// --
--  ScreenGui / scale
-- ////////////////////////////////////////////////////////////////// --
local GuiName = "redz-library-v5"
local GuiParent = GetGuiParent()

do -- remove the previous execution (and its connections)
	local Genv = (getgenv and getgenv()) or _G
	if type(Genv.__redzlib_cleanup) == "function" then
		pcall(Genv.__redzlib_cleanup)
	end

	for _, Old in ipairs(GuiParent:GetChildren()) do
		if Old.Name == GuiName then
			Old:Destroy()
		end
	end
end

local ScreenGui = Create("ScreenGui", {
	Name = GuiName,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 999
}, {
	Create("UIScale", {
		Scale = 1,
		Name = "Scale"
	})
})

if Env.ProtectGui then
	pcall(Env.ProtectGui, ScreenGui)
end
ScreenGui.Parent = GuiParent

do
	local Genv = (getgenv and getgenv()) or _G
	Genv.__redzlib_cleanup = function()
		LibMaid:Clean()
		ScreenGui:Destroy()
	end
end

local ViewportCallbacks = {}

local function GetViewport()
	local Camera = workspace.CurrentCamera
	return Camera and Camera.ViewportSize or Vector2.new(1280, 720)
end

local function GetScale()
	return ScreenGui.Scale.Scale
end

local function UpdateScale()
	local Base = redzlib.Save.Scale or 450
	ScreenGui.Scale.Scale = math.clamp(GetViewport().Y / Base, 0.4, 6)
	for _, Callback in ipairs(ViewportCallbacks) do
		task.spawn(Callback)
	end
end

do
	local function HookCamera()
		local Camera = workspace.CurrentCamera
		if Camera then
			LibMaid:Give(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale))
		end
	end

	LibMaid:Give(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		HookCamera()
		UpdateScale()
	end))
	HookCamera()
	UpdateScale()
end

-- ////////////////////////////////////////////////////////////////// --
--  Tweens (a new tween on the same property cancels the previous one)
-- ////////////////////////////////////////////////////////////////// --
local ActiveTweens = setmetatable({}, {__mode = "k"})

local function StopTweens(Obj)
	local Store = ActiveTweens[Obj]
	if Store then
		for _, Tween in pairs(Store) do
			Tween:Cancel()
		end
		ActiveTweens[Obj] = nil
	end
end

-- CreateTween({Instance, "Property", Value, Time, WaitUntilDone, EasingStyle, EasingDirection})
local function CreateTween(Configs)
	local Obj = Configs[1] or Configs.Instance
	local Prop = Configs[2] or Configs.Prop
	local NewVal = Configs[3]
	if NewVal == nil then NewVal = Configs.NewVal end
	local Time = Configs[4] or Configs.Time or 0.5
	local Wait = Configs[5] or Configs.wait or false
	local Style = Configs[6] or Configs.Style or Enum.EasingStyle.Quint
	local Direction = Configs[7] or Configs.Direction or Enum.EasingDirection.Out

	local Store = ActiveTweens[Obj]
	if not Store then
		Store = {}
		ActiveTweens[Obj] = Store
	end

	local Old = Store[Prop]
	if Old then
		Old:Cancel()
	end

	local Tween = TweenService:Create(Obj, TweenInfo.new(Time, Style, Direction), {[Prop] = NewVal})
	Store[Prop] = Tween

	Tween.Completed:Connect(function()
		if Store[Prop] == Tween then
			Store[Prop] = nil
		end
	end)

	Tween:Play()
	if Wait then
		Tween.Completed:Wait()
	end
	return Tween
end

-- ////////////////////////////////////////////////////////////////// --
--  Drag / resize (mouse + touch)
-- ////////////////////////////////////////////////////////////////// --
local function IsPointerStart(Input)
	return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

-- OnStart(Input) / OnMove(DeltaInVirtualUnits, Input) / OnEnd()
local function TrackDrag(Handle, OnStart, OnMove, OnEnd)
	local Active, Origin, StartInput = false, nil, nil

	Handle.InputBegan:Connect(function(Input)
		if not IsPointerStart(Input) then return end

		Active, Origin, StartInput = true, Input.Position, Input
		if OnStart then OnStart(Input) end

		local Changed
		Changed = Input.Changed:Connect(function()
			if Input.UserInputState == Enum.UserInputState.End then
				Changed:Disconnect()
				if Active and StartInput == Input then
					Active = false
					if OnEnd then OnEnd() end
				end
			end
		end)
	end)

	LibMaid:Give(UserInputService.InputChanged:Connect(function(Input)
		if not Active then return end

		local IsMouse = Input.UserInputType == Enum.UserInputType.MouseMovement
		local IsTouch = Input.UserInputType == Enum.UserInputType.Touch and Input == StartInput
		if IsMouse or IsTouch then
			local Delta = Input.Position - Origin
			OnMove(Vector2.new(Delta.X, Delta.Y) / GetScale(), Input)
		end
	end))

	return Handle
end

local function KeepOnScreen(Target, Margin)
	Margin = (Margin or 40) * GetScale()

	local Screen = ScreenGui.AbsoluteSize
	local Pos, Size = Target.AbsolutePosition, Target.AbsoluteSize
	local DX, DY = 0, 0

	if Pos.X + Size.X < Margin then
		DX = Margin - (Pos.X + Size.X)
	elseif Pos.X > Screen.X - Margin then
		DX = (Screen.X - Margin) - Pos.X
	end

	if Pos.Y < 0 then
		DY = -Pos.Y
	elseif Pos.Y > Screen.Y - Margin then
		DY = (Screen.Y - Margin) - Pos.Y
	end

	if DX ~= 0 or DY ~= 0 then
		local P, S = Target.Position, GetScale()
		Target.Position = UDim2.new(P.X.Scale, P.X.Offset + DX / S, P.Y.Scale, P.Y.Offset + DY / S)
	end
end

-- Handle = the part the user grabs, Target = the frame that moves
local function MakeDrag(Handle, Target, OnFinish)
	Target = Target or Handle
	Handle.Active = true

	local StartPos
	TrackDrag(Handle, function()
		StartPos = Target.Position
	end, function(Delta)
		Target.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
		KeepOnScreen(Target)
	end, OnFinish)

	return Handle
end


-- ////////////////////////////////////////////////////////////////// --
--  Themes
-- ////////////////////////////////////////////////////////////////// --
local Theme = redzlib.Themes[redzlib.Save.Theme] or redzlib.Themes.Darker

local RoleKeys = {
	Frame = "Color Hub 2",
	Stroke = "Color Stroke",
	Theme = "Color Theme",
	ScrollBar = "Color Theme",
	Text = "Color Text",
	DarkText = "Color Dark Text",
	Gradient = "Color Hub 1"
}

local function ThemeProp(Obj, Role)
	if Obj:IsA("UIStroke") or Obj:IsA("UIGradient") then
		return "Color"
	end
	if Obj:IsA("ScrollingFrame") and Role == "ScrollBar" then
		return "ScrollBarImageColor3"
	end

	local IsImage = Obj:IsA("ImageLabel") or Obj:IsA("ImageButton")
	if Role == "Text" or Role == "DarkText" then
		return IsImage and "ImageColor3" or "TextColor3"
	end
	if Role == "Theme" and IsImage then
		return "ImageColor3"
	end
	return "BackgroundColor3"
end

local function ApplyThemeRole(Obj, Role, Animate)
	local Key = RoleKeys[Role]
	if not Key then return end

	local Value = Theme[Key]
	if Role == "Gradient" then
		Obj.Color = Value
		return
	end

	local Prop = ThemeProp(Obj, Role)
	if Animate then
		CreateTween({Obj, Prop, Value, 0.3})
	else
		Obj[Prop] = Value
	end
end

local function InsertTheme(Obj, Role)
	redzlib.Instances[Obj] = Role
	return Obj
end

function redzlib:SetTheme(NewTheme)
	if not VerifyTheme(NewTheme) then return end

	redzlib.Save.Theme = NewTheme
	SaveSettings()
	Theme = redzlib.Themes[NewTheme]

	Connection:FireConnection("ThemeChanged", NewTheme)
	for Obj, Role in pairs(redzlib.Instances) do
		ApplyThemeRole(Obj, Role, true)
	end
end

function redzlib:GetThemes()
	local Names = {}
	for Name in pairs(redzlib.Themes) do
		table.insert(Names, Name)
	end
	table.sort(Names)
	return Names
end

-- Missing keys fall back to the "Darker" theme. "Color Hub 1" accepts a Color3 or a ColorSequence.
function redzlib:AddTheme(Name, Data)
	if type(Name) ~= "string" or type(Data) ~= "table" then return end

	local New = {}
	for Key, Default in pairs(redzlib.Themes.Darker) do
		local Value = Data[Key]
		if Key == "Color Hub 1" and typeof(Value) == "Color3" then
			Value = ColorSequence.new(Value)
		end
		New[Key] = Value ~= nil and Value or Default
	end

	redzlib.Themes[Name] = New
	return New
end

-- Same meaning as the original: the window is designed for `NewScale` pixels of height
function redzlib:SetScale(NewScale)
	redzlib.Save.Scale = math.clamp(tonumber(NewScale) or 450, 300, 2000)
	SaveSettings()
	UpdateScale()
end

-- ////////////////////////////////////////////////////////////////// --
--  Icons
-- ////////////////////////////////////////////////////////////////// --
local IconCache = {}

function redzlib:GetIcon(Index)
	if type(Index) == "number" then
		return "rbxassetid://" .. tostring(Index)
	end
	if type(Index) ~= "string" or #Index == 0 then
		return Index
	end
	if Index:find("rbxassetid://", 1, true) then
		return Index
	end
	if Index:match("^%d+$") then
		return "rbxassetid://" .. Index
	end

	local Key = string.lower(Index)
	Key = Key:gsub("^lucide", "")
	Key = Key:gsub("[%s%-_]", "")

	if IconCache[Key] ~= nil then
		return IconCache[Key]
	end

	local Result = self.Icons[Key]
	if not Result then
		local BestName
		for Name, Icon in pairs(self.Icons) do
			if Name:find(Key, 1, true) then
				if not BestName or #Name < #BestName or (#Name == #BestName and Name < BestName) then
					BestName, Result = Name, Icon
				end
			end
		end
	end

	Result = Result or Index
	IconCache[Key] = Result
	return Result
end

-- ////////////////////////////////////////////////////////////////// --
--  Basic elements
-- ////////////////////////////////////////////////////////////////// --
local function GetStr(Val)
	if type(Val) == "function" then
		return Val()
	end
	return Val
end

local function AddEle(Name, Func)
	redzlib.Elements[Name] = Func
end

local function Make(Ele, Obj, Props, ...)
	return redzlib.Elements[Ele](Obj, Props, ...)
end

AddEle("Corner", function(Parent, CornerRadius)
	return Create("UICorner", Parent, {
		CornerRadius = CornerRadius or UDim.new(0, 7)
	})
end)

AddEle("Stroke", function(Parent, Props, Color, Thickness)
	local New = Create("UIStroke", Parent, {
		Color = Color or Theme["Color Stroke"],
		Thickness = Thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	})
	SetProps(New, Props)
	return InsertTheme(New, "Stroke")
end)

AddEle("Button", function(Parent, Props, Callback)
	local New = InsertTheme(Create("TextButton", Parent, {
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme["Color Hub 2"]
	}), "Frame")
	SetProps(New, Props)

	New.MouseEnter:Connect(function()
		CreateTween({New, "BackgroundTransparency", 0.4, 0.15})
	end)
	New.MouseLeave:Connect(function()
		CreateTween({New, "BackgroundTransparency", 0, 0.15})
	end)

	if Callback then
		New.Activated:Connect(Callback)
	end
	return New
end)

AddEle("Gradient", function(Parent, Props)
	local New = Create("UIGradient", Parent, {
		Color = Theme["Color Hub 1"]
	})
	SetProps(New, Props)
	return InsertTheme(New, "Gradient")
end)

-- Dark overlay that blocks an element ("locked" state)
local function AddLock(Frame)
	local Cover = Create("TextButton", Frame, {
		Name = "Locked",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.55,
		ZIndex = 20,
		Active = true,
		Visible = false
	})
	Make("Corner", Cover, UDim.new(0, 6))

	return function(State)
		Cover.Visible = State and true or false
	end
end

-- Base row used by almost every element.  Returns the frame and a label controller.
local function ButtonFrame(Parent, Title, Description, HolderSize, Static)
	local TitleL = InsertTheme(Create("TextLabel", {
		Font = Enum.Font.GothamMedium,
		TextColor3 = Theme["Color Text"],
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		RichText = true,
		LayoutOrder = 1
	}), "Text")

	local DescL = InsertTheme(Create("TextLabel", {
		Font = Enum.Font.Gotham,
		TextColor3 = Theme["Color Dark Text"],
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		RichText = true,
		LayoutOrder = 2
	}), "DarkText")

	local Frame
	if Static then
		Frame = InsertTheme(Create("Frame", Parent, {
			Size = UDim2.new(1, 0, 0, 25),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme["Color Hub 2"],
			Name = "Option"
		}), "Frame")
	else
		Frame = Make("Button", Parent, {
			Size = UDim2.new(1, 0, 0, 25),
			AutomaticSize = Enum.AutomaticSize.Y,
			Name = "Option"
		})
	end
	Make("Corner", Frame, UDim.new(0, 6))

	local LabelHolder = Create("Frame", Frame, {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = HolderSize,
		Position = UDim2.new(0, 10, 0, 0),
		AnchorPoint = Vector2.new(0, 0),
		Name = "Labels"
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2)
		}),
		Create("UIPadding", {
			PaddingBottom = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5)
		}),
		TitleL,
		DescL
	})

	local Label = {Title = "", Desc = ""}

	function Label:SetTitle(NewTitle)
		if NewTitle ~= nil then
			self.Title = tostring(NewTitle)
			TitleL.Text = self.Title
		end
	end

	function Label:SetDesc(NewDesc)
		NewDesc = NewDesc ~= nil and tostring(NewDesc) or ""
		self.Desc = NewDesc

		if NewDesc:match("%S") then
			DescL.Visible = true
			DescL.Text = NewDesc
			LabelHolder.Position = UDim2.new(0, 10, 0, 0)
			LabelHolder.AnchorPoint = Vector2.new(0, 0)
		else
			DescL.Visible = false
			DescL.Text = ""
			LabelHolder.Position = UDim2.new(0, 10, 0.5, 0)
			LabelHolder.AnchorPoint = Vector2.new(0, 0.5)
		end
	end

	Label:SetTitle(Title)
	Label:SetDesc(Description)
	return Frame, Label
end

-- ////////////////////////////////////////////////////////////////// --
--  Popups (dropdown list / color picker share the same controller)
-- ////////////////////////////////////////////////////////////////// --
local function MakePopupController(MainFrame)
	local Holder = Create("Folder", ScreenGui, {
		Name = "Dropdown"
	})

	local Blocker = Create("TextButton", Holder, {
		Name = "AntiClick",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Visible = false,
		ZIndex = 100
	})

	local Controller = {Current = nil}

	-- Owner = {Frame, Anchor, Width, Height, OnClose}
	function Controller:NewFrame()
		local Frame = Create("Frame", Blocker, {
			Name = "DropdownFrame",
			Size = UDim2.fromOffset(150, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.02,
			ClipsDescendants = true,
			Active = true,
			Visible = false
		})
		Make("Corner", Frame)
		Make("Stroke", Frame)
		Make("Gradient", Frame, {Rotation = 60})
		return Frame
	end

	function Controller:Place(Owner, Animate)
		local Scale = GetScale()
		local Anchor = Owner.Anchor
		local APos, ASize = Anchor.AbsolutePosition, Anchor.AbsoluteSize
		local Screen = ScreenGui.AbsoluteSize
		local Width, Height = Owner.Width, Owner.Height

		local X = math.clamp((APos.X + ASize.X) / Scale - Width, 4, math.max(4, Screen.X / Scale - Width - 4))
		local Below = (APos.Y + ASize.Y) / Scale + 4
		local Above = APos.Y / Scale - 4 - Height
		local OpenUp = (Below + Height > Screen.Y / Scale - 4) and Above >= 4
		local Y = OpenUp and Above or Below
		Y = math.clamp(Y, 4, math.max(4, Screen.Y / Scale - Height - 4))

		local Frame = Owner.Frame
		if Animate then
			Frame.Position = UDim2.fromOffset(X, OpenUp and (Y + Height) or Y)
			Frame.Size = UDim2.fromOffset(Width, 0)
			CreateTween({Frame, "Size", UDim2.fromOffset(Width, Height), 0.2})
			CreateTween({Frame, "Position", UDim2.fromOffset(X, Y), 0.2})
		else
			CreateTween({Frame, "Size", UDim2.fromOffset(Width, Height), 0.12})
			CreateTween({Frame, "Position", UDim2.fromOffset(X, Y), 0.12})
		end
	end

	function Controller:Open(Owner)
		if self.Current and self.Current ~= Owner then
			self:Close(self.Current)
		end

		self.Current = Owner
		Blocker.Visible = true
		Owner.Frame.Visible = true
		self:Place(Owner, true)
	end

	function Controller:Close(Owner)
		Owner = Owner or self.Current
		if not Owner or self.Current ~= Owner then return end

		self.Current = nil
		Blocker.Visible = false

		if Owner.OnClose then
			Owner.OnClose()
		end

		local Frame = Owner.Frame
		CreateTween({Frame, "Size", UDim2.fromOffset(Owner.Width, 0), 0.15})
		task.delay(0.16, function()
			if Controller.Current ~= Owner then
				Frame.Visible = false
			end
		end)
	end

	function Controller:IsOpen(Owner)
		return self.Current == Owner
	end

	-- Keeps the popup glued to its anchor while the window moves / the list scrolls
	function Controller:Track(Owner)
		Owner.Anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if Controller.Current == Owner then
				Controller:Place(Owner, false)
			end
		end)
	end

	Blocker.Activated:Connect(function()
		Controller:Close()
	end)
	MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		Controller:Close()
	end)

	return Controller
end

-- ////////////////////////////////////////////////////////////////// --
--  Notifications
-- ////////////////////////////////////////////////////////////////// --
local NotifyHolder = Create("Frame", ScreenGui, {
	Name = "Notifications",
	Size = UDim2.new(0, 280, 1, -20),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -10),
	BackgroundTransparency = 1,
	ZIndex = 200
}, {
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right
	})
})

local NotifyColors = {
	Success = Color3.fromRGB(80, 200, 120),
	Warning = Color3.fromRGB(255, 185, 60),
	Error = Color3.fromRGB(240, 80, 80)
}

local NotifyCount, NotifyActive = 0, {}

-- Notify({Title = "", Content = "", Duration = 4, Type = "Info" | "Success" | "Warning" | "Error"})
function redzlib:Notify(Configs)
	if type(Configs) == "string" then
		Configs = {Content = Configs}
	end
	Configs = Configs or {}

	local Title = tostring(Configs[1] or Configs.Title or Configs.Name or "Notification")
	local Content = tostring(Configs[2] or Configs.Content or Configs.Text or Configs.Desc or Configs.Description or "")
	local Duration = tonumber(Configs[3] or Configs.Duration or Configs.Time) or 4
	local Kind = Configs.Type or "Info"

	NotifyCount = NotifyCount + 1
	while #NotifyActive >= 6 do
		local Oldest = table.remove(NotifyActive, 1)
		Oldest.Close()
	end

	local Wrap = Create("Frame", NotifyHolder, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = NotifyCount,
		Name = "Notification"
	})

	local Card = InsertTheme(Create("TextButton", Wrap, {
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 300, 0, 0),
		BackgroundColor3 = Theme["Color Hub 2"],
		BackgroundTransparency = 0.04
	}), "Frame")
	Make("Corner", Card, UDim.new(0, 6))
	Make("Stroke", Card)

	local Accent = Create("Frame", Card, {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.new(0, 7, 0, 6),
		BackgroundColor3 = NotifyColors[Kind] or Theme["Color Theme"]
	})
	Make("Corner", Accent, UDim.new(0.5, 0))
	if not NotifyColors[Kind] then
		InsertTheme(Accent, "Theme")
	end

	local Body = Create("Frame", Card, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 12)
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder
		}),
		InsertTheme(Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Theme["Color Text"],
			Text = Title,
			LayoutOrder = 1
		}), "Text"),
		InsertTheme(Create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Theme["Color Dark Text"],
			Text = Content,
			Visible = Content ~= "",
			LayoutOrder = 2
		}), "DarkText")
	})

	local Fill
	if Duration > 0 then
		local Track = Create("Frame", Card, {
			Size = UDim2.new(1, -14, 0, 2),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			BackgroundTransparency = 1
		})
		Fill = Create("Frame", Track, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = NotifyColors[Kind] or Theme["Color Theme"],
			BackgroundTransparency = 0.3
		})
		Make("Corner", Fill, UDim.new(0.5, 0))
		if not NotifyColors[Kind] then
			InsertTheme(Fill, "Theme")
		end
	end

	local Closed = false
	local Notification = {}

	local function Close()
		if Closed then return end
		Closed = true

		local Index = table.find(NotifyActive, Notification)
		if Index then
			table.remove(NotifyActive, Index)
		end

		CreateTween({Card, "Position", UDim2.new(0, 300, 0, 0), 0.3})
		task.delay(0.35, function()
			Wrap:Destroy()
		end)
	end

	Notification.Close = Close
	table.insert(NotifyActive, Notification)

	Card.Activated:Connect(Close)
	CreateTween({Card, "Position", UDim2.new(0, 0, 0, 0), 0.35})

	if Fill then
		CreateTween({Fill, "Size", UDim2.new(0, 0, 1, 0), Duration, false, Enum.EasingStyle.Linear})
		task.delay(Duration, Close)
	end

	return Notification
end


-- ////////////////////////////////////////////////////////////////// --
--  Element builders
--  Ctx = { Container, Register(Frame, Kind, Label) -> Entry, Popup, Tab }
-- ////////////////////////////////////////////////////////////////// --
local Builders = {}

local function ApplyBase(Obj, Frame, Entry, LabelFunc, SetLock)
	Obj.Frame = Frame

	function Obj:Visible(Bool)
		Entry:SetVisible(Bool)
	end
	function Obj:Destroy()
		Frame:Destroy()
	end
	function Obj:SetTitle(Val)
		LabelFunc:SetTitle(GetStr(Val))
	end
	function Obj:SetDesc(Val)
		LabelFunc:SetDesc(GetStr(Val))
	end
	function Obj:SetLocked(State)
		SetLock(State)
	end
	return Obj
end

-- ------------------------------------------------------------------ Section
function Builders.Section(Ctx, Configs)
	local SectionName = type(Configs) == "string" and Configs or Configs[1] or Configs.Name or Configs.Title or Configs.Section or "Section"

	local SectionFrame = Create("Frame", Ctx.Container, {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Name = "Option"
	})

	local SectionLabel = InsertTheme(Create("TextLabel", SectionFrame, {
		Font = Enum.Font.GothamBold,
		Text = SectionName,
		TextColor3 = Theme["Color Text"],
		Size = UDim2.new(1, -25, 1, 0),
		Position = UDim2.new(0, 5, 0, 0),
		BackgroundTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left
	}), "Text")

	local Label = {Title = SectionName, Desc = ""}
	local Entry = Ctx.Register(SectionFrame, "Section", Label)

	local Section = {Frame = SectionFrame}
	table.insert(redzlib.Options, {type = "Section", Name = SectionName, func = Section})

	function Section:Visible(Bool)
		Entry:SetVisible(Bool)
	end
	function Section:Destroy()
		SectionFrame:Destroy()
	end
	function Section:Set(New)
		if New ~= nil then
			Label.Title = tostring(GetStr(New))
			SectionLabel.Text = Label.Title
		end
	end
	Section.SetTitle = Section.Set

	return Section
end

-- ------------------------------------------------------------------ Paragraph / Label
function Builders.Paragraph(Ctx, Configs)
	if type(Configs) == "string" then
		Configs = {Configs}
	end

	local PName = Configs[1] or Configs.Title or "Paragraph"
	local PDesc = Configs[2] or Configs.Text or Configs.Desc or Configs.Description or ""

	local Frame, LabelFunc = ButtonFrame(Ctx.Container, GetStr(PName), GetStr(PDesc), UDim2.new(1, -20, 0, 0), true)
	local Entry = Ctx.Register(Frame, "Element", LabelFunc)
	local Paragraph = ApplyBase({}, Frame, Entry, LabelFunc, AddLock(Frame))

	function Paragraph:Set(Val1, Val2)
		if Val1 ~= nil and Val2 ~= nil then
			LabelFunc:SetTitle(GetStr(Val1))
			LabelFunc:SetDesc(GetStr(Val2))
		elseif Val1 ~= nil then
			LabelFunc:SetDesc(GetStr(Val1))
		end
	end

	return Paragraph
end

function Builders.Label(Ctx, Configs)
	if type(Configs) == "string" then
		Configs = {Configs}
	end

	local LText = Configs[1] or Configs.Text or Configs.Title or Configs.Name or "Label"
	local Frame, LabelFunc = ButtonFrame(Ctx.Container, GetStr(LText), "", UDim2.new(1, -20, 0, 0), true)
	local Entry = Ctx.Register(Frame, "Element", LabelFunc)
	local Label = ApplyBase({}, Frame, Entry, LabelFunc, AddLock(Frame))

	function Label:Set(Val)
		LabelFunc:SetTitle(GetStr(Val))
	end

	return Label
end

-- ------------------------------------------------------------------ Divider
function Builders.Divider(Ctx, Configs)
	local Holder = Create("Frame", Ctx.Container, {
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundTransparency = 1,
		Name = "Option"
	})

	local Line = InsertTheme(Create("Frame", Holder, {
		Size = UDim2.new(1, -10, 0, 1),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme["Color Stroke"]
	}), "Stroke")

	local Entry = Ctx.Register(Holder, "Divider", {Title = "", Desc = ""})
	local Divider = {Frame = Holder}

	function Divider:Visible(Bool)
		Entry:SetVisible(Bool)
	end
	function Divider:Destroy()
		Holder:Destroy()
	end

	return Divider
end

-- ------------------------------------------------------------------ Button
function Builders.Button(Ctx, Configs)
	local BName = Configs[1] or Configs.Name or Configs.Title or "Button!"
	local BDescription = Configs.Desc or Configs.Description or ""
	local Callback = Funcs:GetCallback(Configs, 2)

	local FButton, LabelFunc = ButtonFrame(Ctx.Container, BName, BDescription, UDim2.new(1, -20, 0, 0))
	local Entry = Ctx.Register(FButton, "Element", LabelFunc)
	local SetLock = AddLock(FButton)

	InsertTheme(Create("ImageLabel", FButton, {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://10709791437",
		ImageColor3 = Theme["Color Text"]
	}), "Text")

	if Configs.Disabled or Configs.Locked then
		SetLock(true)
	end

	FButton.Activated:Connect(function()
		Funcs:FireCallback(Callback)
	end)

	local Button = ApplyBase({}, FButton, Entry, LabelFunc, SetLock)

	function Button:Callback(Func)
		Funcs:InsertCallback(Callback, Func)
	end
	function Button:SetCallback(Func)
		Funcs:ReplaceCallback(Callback, Func)
	end
	function Button:Fire()
		Funcs:FireCallback(Callback)
	end
	function Button:Set(Val1, Val2)
		if type(Val1) == "string" and type(Val2) == "string" then
			LabelFunc:SetTitle(Val1)
			LabelFunc:SetDesc(Val2)
		elseif type(Val1) == "string" then
			LabelFunc:SetTitle(Val1)
		elseif type(Val1) == "function" then
			Funcs:ReplaceCallback(Callback, Val1)
		end
	end

	return Button
end

-- ------------------------------------------------------------------ Toggle
function Builders.Toggle(Ctx, Configs)
	local TName = Configs[1] or Configs.Name or Configs.Title or "Toggle"
	local TDesc = Configs.Desc or Configs.Description or ""
	local Callback = Funcs:GetCallback(Configs, 3)
	local Flag = Configs[4] or Configs.Flag or false

	local Default = Configs[2]
	if Default == nil then Default = Configs.Default end
	Default = Default == true
	if CheckFlag(Flag) then
		Default = GetFlag(Flag) == true
	end

	local Button, LabelFunc = ButtonFrame(Ctx.Container, TName, TDesc, UDim2.new(1, -38, 0, 0))
	local Entry = Ctx.Register(Button, "Element", LabelFunc)
	local SetLock = AddLock(Button)

	local ToggleHolder = InsertTheme(Create("Frame", Button, {
		Size = UDim2.new(0, 35, 0, 18),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme["Color Stroke"]
	}), "Stroke")
	Make("Corner", ToggleHolder, UDim.new(0.5, 0))

	local Knob = InsertTheme(Create("Frame", ToggleHolder, {
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme["Color Theme"]
	}), "Theme")
	Make("Corner", Knob, UDim.new(0.5, 0))

	local State = Default

	local function Visual(Instant)
		local Pos = State and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		local Transparency = State and 0 or 0.75

		if Instant then
			StopTweens(Knob)
			Knob.Position = Pos
			Knob.BackgroundTransparency = Transparency
		else
			CreateTween({Knob, "Position", Pos, 0.25})
			CreateTween({Knob, "BackgroundTransparency", Transparency, 0.25})
		end
	end

	local function Apply(Value)
		Value = Value == true
		if Value == State then return end

		State = Value
		SetFlag(Flag, State)
		Visual(false)
		Funcs:FireCallback(Callback, State)
	end

	Visual(true)
	SetFlag(Flag, State)
	Funcs:FireCallback(Callback, State)
	RegisterFlag(Flag, Apply)

	if Configs.Disabled or Configs.Locked then
		SetLock(true)
	end

	Button.Activated:Connect(function()
		Apply(not State)
	end)

	local Toggle = ApplyBase({}, Button, Entry, LabelFunc, SetLock)

	function Toggle:Get()
		return State
	end
	function Toggle:SetValue(Value)
		Apply(Value)
	end
	function Toggle:Callback(Func)
		if Funcs:InsertCallback(Callback, Func) then
			task.spawn(Func, State)
		end
	end
	function Toggle:OnChanged(Func)
		Funcs:InsertCallback(Callback, Func)
	end
	function Toggle:Set(Val1, Val2)
		if type(Val1) == "string" and type(Val2) == "string" then
			LabelFunc:SetTitle(Val1)
			LabelFunc:SetDesc(Val2)
		elseif type(Val1) == "string" then
			LabelFunc:SetTitle(Val1)
		elseif type(Val1) == "boolean" then
			Apply(Val1)
		elseif type(Val1) == "function" then
			Funcs:ReplaceCallback(Callback, Val1)
		end
	end

	return Toggle
end

-- ------------------------------------------------------------------ Dropdown
function Builders.Dropdown(Ctx, Configs)
	local DName = Configs[1] or Configs.Name or Configs.Title or "Dropdown"
	local DDesc = Configs.Desc or Configs.Description or ""
	local DOptions = Configs[2] or Configs.Options or {}
	local OpDefault = Configs[3]
	if OpDefault == nil then OpDefault = Configs.Default end
	local Flag = Configs[5] or Configs.Flag or false
	local Multi = Configs.MultiSelect or Configs.Multi or false
	local KeepOpen = Configs.KeepOpen or false
	local Callback = Funcs:GetCallback(Configs, 4)

	local Button, LabelFunc = ButtonFrame(Ctx.Container, DName, DDesc, UDim2.new(1, -180, 0, 0))
	local Entry = Ctx.Register(Button, "Element", LabelFunc)
	local SetLock = AddLock(Button)

	local SelectedFrame = InsertTheme(Create("Frame", Button, {
		Size = UDim2.new(0, 150, 0, 18),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme["Color Stroke"]
	}), "Stroke")
	Make("Corner", SelectedFrame, UDim.new(0, 4))

	local ActiveLabel = InsertTheme(Create("TextLabel", SelectedFrame, {
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme["Color Text"],
		Text = "..."
	}), "Text")

	local Arrow = InsertTheme(Create("ImageLabel", SelectedFrame, {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Image = "rbxassetid://10709790948",
		ImageColor3 = Theme["Color Text"],
		BackgroundTransparency = 1
	}), "Text")

	-- Popup -----------------------------------------------------------
	local PopupFrame = Ctx.Popup:NewFrame()
	local Owner = {Frame = PopupFrame, Anchor = SelectedFrame, Width = 160, Height = 60}

	local SearchRow = InsertTheme(Create("Frame", PopupFrame, {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 6),
		BackgroundColor3 = Theme["Color Stroke"],
		Visible = false
	}), "Stroke")
	Make("Corner", SearchRow, UDim.new(0, 4))

	local SearchBox = InsertTheme(Create("TextBox", SearchRow, {
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		PlaceholderText = "Search...",
		PlaceholderColor3 = Theme["Color Dark Text"],
		TextColor3 = Theme["Color Text"],
		Text = ""
	}), "Text")

	local ListFrame = InsertTheme(Create("ScrollingFrame", PopupFrame, {
		ScrollBarImageColor3 = Theme["Color Theme"],
		Size = UDim2.new(1, 0, 1, 0),
		ScrollBarThickness = 1.5,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Active = true
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5)
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder
		})
	}), "ScrollBar")

	-- State -----------------------------------------------------------
	local Options, Order = {}, {}      -- Options[Name] = Data   /   Order = list of names
	local Selected = Multi and {} or nil -- multi: Selected[Name] = true  /  single: Name
	local OrderCounter = 0

	local function IsOn(Name)
		if Multi then
			return Selected[Name] == true
		end
		return Selected == Name
	end

	local function UpdateVisuals()
		for Name, Data in pairs(Options) do
			local On = IsOn(Name)
			CreateTween({Data.Indicator, "BackgroundTransparency", On and 0 or 1, 0.3})
			CreateTween({Data.Indicator, "Size", On and UDim2.fromOffset(4, 12) or UDim2.fromOffset(4, 4), 0.3})
			CreateTween({Data.Label, "TextTransparency", On and 0 or 0.4, 0.3})
		end

		if Multi then
			local List = {}
			for _, Name in ipairs(Order) do
				if Selected[Name] then
					table.insert(List, Name)
				end
			end
			ActiveLabel.Text = #List > 0 and table.concat(List, ", ") or "..."
		else
			ActiveLabel.Text = Selected and tostring(Selected) or "..."
		end
	end

	local function GetCurrent()
		if Multi then
			local Out = {}
			for _, Name in ipairs(Order) do
				Out[Name] = Selected[Name] == true
			end
			return Out
		end

		local Data = Selected and Options[Selected]
		return Data and Data.Value or nil
	end

	local function Fire()
		if Multi then
			local Out = GetCurrent()
			SetFlag(Flag, Out)
			Funcs:FireCallback(Callback, Out)
		else
			SetFlag(Flag, Selected or "")
			Funcs:FireCallback(Callback, GetCurrent())
		end
	end

	local function Resize()
		local Count = 0
		for _, Data in pairs(Options) do
			if Data.Row.Visible then
				Count = Count + 1
			end
		end

		local ShowSearch = Configs.Search ~= false and #Order >= 8
		SearchRow.Visible = ShowSearch

		local Offset = ShowSearch and 32 or 0
		ListFrame.Position = UDim2.fromOffset(0, Offset)
		ListFrame.Size = UDim2.new(1, 0, 1, -Offset)

		Owner.Height = Offset + math.clamp(math.max(Count, 1), 1, 7) * 25 + 10
		if Ctx.Popup:IsOpen(Owner) then
			Ctx.Popup:Place(Owner, false)
		end
	end

	local function SetSelected(Name, State, Silent)
		if not Options[Name] then return end

		if Multi then
			Selected[Name] = State and true or nil
		elseif State then
			Selected = Name
		elseif Selected == Name then
			Selected = nil
		end

		UpdateVisuals()
		if not Silent then
			Fire()
		end
	end

	local function AddOption(Name, Value)
		Name = tostring(Name)
		if Options[Name] then return end

		OrderCounter = OrderCounter + 1
		local Row = Make("Button", ListFrame, {
			Name = "Option",
			Size = UDim2.new(1, 0, 0, 21),
			LayoutOrder = OrderCounter
		})
		Make("Corner", Row, UDim.new(0, 4))

		local Indicator = InsertTheme(Create("Frame", Row, {
			Position = UDim2.new(0, 1, 0.5, 0),
			Size = UDim2.new(0, 4, 0, 4),
			BackgroundColor3 = Theme["Color Theme"],
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5)
		}), "Theme")
		Make("Corner", Indicator, UDim.new(0.5, 0))

		local Label = InsertTheme(Create("TextLabel", Row, {
			Size = UDim2.new(1, -10, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			Text = Name,
			TextColor3 = Theme["Color Text"],
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			BackgroundTransparency = 1,
			TextTransparency = 0.4
		}), "Text")

		Options[Name] = {Name = Name, Value = Value, Row = Row, Indicator = Indicator, Label = Label}
		table.insert(Order, Name)

		Row.Activated:Connect(function()
			if Multi then
				SetSelected(Name, not Selected[Name])
			else
				SetSelected(Name, true)
				if not KeepOpen then
					Ctx.Popup:Close(Owner)
				end
			end
		end)
	end

	local function RemoveOption(Name, Silent)
		local Data = Options[Name]
		if not Data then return end

		if Multi then
			Selected[Name] = nil
		elseif Selected == Name then
			Selected = nil
		end

		Data.Row:Destroy()
		Options[Name] = nil

		local Index = table.find(Order, Name)
		if Index then
			table.remove(Order, Index)
		end

		if not Silent then
			UpdateVisuals()
			Resize()
			Fire()
		end
	end

	-- array  -> { {Name = tostring(v), Value = v} ... }
	-- dict   -> { {Name = key,         Value = value} ... } (sorted by key)
	local function Normalize(List)
		local Items = {}
		if type(List) ~= "table" then return Items end

		if #List > 0 then
			for _, Val in ipairs(List) do
				table.insert(Items, {Name = tostring(Val), Value = Val})
			end
		else
			local Keys = {}
			for Key in pairs(List) do
				table.insert(Keys, Key)
			end
			table.sort(Keys, function(A, B)
				return tostring(A) < tostring(B)
			end)
			for _, Key in ipairs(Keys) do
				table.insert(Items, {Name = tostring(Key), Value = List[Key]})
			end
		end
		return Items
	end

	local function ApplyValue(Value)
		if Multi then
			Selected = {}
			if type(Value) == "table" then
				for Key, Val in pairs(Value) do
					if type(Key) == "number" then
						if Options[tostring(Val)] then
							Selected[tostring(Val)] = true
						end
					elseif Val == true and Options[tostring(Key)] then
						Selected[tostring(Key)] = true
					end
				end
			elseif Value ~= nil and Options[tostring(Value)] then
				Selected[tostring(Value)] = true
			end
		else
			Selected = nil
			if type(Value) == "table" then
				Value = Value[1]
			end

			if Value ~= nil and Value ~= "" then
				if Options[tostring(Value)] then
					Selected = tostring(Value)
				else
					for Name, Data in pairs(Options) do
						if Data.Value == Value then
							Selected = Name
							break
						end
					end
				end
			end
		end
	end

	local function ClearOptions()
		for _, Name in ipairs(table.clone(Order)) do
			RemoveOption(Name, true)
		end
	end

	for _, Item in ipairs(Normalize(DOptions)) do
		AddOption(Item.Name, Item.Value)
	end

	local Initial = OpDefault
	if CheckFlag(Flag) then
		Initial = GetFlag(Flag)
	end
	ApplyValue(Initial)
	UpdateVisuals()
	Resize()
	Fire()

	RegisterFlag(Flag, function(Value)
		ApplyValue(Value)
		UpdateVisuals()
		Fire()
	end)

	-- Open / close ----------------------------------------------------
	local DMaid = ElementMaid(Button)

	Owner.OnClose = function()
		CreateTween({Arrow, "Rotation", 0, 0.2})
		SearchBox.Text = ""
	end

	Ctx.Popup:Track(Owner)

	Button.Activated:Connect(function()
		if Ctx.Popup:IsOpen(Owner) then
			Ctx.Popup:Close(Owner)
		else
			Resize()
			Ctx.Popup:Open(Owner)
			CreateTween({Arrow, "Rotation", 180, 0.2})
		end
	end)

	DMaid:Give(function()
		Ctx.Popup:Close(Owner)
		PopupFrame:Destroy()
	end)

	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local Query = string.lower(SearchBox.Text)
		for Name, Data in pairs(Options) do
			Data.Row.Visible = Query == "" or string.find(string.lower(Name), Query, 1, true) ~= nil
		end
		Resize()
	end)

	if Configs.Disabled or Configs.Locked then
		SetLock(true)
	end

	-- API -------------------------------------------------------------
	local Dropdown = ApplyBase({}, Button, Entry, LabelFunc, SetLock)

	local function ResolveName(Option)
		if type(Option) == "number" then
			return Order[Option]
		end
		return Option ~= nil and tostring(Option) or nil
	end

	function Dropdown:Get()
		return GetCurrent()
	end
	function Dropdown:Callback(Func)
		if Funcs:InsertCallback(Callback, Func) then
			task.spawn(Func, GetCurrent())
		end
	end
	function Dropdown:OnChanged(Func)
		Funcs:InsertCallback(Callback, Func)
	end
	function Dropdown:Add(...)
		local Args = {...}
		if type(Args[1]) == "table" then
			for _, Item in ipairs(Normalize(Args[1])) do
				AddOption(Item.Name, Item.Value)
			end
		else
			for _, Val in ipairs(Args) do
				AddOption(tostring(Val), Val)
			end
		end
		UpdateVisuals()
		Resize()
	end
	function Dropdown:Remove(Option)
		local Name = ResolveName(Option)
		if Name then
			RemoveOption(Name)
		end
	end
	function Dropdown:Clear()
		ClearOptions()
		UpdateVisuals()
		Resize()
		Fire()
	end
	-- Replaces every option. KeepSelection re-selects whatever still exists.
	function Dropdown:Refresh(List, KeepSelection)
		local Old = {}
		if KeepSelection then
			if Multi then
				for Name in pairs(Selected) do
					Old[Name] = true
				end
			elseif Selected then
				Old[Selected] = true
			end
		end

		ClearOptions()
		for _, Item in ipairs(Normalize(List)) do
			AddOption(Item.Name, Item.Value)
		end

		if Multi then
			Selected = {}
			for Name in pairs(Old) do
				if Options[Name] then
					Selected[Name] = true
				end
			end
		else
			Selected = nil
			for Name in pairs(Old) do
				if Options[Name] then
					Selected = Name
				end
			end
		end

		UpdateVisuals()
		Resize()
		Fire()
	end
	function Dropdown:Select(Option)
		local Name = ResolveName(Option)
		if Name then
			SetSelected(Name, true)
		end
	end
	function Dropdown:Deselect(Option)
		local Name = ResolveName(Option)
		if Name then
			SetSelected(Name, false)
		end
	end
	function Dropdown:SetValue(Value)
		ApplyValue(Value)
		UpdateVisuals()
		Fire()
	end
	-- Same behaviour as V5: Set(list) replaces the options, Set(list, true) appends them
	function Dropdown:Set(Val1, Clear)
		if type(Val1) == "table" then
			if Clear then
				Dropdown:Add(Val1)
			else
				Dropdown:Refresh(Val1)
			end
		elseif type(Val1) == "function" then
			Funcs:ReplaceCallback(Callback, Val1)
		elseif type(Val1) == "string" then
			Dropdown:Select(Val1)
		end
	end

	return Dropdown
end

-- ------------------------------------------------------------------ Slider
function Builders.Slider(Ctx, Configs)
	local SName = Configs[1] or Configs.Name or Configs.Title or "Slider!"
	local SDesc = Configs.Desc or Configs.Description or ""
	local Min = tonumber(Configs[2] or Configs.MinValue or Configs.Min) or 0
	local Max = tonumber(Configs[3] or Configs.MaxValue or Configs.Max) or 100
	local Step = tonumber(Configs[4] or Configs.Increase or Configs.Step) or 1
	local Default = tonumber(Configs[5] or Configs.Default)
	local Callback = Funcs:GetCallback(Configs, 6)
	local Flag = Configs[7] or Configs.Flag or false

	if Max < Min then
		Min, Max = Max, Min
	end
	if Step <= 0 then
		Step = 1
	end
	Default = Default or Min
	if CheckFlag(Flag) then
		Default = tonumber(GetFlag(Flag)) or Default
	end

	local function CountDecimals(Number)
		local Text = string.format("%.10f", Number):gsub("0+$", "")
		local Decimals = Text:match("%.(%d*)$")
		return Decimals and #Decimals or 0
	end

	local Decimals = math.max(CountDecimals(Step), CountDecimals(Min))
	local Format = "%." .. tostring(Decimals) .. "f"

	local function Round(Value)
		Value = math.clamp(Value, Min, Max)
		local Steps = math.floor((Value - Min) / Step + 0.5)
		Value = math.clamp(Min + Steps * Step, Min, Max)

		local Mult = 10 ^ Decimals
		return math.floor(Value * Mult + 0.5) / Mult
	end

	local Button, LabelFunc = ButtonFrame(Ctx.Container, SName, SDesc, UDim2.new(1, -190, 0, 0))
	local Entry = Ctx.Register(Button, "Element", LabelFunc)
	local SetLock = AddLock(Button)

	local SliderHolder = Create("Frame", Button, {
		Size = UDim2.new(0, 180, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1
	})

	local ValueFrame = InsertTheme(Create("Frame", SliderHolder, {
		Size = UDim2.fromOffset(40, 18),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme["Color Stroke"]
	}), "Stroke")
	Make("Corner", ValueFrame, UDim.new(0, 4))

	local ValueBox = InsertTheme(Create("TextBox", ValueFrame, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Theme["Color Text"],
		ClearTextOnFocus = false,
		Text = ""
	}), "Text")

	local BarArea = Create("TextButton", SliderHolder, {
		Text = "",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -48, 1, 0)
	})

	local SliderBar = InsertTheme(Create("Frame", BarArea, {
		BackgroundColor3 = Theme["Color Stroke"],
		Size = UDim2.new(1, -10, 0, 6),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5)
	}), "Stroke")
	Make("Corner", SliderBar, UDim.new(0.5, 0))

	local Indicator = InsertTheme(Create("Frame", SliderBar, {
		BackgroundColor3 = Theme["Color Theme"],
		Size = UDim2.fromScale(0, 1)
	}), "Theme")
	Make("Corner", Indicator, UDim.new(0.5, 0))

	local Knob = Create("Frame", SliderBar, {
		Size = UDim2.fromOffset(6, 12),
		BackgroundColor3 = Color3.fromRGB(220, 220, 220),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0.2
	})
	Make("Corner", Knob, UDim.new(0.5, 0))

	local Value = Round(Default)

	local function Display(Animate)
		local Range = Max - Min
		local Rel = Range > 0 and (Value - Min) / Range or 0

		ValueBox.Text = string.format(Format, Value)
		if Animate then
			CreateTween({Knob, "Position", UDim2.fromScale(Rel, 0.5), 0.25})
			CreateTween({Indicator, "Size", UDim2.fromScale(Rel, 1), 0.25})
		else
			StopTweens(Knob)
			StopTweens(Indicator)
			Knob.Position = UDim2.fromScale(Rel, 0.5)
			Indicator.Size = UDim2.fromScale(Rel, 1)
		end
	end

	local function Commit(NewValue, Animate)
		NewValue = Round(NewValue)
		local Changed = NewValue ~= Value
		Value = NewValue
		Display(Animate)

		if Changed then
			SetFlag(Flag, Value)
			Funcs:FireCallback(Callback, Value)
		end
	end

	local function FromInput(Input)
		local Rel = math.clamp((Input.Position.X - SliderBar.AbsolutePosition.X) / math.max(SliderBar.AbsoluteSize.X, 1), 0, 1)
		Commit(Min + Rel * (Max - Min), false)
	end

	Display(false)
	SetFlag(Flag, Value)
	Funcs:FireCallback(Callback, Value)
	RegisterFlag(Flag, function(Val)
		if tonumber(Val) then
			Commit(tonumber(Val), true)
		end
	end)

	TrackDrag(BarArea, function(Input)
		Ctx.Container.ScrollingEnabled = false
		CreateTween({Knob, "BackgroundTransparency", 0, 0.2})
		FromInput(Input)
	end, function(_, Input)
		FromInput(Input)
	end, function()
		Ctx.Container.ScrollingEnabled = true
		CreateTween({Knob, "BackgroundTransparency", 0.2, 0.2})
		SetFlag(Flag, Value)
	end)

	ValueBox.FocusLost:Connect(function()
		local Typed = tonumber(ValueBox.Text)
		if Typed then
			Commit(Typed, true)
		else
			Display(false)
		end
	end)

	if Configs.Disabled or Configs.Locked then
		SetLock(true)
	end

	local Slider = ApplyBase({}, Button, Entry, LabelFunc, SetLock)

	function Slider:Get()
		return Value
	end
	function Slider:SetValue(NewValue)
		if type(NewValue) == "number" then
			Commit(NewValue, true)
		end
	end
	function Slider:Callback(Func)
		if Funcs:InsertCallback(Callback, Func) then
			task.spawn(Func, Value)
		end
	end
	function Slider:OnChanged(Func)
		Funcs:InsertCallback(Callback, Func)
	end
	function Slider:Set(NewVal1, NewVal2)
		if type(NewVal1) == "string" and type(NewVal2) == "string" then
			LabelFunc:SetTitle(NewVal1)
			LabelFunc:SetDesc(NewVal2)
		elseif type(NewVal1) == "string" then
			LabelFunc:SetTitle(NewVal1)
		elseif type(NewVal1) == "function" then
			Funcs:ReplaceCallback(Callback, NewVal1)
		elseif type(NewVal1) == "number" then
			Commit(NewVal1, true)
		end
	end

	return Slider
end

-- ------------------------------------------------------------------ TextBox
function Builders.TextBox(Ctx, Configs)
	local TName = Configs[1] or Configs.Name or Configs.Title or "Text Box"
	local TDesc = Configs.Desc or Configs.Description or ""
	local TDefault = Configs[2] or Configs.Default or ""
	local TClearText = Configs[3] or Configs.ClearText or false
	local Callback = Funcs:GetCallback(Configs, 4)
	local TPlaceholder = Configs[5] or Configs.PlaceholderText or "Input"
	local Flag = Configs[6] or Configs.Flag or false
	local Numeric = Configs.Numeric or false
	local Live = Configs.Live or false

	TDefault = tostring(TDefault)
	if CheckFlag(Flag) then
		TDefault = tostring(GetFlag(Flag))
	end

	local Button, LabelFunc = ButtonFrame(Ctx.Container, TName, TDesc, UDim2.new(1, -180, 0, 0))
	local Entry = Ctx.Register(Button, "Element", LabelFunc)
	local SetLock = AddLock(Button)

	local BoxFrame = InsertTheme(Create("Frame", Button, {
		Size = UDim2.new(0, 150, 0, 18),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme["Color Stroke"]
	}), "Stroke")
	Make("Corner", BoxFrame, UDim.new(0, 4))

	local Pencil = InsertTheme(Create("ImageLabel", BoxFrame, {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(0, 6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Image = "rbxassetid://15637081879",
		ImageColor3 = Theme["Color Text"],
		BackgroundTransparency = 1
	}), "Text")

	local Input = InsertTheme(Create("TextBox", BoxFrame, {
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.fromOffset(22, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme["Color Text"],
		ClearTextOnFocus = TClearText,
		PlaceholderText = TPlaceholder,
		PlaceholderColor3 = Theme["Color Dark Text"],
		Text = ""
	}), "Text")

	local TextBox = {OnChanging = false}
	local Value = ""

	local function Process(Text)
		if Numeric then
			Text = Text:gsub("[^%d%.%-]", "")
		end
		if type(TextBox.OnChanging) == "function" then
			local Ok, Result = pcall(TextBox.OnChanging, Text)
			if Ok and type(Result) == "string" then
				Text = Result
			end
		end
		return Text
	end

	local function Fire(Text)
		if Numeric then
			local Number = tonumber(Text)
			if Number == nil then return end
			Funcs:FireCallback(Callback, Number)
		else
			Funcs:FireCallback(Callback, Text)
		end
	end

	local function Commit(Text, Force)
		Text = Process(tostring(Text))
		Input.Text = Text

		if Text == Value and not Force then return end
		Value = Text
		SetFlag(Flag, Value)
		Fire(Value)
	end

	Input.Text = Process(TDefault)
	Value = Input.Text
	SetFlag(Flag, Value)
	if Value:match("%S") then
		Fire(Value)
	end
	RegisterFlag(Flag, function(Val)
		Commit(Val)
	end)

	Input.FocusLost:Connect(function()
		CreateTween({Pencil, "ImageColor3", Theme["Color Text"], 0.2})
		Commit(Input.Text)
	end)
	Input.Focused:Connect(function()
		CreateTween({Pencil, "ImageColor3", Theme["Color Theme"], 0.2})
	end)
	Input:GetPropertyChangedSignal("Text"):Connect(function()
		if Live and Input:IsFocused() then
			Fire(Input.Text)
		end
	end)

	if Configs.Disabled or Configs.Locked then
		SetLock(true)
	end

	ApplyBase(TextBox, Button, Entry, LabelFunc, SetLock)

	function TextBox:Get()
		return Value
	end
	function TextBox:SetValue(Text)
		Commit(Text)
	end
	function TextBox:Set(Val1, Val2)
		if type(Val1) == "function" then
			Funcs:ReplaceCallback(Callback, Val1)
		elseif type(Val1) == "string" and type(Val2) == "string" then
			LabelFunc:SetTitle(Val1)
			LabelFunc:SetDesc(Val2)
		elseif Val1 ~= nil then
			Commit(Val1)
		end
	end
	function TextBox:Callback(Func)
		Funcs:InsertCallback(Callback, Func)
	end
	function TextBox:Focus()
		Input:CaptureFocus()
	end

	return TextBox
end

-- ------------------------------------------------------------------ Keybind
function Builders.Keybind(Ctx, Configs)
	local KName = Configs[1] or Configs.Name or Configs.Title or "Keybind"
	local KDesc = Configs.Desc or Configs.Description or ""
	local Default = Configs[2]
	if Default == nil then Default = Configs.Default end
	local Callback = Funcs:GetCallback(Configs, 3)
	local Flag = Configs[4] or Configs.Flag or false
	local Hold = Configs.Hold or false

	local Changed = {}
	if type(Configs.OnChanged) == "function" then
		table.insert(Changed, Configs.OnChanged)
	end

	local function ParseKey(Val)
		if typeof(Val) == "EnumItem" and Val.EnumType == Enum.KeyCode then
			return Val
		end
		if type(Val) == "string" then
			local Ok, Item = pcall(function()
				return Enum.KeyCode[Val]
			end)
			if Ok then
				return Item
			end
		end
		return nil
	end

	if CheckFlag(Flag) then
		Default = GetFlag(Flag)
	end
	local Key = ParseKey(Default)

	local Button, LabelFunc = ButtonFrame(Ctx.Container, KName, KDesc, UDim2.new(1, -100, 0, 0))
	local Entry = Ctx.Register(Button, "Element", LabelFunc)
	local SetLock = AddLock(Button)

	local KeyFrame = InsertTheme(Create("Frame", Button, {
		Size = UDim2.new(0, 80, 0, 18),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme["Color Stroke"]
	}), "Stroke")
	Make("Corner", KeyFrame, UDim.new(0, 4))

	local KeyLabel = InsertTheme(Create("TextLabel", KeyFrame, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Theme["Color Text"],
		Text = "None"
	}), "Text")

	local Listening = false
	local KMaid = ElementMaid(Button)

	local function Refresh()
		KeyLabel.Text = Listening and "..." or (Key and Key.Name or "None")
	end

	local function SetKey(NewKey, Silent)
		Key = NewKey
		Listening = false
		Refresh()
		SetFlag(Flag, Key or "None")
		if not Silent then
			Funcs:FireCallback(Changed, Key)
		end
	end

	Refresh()
	SetFlag(Flag, Key or "None")
	RegisterFlag(Flag, function(Val)
		SetKey(ParseKey(Val))
	end)

	Button.Activated:Connect(function()
		Listening = true
		Refresh()
	end)

	KMaid:Give(UserInputService.InputBegan:Connect(function(Input, Processed)
		if Listening then
			if Input.UserInputType ~= Enum.UserInputType.Keyboard then return end

			if Input.KeyCode == Enum.KeyCode.Escape then
				Listening = false
				Refresh()
			elseif Input.KeyCode == Enum.KeyCode.Backspace then
				SetKey(nil)
			else
				SetKey(Input.KeyCode)
			end
			return
		end

		if Processed or not Key then return end
		if Input.KeyCode == Key then
			Funcs:FireCallback(Callback, true, Key)
		end
	end))

	if Hold then
		KMaid:Give(UserInputService.InputEnded:Connect(function(Input)
			if not Listening and Key and Input.KeyCode == Key then
				Funcs:FireCallback(Callback, false, Key)
			end
		end))
	end

	if Configs.Disabled or Configs.Locked then
		SetLock(true)
	end

	local Keybind = ApplyBase({}, Button, Entry, LabelFunc, SetLock)

	function Keybind:Get()
		return Key
	end
	function Keybind:SetValue(NewKey)
		SetKey(ParseKey(NewKey))
	end
	function Keybind:Set(Val1)
		if type(Val1) == "function" then
			Funcs:ReplaceCallback(Callback, Val1)
		else
			SetKey(ParseKey(Val1))
		end
	end
	function Keybind:Callback(Func)
		Funcs:InsertCallback(Callback, Func)
	end
	function Keybind:OnChanged(Func)
		Funcs:InsertCallback(Changed, Func)
	end

	return Keybind
end

-- ------------------------------------------------------------------ ColorPicker
function Builders.ColorPicker(Ctx, Configs)
	local CName = Configs[1] or Configs.Name or Configs.Title or "Color"
	local CDesc = Configs.Desc or Configs.Description or ""
	local Default = Configs[2]
	if Default == nil then Default = Configs.Default end
	local Callback = Funcs:GetCallback(Configs, 3)
	local Flag = Configs[4] or Configs.Flag or false

	if typeof(Default) ~= "Color3" then
		Default = Color3.fromRGB(255, 255, 255)
	end
	if CheckFlag(Flag) and typeof(GetFlag(Flag)) == "Color3" then
		Default = GetFlag(Flag)
	end

	local Button, LabelFunc = ButtonFrame(Ctx.Container, CName, CDesc, UDim2.new(1, -60, 0, 0))
	local Entry = Ctx.Register(Button, "Element", LabelFunc)
	local SetLock = AddLock(Button)

	local Swatch = Create("Frame", Button, {
		Size = UDim2.fromOffset(30, 16),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Default
	})
	Make("Corner", Swatch, UDim.new(0, 4))
	Make("Stroke", Swatch)

	local H, S, V = Default:ToHSV()
	local Color = Default

	-- Popup -----------------------------------------------------------
	local PopupFrame = Ctx.Popup:NewFrame()
	local Owner = {Frame = PopupFrame, Anchor = Swatch, Width = 190, Height = 150}

	local SVBox = Create("TextButton", PopupFrame, {
		Text = "",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(174, 84),
		BackgroundColor3 = Color3.fromHSV(H, 1, 1)
	})
	Make("Corner", SVBox, UDim.new(0, 4))

	Create("Frame", SVBox, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	}, {
		Create("UIGradient", {Transparency = NumberSequence.new(0, 1)}),
		Create("UICorner", {CornerRadius = UDim.new(0, 4)})
	})

	Create("Frame", SVBox, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	}, {
		Create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}),
		Create("UICorner", {CornerRadius = UDim.new(0, 4)})
	})

	local SVCursor = Create("Frame", SVBox, {
		Size = UDim2.fromOffset(9, 9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0.5, 0)}),
		Create("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 2})
	})

	local HueKeys = {}
	for Index = 0, 6 do
		table.insert(HueKeys, ColorSequenceKeypoint.new(Index / 6, Color3.fromHSV(math.min(Index / 6, 0.999), 1, 1)))
	end
	HueKeys[7] = ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))

	local HueBar = Create("TextButton", PopupFrame, {
		Text = "",
		Position = UDim2.fromOffset(8, 100),
		Size = UDim2.fromOffset(174, 10),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	}, {
		Create("UIGradient", {Color = ColorSequence.new(HueKeys)}),
		Create("UICorner", {CornerRadius = UDim.new(0.5, 0)})
	})

	local HueCursor = Create("Frame", HueBar, {
		Size = UDim2.fromOffset(4, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 3
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 2)}),
		Create("UIStroke", {Color = Color3.fromRGB(0, 0, 0), Thickness = 1, Transparency = 0.5})
	})

	local HexFrame = InsertTheme(Create("Frame", PopupFrame, {
		Position = UDim2.fromOffset(8, 118),
		Size = UDim2.fromOffset(174, 22),
		BackgroundColor3 = Theme["Color Stroke"]
	}), "Stroke")
	Make("Corner", HexFrame, UDim.new(0, 4))

	local HexBox = InsertTheme(Create("TextBox", HexFrame, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Theme["Color Text"],
		ClearTextOnFocus = false,
		Text = ""
	}), "Text")

	local function ToHex(Value)
		return string.format("#%02X%02X%02X", math.floor(Value.R * 255 + 0.5), math.floor(Value.G * 255 + 0.5), math.floor(Value.B * 255 + 0.5))
	end

	local function Display()
		Color = Color3.fromHSV(H, S, V)
		Swatch.BackgroundColor3 = Color
		SVBox.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
		SVCursor.Position = UDim2.fromScale(S, 1 - V)
		HueCursor.Position = UDim2.new(H, 0, 0.5, 0)
		HexBox.Text = ToHex(Color)
	end

	local function Commit()
		Display()
		SetFlag(Flag, Color)
		Funcs:FireCallback(Callback, Color)
	end

	local function FromSV(Input)
		local Pos, Size = SVBox.AbsolutePosition, SVBox.AbsoluteSize
		S = math.clamp((Input.Position.X - Pos.X) / math.max(Size.X, 1), 0, 1)
		V = 1 - math.clamp((Input.Position.Y - Pos.Y) / math.max(Size.Y, 1), 0, 1)
		Commit()
	end

	local function FromHue(Input)
		local Pos, Size = HueBar.AbsolutePosition, HueBar.AbsoluteSize
		H = math.clamp((Input.Position.X - Pos.X) / math.max(Size.X, 1), 0, 0.999)
		Commit()
	end

	TrackDrag(SVBox, FromSV, function(_, Input)
		FromSV(Input)
	end)
	TrackDrag(HueBar, FromHue, function(_, Input)
		FromHue(Input)
	end)

	HexBox.FocusLost:Connect(function()
		local Hex = HexBox.Text:match("^#?(%x%x%x%x%x%x)$")
		if Hex then
			local R = tonumber(Hex:sub(1, 2), 16)
			local G = tonumber(Hex:sub(3, 4), 16)
			local B = tonumber(Hex:sub(5, 6), 16)
			H, S, V = Color3.fromRGB(R, G, B):ToHSV()
			Commit()
		else
			Display()
		end
	end)

	Display()
	SetFlag(Flag, Color)
	Funcs:FireCallback(Callback, Color)
	RegisterFlag(Flag, function(Val)
		if typeof(Val) == "Color3" then
			H, S, V = Val:ToHSV()
			Commit()
		end
	end)

	local CMaid = ElementMaid(Button)
	Ctx.Popup:Track(Owner)
	Owner.OnClose = function() end

	Button.Activated:Connect(function()
		if Ctx.Popup:IsOpen(Owner) then
			Ctx.Popup:Close(Owner)
		else
			Ctx.Popup:Open(Owner)
		end
	end)

	CMaid:Give(function()
		Ctx.Popup:Close(Owner)
		PopupFrame:Destroy()
	end)

	if Configs.Disabled or Configs.Locked then
		SetLock(true)
	end

	local ColorPicker = ApplyBase({}, Button, Entry, LabelFunc, SetLock)

	function ColorPicker:Get()
		return Color
	end
	function ColorPicker:SetValue(NewColor)
		if typeof(NewColor) == "Color3" then
			H, S, V = NewColor:ToHSV()
			Commit()
		end
	end
	function ColorPicker:Set(Val1)
		if type(Val1) == "function" then
			Funcs:ReplaceCallback(Callback, Val1)
		elseif typeof(Val1) == "Color3" then
			ColorPicker:SetValue(Val1)
		end
	end
	function ColorPicker:Callback(Func)
		if Funcs:InsertCallback(Callback, Func) then
			task.spawn(Func, Color)
		end
	end
	function ColorPicker:OnChanged(Func)
		Funcs:InsertCallback(Callback, Func)
	end

	return ColorPicker
end

-- ------------------------------------------------------------------ Discord invite
local function JoinDiscord(Invite)
	local Code = tostring(Invite):match("discord%.gg/([%w%-_]+)") or tostring(Invite):match("discord%.com/invite/([%w%-_]+)") or tostring(Invite):match("^([%w%-_]+)$")
	if not (Code and Env.Request) then return false end

	local Ok, Response = pcall(Env.Request, {
		Url = "http://127.0.0.1:6463/rpc?v=1",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Origin"] = "https://discord.com"
		},
		Body = HttpService:JSONEncode({
			cmd = "INVITE_BROWSER",
			args = {code = Code},
			nonce = HttpService:GenerateGUID(false)
		})
	})
	return Ok and Response ~= nil
end

function Builders.DiscordInvite(Ctx, Configs)
	local Title = Configs[1] or Configs.Name or Configs.Title or "Discord"
	local Desc = Configs.Desc or Configs.Description or ""
	local Logo = Configs[2] or Configs.Logo or ""
	local Invite = Configs[3] or Configs.Invite or ""

	local InviteHolder = Create("Frame", Ctx.Container, {
		Size = UDim2.new(1, 0, 0, 80),
		Name = "Option",
		BackgroundTransparency = 1
	})
	local Entry = Ctx.Register(InviteHolder, "Element", {Title = Title, Desc = Desc})

	Create("TextLabel", InviteHolder, {
		Size = UDim2.new(1, 0, 0, 15),
		Position = UDim2.new(0, 5, 0, 0),
		TextColor3 = Color3.fromRGB(40, 150, 255),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		TextSize = 10,
		Text = Invite
	})

	local FrameHolder = InsertTheme(Create("Frame", InviteHolder, {
		Size = UDim2.new(1, 0, 0, 65),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme["Color Hub 2"]
	}), "Frame")
	Make("Corner", FrameHolder)

	local ImageLabel = Create("ImageLabel", FrameHolder, {
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(0, 7, 0, 7),
		Image = redzlib:GetIcon(Logo),
		BackgroundTransparency = 1
	})
	Make("Corner", ImageLabel, UDim.new(0, 4))
	Make("Stroke", ImageLabel)

	InsertTheme(Create("TextLabel", FrameHolder, {
		Size = UDim2.new(1, -52, 0, 15),
		Position = UDim2.new(0, 44, 0, 7),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme["Color Text"],
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundTransparency = 1,
		TextSize = 10,
		Text = Title
	}), "Text")

	InsertTheme(Create("TextLabel", FrameHolder, {
		Size = UDim2.new(1, -52, 0, 0),
		Position = UDim2.new(0, 44, 0, 22),
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme["Color Dark Text"],
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		BackgroundTransparency = 1,
		TextSize = 8,
		Text = Desc
	}), "DarkText")

	local JoinButton = Create("TextButton", FrameHolder, {
		Size = UDim2.new(1, -14, 0, 16),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Text = "Join",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	})
	Make("Corner", JoinButton, UDim.new(0, 5))

	local ClickDelay = false
	JoinButton.Activated:Connect(function()
		if ClickDelay then return end
		ClickDelay = true

		local Copied = false
		if Env.SetClipboard then
			Copied = (pcall(Env.SetClipboard, Invite))
		end
		local Joined = JoinDiscord(Invite)

		SetProps(JoinButton, {
			Text = Joined and "Opened in Discord" or (Copied and "Copied to Clipboard" or "Invite: " .. tostring(Invite)),
			BackgroundColor3 = Color3.fromRGB(100, 100, 100),
			TextColor3 = Color3.fromRGB(150, 150, 150)
		})
		task.wait(5)
		SetProps(JoinButton, {
			Text = "Join",
			BackgroundColor3 = Color3.fromRGB(50, 150, 50),
			TextColor3 = Color3.fromRGB(220, 220, 220)
		})
		ClickDelay = false
	end)

	local DiscordInvite = {Frame = InviteHolder}
	function DiscordInvite:Destroy()
		InviteHolder:Destroy()
	end
	function DiscordInvite:Visible(Bool)
		Entry:SetVisible(Bool)
	end

	return DiscordInvite
end

-- ------------------------------------------------------------------ Config manager (ready-made UI)
function Builders.ConfigManager(Ctx, Configs)
	Configs = Configs or {}

	Builders.Section(Ctx, Configs.Title or "Configs")

	local ConfigName, Chosen = "", nil

	Builders.TextBox(Ctx, {
		Name = "Config name",
		Placeholder = "my config",
		PlaceholderText = "my config",
		Callback = function(Text)
			ConfigName = Text
		end
	})

	local Picker = Builders.Dropdown(Ctx, {
		Name = "Saved configs",
		Options = redzlib:ListConfigs(),
		Callback = function(Value)
			Chosen = Value
		end
	})

	Builders.Button(Ctx, {
		Name = "Save config",
		Desc = "Saves every flag under the typed name (or the selected one)",
		Callback = function()
			local Name = ConfigName:match("%S") and ConfigName or Chosen
			if not Name or Name == "" then
				redzlib:Notify({Title = "Config", Content = "Type a name or pick a config first.", Type = "Warning"})
				return
			end

			if redzlib:SaveConfig(Name) then
				redzlib:Notify({Title = "Config saved", Content = tostring(Name), Type = "Success"})
				Picker:Refresh(redzlib:ListConfigs(), true)
			else
				redzlib:Notify({Title = "Config", Content = "Could not save (no file access?).", Type = "Error"})
			end
		end
	})

	Builders.Button(Ctx, {
		Name = "Load config",
		Callback = function()
			if not Chosen or Chosen == "" then
				redzlib:Notify({Title = "Config", Content = "Pick a config first.", Type = "Warning"})
			elseif redzlib:LoadConfig(Chosen) then
				redzlib:Notify({Title = "Config loaded", Content = tostring(Chosen), Type = "Success"})
			else
				redzlib:Notify({Title = "Config", Content = "Could not load that config.", Type = "Error"})
			end
		end
	})

	Builders.Button(Ctx, {
		Name = "Delete config",
		Callback = function()
			if Chosen and Chosen ~= "" and redzlib:DeleteConfig(Chosen) then
				redzlib:Notify({Title = "Config deleted", Content = tostring(Chosen), Type = "Success"})
				Chosen = nil
				Picker:Refresh(redzlib:ListConfigs())
			else
				redzlib:Notify({Title = "Config", Content = "Nothing deleted.", Type = "Warning"})
			end
		end
	})

	Builders.Button(Ctx, {
		Name = "Refresh list",
		Callback = function()
			Picker:Refresh(redzlib:ListConfigs(), true)
		end
	})
end

-- ------------------------------------------------------------------ Theme selector (ready-made)
function Builders.ThemeSelector(Ctx, Configs)
	Configs = Configs or {}

	return Builders.Dropdown(Ctx, {
		Name = Configs.Name or "Theme",
		Desc = Configs.Desc or "Changes the UI colors (saved automatically)",
		Options = redzlib:GetThemes(),
		Default = redzlib.Save.Theme,
		Callback = function(Value)
			if type(Value) == "string" and Value ~= redzlib.Save.Theme then
				redzlib:SetTheme(Value)
			end
		end
	})
end

-- ////////////////////////////////////////////////////////////////// --
--  Config files (named presets of every flag)
-- ////////////////////////////////////////////////////////////////// --
local function ConfigPath(Name)
	local Safe = tostring(Name or ""):gsub("[^%w%-_ ]", "")
	Safe = Safe:match("^%s*(.-)%s*$")
	if Safe == "" then return nil end
	return Settings.ConfigFolder .. "/" .. Safe .. ".json"
end

function redzlib:SaveConfig(Name)
	local Path = ConfigPath(Name)
	if not Path then return false end

	local Encoded = EncodeJson(Flags)
	return Encoded ~= nil and WriteRaw(Path, Encoded)
end

function redzlib:LoadConfig(Name)
	local Path = ConfigPath(Name)
	if not Path then return false end

	local Data = DecodeJson(ReadRaw(Path))
	if type(Data) ~= "table" then return false end

	for Flag, Value in pairs(Data) do
		local Setter = FlagSetters[Flag]
		if Setter then
			pcall(Setter, Value)
		else
			Flags[Flag] = Value
		end
	end

	Connection:FireConnection("ConfigLoaded", Name)
	return true
end

function redzlib:ListConfigs()
	local List = {}
	if not Env.ListFiles then return List end

	EnsureFolder(Settings.ConfigFolder .. "/x")
	local Ok, Files = pcall(Env.ListFiles, Settings.ConfigFolder)
	if Ok and type(Files) == "table" then
		for _, Path in ipairs(Files) do
			local Name = tostring(Path):match("([^/\\]+)%.json$")
			if Name then
				table.insert(List, Name)
			end
		end
	end

	table.sort(List)
	return List
end

function redzlib:DeleteConfig(Name)
	local Path = ConfigPath(Name)
	if not (Path and Env.DelFile) then return false end
	return (pcall(Env.DelFile, Path))
end


-- ////////////////////////////////////////////////////////////////// --
--  Window
-- ////////////////////////////////////////////////////////////////// --
local function RefreshEntry(Entry)
	Entry.Frame.Visible = not (Entry.Hidden or Entry.Filtered)
end

function redzlib:MakeWindow(Configs)
	Configs = Configs or {}

	local WTitle = Configs[1] or Configs.Name or Configs.Title or "redz Library V5"
	local WMiniText = Configs[2] or Configs.SubTitle or "by : redz9999"
	Settings.ScriptFile = Configs[3] or Configs.SaveFolder or false

	local ToggleKey = Configs.ToggleKey
	if ToggleKey == nil then
		ToggleKey = Enum.KeyCode.RightShift
	end
	local UseSearch = Configs.Search ~= false

	table.clear(redzlib.Tabs)

	-- Load saved flags (applied as defaults while the elements are created)
	if type(Settings.ScriptFile) == "string" then
		local Data = DecodeJson(ReadRaw(Settings.ScriptFile))
		if type(Data) == "table" then
			for Key, Value in pairs(Data) do
				Flags[Key] = Value
			end
		end
	end

	local SizeX = tonumber(redzlib.Save.UISize[1]) or 550
	local SizeY = tonumber(redzlib.Save.UISize[2]) or 380
	local TabWidth = tonumber(redzlib.Save.TabSize) or 160

	local MainFrame = InsertTheme(Create("ImageButton", ScreenGui, {
		Size = UDim2.fromOffset(SizeX, SizeY),
		Position = UDim2.new(0.5, -SizeX / 2, 0.5, -SizeY / 2),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.03,
		Active = true,
		Name = "Hub"
	}), "Main")
	Make("Gradient", MainFrame, {Rotation = 45})
	local MainCorner = Make("Corner", MainFrame)

	local Components = Create("Folder", MainFrame, {Name = "Components"})
	local Popup = MakePopupController(MainFrame)

	-- Top bar -----------------------------------------------------------
	local TopBar = Create("Frame", Components, {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Active = true,
		Name = "Top Bar"
	})

	local Title = InsertTheme(Create("TextLabel", TopBar, {
		Position = UDim2.new(0, 15, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		AutomaticSize = Enum.AutomaticSize.XY,
		Text = WTitle,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 12,
		TextColor3 = Theme["Color Text"],
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Name = "Title"
	}, {
		InsertTheme(Create("TextLabel", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(1, 5, 0.9, 0),
			Text = WMiniText,
			TextColor3 = Theme["Color Dark Text"],
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			TextSize = 8,
			Font = Enum.Font.Gotham,
			Name = "SubTitle"
		}), "DarkText")
	}), "Text")

	MakeDrag(TopBar, MainFrame)

	local MainScroll = InsertTheme(Create("ScrollingFrame", Components, {
		Size = UDim2.new(0, TabWidth, 1, -TopBar.Size.Y.Offset),
		ScrollBarImageColor3 = Theme["Color Theme"],
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		ScrollBarThickness = 1.5,
		BackgroundTransparency = 1,
		ScrollBarImageTransparency = 0.2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		Active = true,
		Name = "Tab Scroll"
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10)
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder
		})
	}), "ScrollBar")

	local Containers = Create("Frame", Components, {
		Size = UDim2.new(1, -TabWidth, 1, -TopBar.Size.Y.Offset),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Name = "Containers"
	})

	-- Resize handles ----------------------------------------------------
	local SizeHandle = Create("ImageButton", MainFrame, {
		Size = UDim2.fromOffset(24, 24),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Active = true,
		Name = "Control Hub Size"
	})

	local TabHandle = Create("ImageButton", MainFrame, {
		Size = UDim2.new(0, 14, 1, -TopBar.Size.Y.Offset - 24),
		Position = UDim2.new(0, TabWidth, 0, TopBar.Size.Y.Offset),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Active = true,
		Name = "Control Tab Size"
	})

	local function SetTabWidth(Width)
		TabWidth = math.clamp(Width, 135, 250)
		MainScroll.Size = UDim2.new(0, TabWidth, 1, -TopBar.Size.Y.Offset)
		Containers.Size = UDim2.new(1, -TabWidth, 1, -TopBar.Size.Y.Offset)
		TabHandle.Position = UDim2.new(0, TabWidth, 0, TopBar.Size.Y.Offset)
	end

	local Minimized, SaveSize, WaitClick = false, nil, false

	do
		local StartW, StartH
		TrackDrag(SizeHandle, function()
			StartW, StartH = MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset
		end, function(Delta)
			MainFrame.Size = UDim2.fromOffset(math.clamp(StartW + Delta.X, 430, 1100), math.clamp(StartH + Delta.Y, 240, 700))
		end, function()
			if not Minimized then
				redzlib.Save.UISize = {MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset}
				SaveSettings()
			end
		end)

		local StartTab
		TrackDrag(TabHandle, function()
			StartTab = TabWidth
		end, function(Delta)
			SetTabWidth(StartTab + Delta.X)
		end, function()
			redzlib.Save.TabSize = TabWidth
			SaveSettings()
		end)
	end

	-- Top bar buttons -----------------------------------------------------
	local ButtonsFolder = Create("Folder", TopBar, {Name = "Buttons"})

	local CloseButton = InsertTheme(Create("ImageButton", {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://10747384394",
		ImageColor3 = Theme["Color Text"],
		Name = "Close"
	}), "Text")

	local MinimizeButton = InsertTheme(SetProps(CloseButton:Clone(), {
		Position = UDim2.new(1, -35, 0.5, 0),
		Image = "rbxassetid://10734896206",
		Name = "Minimize"
	}), "Text")

	SetChildren(ButtonsFolder, {CloseButton, MinimizeButton})

	-- Search --------------------------------------------------------------
	local ActiveTab
	local SearchBox

	if UseSearch then
		local SearchFrame = InsertTheme(Create("Frame", TopBar, {
			Size = UDim2.fromOffset(110, 18),
			Position = UDim2.new(1, -62, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Theme["Color Stroke"],
			Name = "Search"
		}), "Stroke")
		Make("Corner", SearchFrame, UDim.new(0, 5))

		InsertTheme(Create("ImageLabel", SearchFrame, {
			Size = UDim2.fromOffset(11, 11),
			Position = UDim2.new(0, 6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://10734943674",
			ImageColor3 = Theme["Color Dark Text"]
		}), "DarkText")

		SearchBox = InsertTheme(Create("TextBox", SearchFrame, {
			Size = UDim2.new(1, -26, 1, 0),
			Position = UDim2.fromOffset(22, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			PlaceholderText = "Search...",
			PlaceholderColor3 = Theme["Color Dark Text"],
			TextColor3 = Theme["Color Text"],
			Text = ""
		}), "Text")

		SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			if ActiveTab then
				ActiveTab:Filter(SearchBox.Text)
			end
		end)
	end

	-- Window object -------------------------------------------------------
	local Window = {Frame = MainFrame, Popup = Popup}
	local FirstTab, TabOrder = false, 0
	local ContainerList = {}

	function Window:CloseBtn()
		Window:Dialog({
			Title = "Close",
			Text = "Do you want to close the UI?",
			Options = {
				{"Confirm", function()
					Window:Destroy()
				end},
				{"Cancel"}
			}
		})
	end

	function Window:MinimizeBtn()
		if WaitClick then return end
		WaitClick = true

		if Minimized then
			MinimizeButton.Image = "rbxassetid://10734896206"
			Minimized = false
			CreateTween({MainFrame, "Size", SaveSize, 0.25, true})
			MainFrame.ClipsDescendants = false
			SizeHandle.Visible = true
			TabHandle.Visible = true
		else
			MinimizeButton.Image = "rbxassetid://10734924532"
			SaveSize = MainFrame.Size
			Minimized = true
			SizeHandle.Visible = false
			TabHandle.Visible = false
			MainFrame.ClipsDescendants = true
			CreateTween({MainFrame, "Size", UDim2.fromOffset(MainFrame.Size.X.Offset, 28), 0.25, true})
		end

		WaitClick = false
	end

	-- Shows / hides the whole window (also bound to the toggle key)
	function Window:Minimize()
		MainFrame.Visible = not MainFrame.Visible
	end

	function Window:Toggle(Bool)
		if Bool == nil then
			Bool = not MainFrame.Visible
		end
		MainFrame.Visible = Bool and true or false
	end

	function Window:SetToggleKey(Key)
		ToggleKey = Key
	end

	function Window:Destroy()
		Connection:FireConnection("WindowDestroyed")
		LibMaid:Clean()
		ScreenGui:Destroy()
	end

	function Window:Notify(...)
		return redzlib:Notify(...)
	end

	function Window:SetTheme(Name)
		redzlib:SetTheme(Name)
	end

	function Window:Set(Val1, Val2)
		if type(Val1) == "string" and type(Val2) == "string" then
			Title.Text = Val1
			Title.SubTitle.Text = Val2
		elseif type(Val1) == "string" then
			Title.Text = Val1
		end
	end
	Window.SetTitle = Window.Set

	function Window:AddMinimizeButton(MConfigs)
		MConfigs = MConfigs or {}
		if Window.MinimizeButton then
			Window.MinimizeButton.Button:Destroy()
		end

		local HasImage = type(MConfigs.Button) == "table" and MConfigs.Button.Image ~= nil

		local Button = InsertTheme(Create("ImageButton", ScreenGui, {
			Size = UDim2.fromOffset(38, 38),
			Position = UDim2.fromScale(0.12, 0.15),
			BackgroundTransparency = HasImage and 1 or 0,
			BackgroundColor3 = Theme["Color Hub 2"],
			Name = "Minimize Button"
		}), "Frame")

		if not HasImage then
			InsertTheme(Create("ImageLabel", Button, {
				Size = UDim2.fromOffset(20, 20),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = redzlib:GetIcon("menu"),
				ImageColor3 = Theme["Color Text"]
			}), "Text")
		end

		local Corner = Make("Corner", Button, UDim.new(0, 10))
		SetProps(Corner, MConfigs.Corner)

		local Stroke
		if MConfigs.Stroke or not HasImage then
			Stroke = Make("Stroke", Button)
			SetProps(Stroke, MConfigs.Stroke)
		end

		SetProps(Button, MConfigs.Button)

		local Moved, StartPos = false, nil
		TrackDrag(Button, function()
			Moved = false
			StartPos = Button.Position
		end, function(Delta)
			if Delta.Magnitude > 6 then
				Moved = true
			end
			if Moved then
				Button.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
				KeepOnScreen(Button, 15)
			end
		end)

		Button.Activated:Connect(function()
			if not Moved then
				Window:Minimize()
			end
		end)

		local Result = {Stroke = Stroke, Corner = Corner, Button = Button}
		Window.MinimizeButton = Result
		return Result
	end

	function Window:Dialog(DConfigs)
		if MainFrame:FindFirstChild("Dialog") then return end
		if Minimized then
			Window:MinimizeBtn()
		end

		local DTitle = DConfigs[1] or DConfigs.Title or "Dialog"
		local DText = DConfigs[2] or DConfigs.Text or "This is a Dialog"
		local DOptions = DConfigs[3] or DConfigs.Options or {}

		local Screen = Create("Frame", MainFrame, {
			BackgroundTransparency = 1,
			Active = true,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 30,
			Name = "Dialog"
		})
		Make("Corner", Screen)

		local Frame = Create("Frame", Screen, {
			Active = true,
			Size = UDim2.fromOffset(250 * 1.08, 150 * 1.08),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1
		}, {
			InsertTheme(Create("TextLabel", {
				Font = Enum.Font.GothamBold,
				Size = UDim2.new(1, 0, 0, 20),
				Text = DTitle,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme["Color Text"],
				TextSize = 15,
				Position = UDim2.fromOffset(15, 5),
				BackgroundTransparency = 1
			}), "Text"),
			InsertTheme(Create("TextLabel", {
				Font = Enum.Font.GothamMedium,
				Size = UDim2.new(1, -25, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = DText,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = Theme["Color Dark Text"],
				TextSize = 12,
				Position = UDim2.fromOffset(15, 28),
				BackgroundTransparency = 1,
				TextWrapped = true
			}), "DarkText")
		})
		Make("Gradient", Frame, {Rotation = 270})
		Make("Corner", Frame)
		Make("Stroke", Frame)

		local ButtonsHolder = Create("Frame", Frame, {
			Size = UDim2.fromScale(1, 0.35),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1
		}, {
			Create("UIListLayout", {
				Padding = UDim.new(0, 10),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder
			}),
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 15),
				PaddingRight = UDim.new(0, 15)
			})
		})

		CreateTween({Frame, "Size", UDim2.fromOffset(250, 150), 0.2})
		CreateTween({Frame, "BackgroundTransparency", 0, 0.15})
		CreateTween({Screen, "BackgroundTransparency", 0.45, 0.15})

		local Dialog, Buttons, Closed = {}, {}, false

		function Dialog:Close()
			if Closed then return end
			Closed = true

			CreateTween({Frame, "Size", UDim2.fromOffset(250 * 1.08, 150 * 1.08), 0.2})
			CreateTween({Screen, "BackgroundTransparency", 1, 0.15})
			CreateTween({Frame, "BackgroundTransparency", 1, 0.15})
			task.delay(0.2, function()
				Screen:Destroy()
			end)
		end

		function Dialog:Button(BConfigs)
			local Name = BConfigs[1] or BConfigs.Name or BConfigs.Title or ""
			local BCallback = BConfigs[2] or BConfigs.Callback or function() end

			local Button = Make("Button", ButtonsHolder, {
				Text = Name,
				Font = Enum.Font.GothamBold,
				TextColor3 = Theme["Color Text"],
				TextSize = 12,
				LayoutOrder = #Buttons + 1
			})
			Make("Corner", Button)
			table.insert(Buttons, Button)

			local Count = #Buttons
			for _, Btn in ipairs(Buttons) do
				Btn.Size = UDim2.new(1 / Count, -((Count - 1) * 10) / Count, 0, 32)
			end

			Button.Activated:Connect(function()
				Dialog:Close()
				task.spawn(BCallback)
			end)
		end

		for _, Option in ipairs(DOptions) do
			Dialog:Button(Option)
		end

		return Dialog
	end

	function Window:SelectTab(TabSelect)
		if type(TabSelect) == "number" then
			local Info = redzlib.Tabs[TabSelect]
			if Info then
				Info.func:Enable()
			end
		elseif type(TabSelect) == "string" then
			for _, Info in ipairs(redzlib.Tabs) do
				if Info.TabInfo.Name == TabSelect then
					Info.func:Enable()
				end
			end
		elseif type(TabSelect) == "table" then
			if type(TabSelect.Enable) == "function" then
				TabSelect:Enable()
			else
				for _, Info in ipairs(redzlib.Tabs) do
					if Info.Cont == TabSelect.Cont then
						Info.func:Enable()
					end
				end
			end
		end
	end

	-- Small caption in the tab list
	function Window:AddTabSection(Name)
		TabOrder = TabOrder + 1

		local Label = InsertTheme(Create("TextLabel", MainScroll, {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Theme["Color Dark Text"],
			Text = string.upper(tostring(Name or "")),
			LayoutOrder = TabOrder,
			Name = "TabSection"
		}), "DarkText")

		local Section = {}
		function Section:Set(New)
			Label.Text = string.upper(tostring(New))
		end
		function Section:Destroy()
			Label:Destroy()
		end
		return Section
	end

	function Window:MakeTab(paste, TConfigs)
		if type(paste) == "table" then
			TConfigs = paste
		elseif type(paste) == "string" then
			TConfigs = {paste, TConfigs}
		end
		TConfigs = TConfigs or {}

		local TName = TConfigs[1] or TConfigs.Title or TConfigs.Name or "Tab!"
		local TIcon = redzlib:GetIcon(TConfigs[2] or TConfigs.Icon or "")

		if type(TIcon) ~= "string" or not TIcon:find("rbxassetid://", 1, true) or #TIcon < 18 then
			TIcon = false
		end

		local IsFirst = not FirstTab
		TabOrder = TabOrder + 1

		local TabSelect = Make("Button", MainScroll, {
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = TabOrder,
			Name = "Tab"
		})
		Make("Corner", TabSelect)

		local LabelTitle = InsertTheme(Create("TextLabel", TabSelect, {
			Size = UDim2.new(1, TIcon and -25 or -15, 1, 0),
			Position = UDim2.fromOffset(TIcon and 25 or 15, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = TName,
			TextColor3 = Theme["Color Text"],
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = IsFirst and 0 or 0.3,
			TextTruncate = Enum.TextTruncate.AtEnd
		}), "Text")

		local LabelIcon = InsertTheme(Create("ImageLabel", TabSelect, {
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.new(0, 13, 0, 13),
			AnchorPoint = Vector2.new(0, 0.5),
			Image = TIcon or "",
			ImageColor3 = Theme["Color Text"],
			BackgroundTransparency = 1,
			ImageTransparency = IsFirst and 0 or 0.3
		}), "Text")

		local Selected = InsertTheme(Create("Frame", TabSelect, {
			Size = IsFirst and UDim2.new(0, 4, 0, 13) or UDim2.new(0, 4, 0, 4),
			Position = UDim2.new(0, 1, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme["Color Theme"],
			BackgroundTransparency = IsFirst and 0 or 1
		}), "Theme")
		Make("Corner", Selected, UDim.new(0.5, 0))

		local Container = InsertTheme(Create("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 1.5,
			BackgroundTransparency = 1,
			ScrollBarImageTransparency = 0.2,
			ScrollBarImageColor3 = Theme["Color Theme"],
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			Active = true,
			Name = ("Container %i [ %s ]"):format(#ContainerList + 1, tostring(TName))
		}, {
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10)
			}),
			Create("UIListLayout", {
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder
			})
		}), "ScrollBar")

		table.insert(ContainerList, Container)
		if IsFirst then
			Container.Parent = Containers
		end

		local Tab = {Enabled = IsFirst, Name = TName, Cont = Container, Button = TabSelect}
		local Entries = {}
		local Counter = 0

		if IsFirst then
			ActiveTab = Tab
		end
		FirstTab = true

		table.insert(redzlib.Tabs, {TabInfo = {Name = TName, Icon = TIcon}, func = Tab, Cont = Container})

		local function Register(Frame, Kind, Label)
			Counter = Counter + 1
			Frame.LayoutOrder = Counter

			local Entry = {Frame = Frame, Kind = Kind, Label = Label, Hidden = false, Filtered = false}
			function Entry:SetVisible(Bool)
				if Bool == nil then
					Bool = self.Hidden
				end
				self.Hidden = not Bool
				RefreshEntry(self)
			end

			table.insert(Entries, Entry)
			return Entry
		end

		function Tab:Filter(Query)
			Query = string.lower(tostring(Query or ""))
			local Searching = Query:match("%S") ~= nil

			for _, Entry in ipairs(Entries) do
				if Entry.Frame.Parent then
					if not Searching then
						Entry.Filtered = false
					elseif Entry.Kind == "Element" then
						local Text = string.lower(tostring(Entry.Label and Entry.Label.Title or "") .. " " .. tostring(Entry.Label and Entry.Label.Desc or ""))
						Text = Text:gsub("<[^>]+>", "")
						Entry.Filtered = not string.find(Text, Query, 1, true)
					else
						Entry.Filtered = true
					end
					RefreshEntry(Entry)
				end
			end
		end

		function Tab:Disable()
			if not Tab.Enabled then return end
			Tab.Enabled = false

			Container.Parent = nil
			Tab:Filter("")
			CreateTween({LabelTitle, "TextTransparency", 0.3, 0.35})
			CreateTween({LabelIcon, "ImageTransparency", 0.3, 0.35})
			CreateTween({Selected, "Size", UDim2.new(0, 4, 0, 4), 0.35})
			CreateTween({Selected, "BackgroundTransparency", 1, 0.35})
		end

		function Tab:Enable()
			if Tab.Enabled then return end

			for _, Info in ipairs(redzlib.Tabs) do
				if Info.func ~= Tab then
					Info.func:Disable()
				end
			end

			Tab.Enabled = true
			ActiveTab = Tab

			Container.Position = UDim2.new(0, 0, 0, 18)
			Container.Parent = Containers
			CreateTween({Container, "Position", UDim2.new(0, 0, 0, 0), 0.3})
			CreateTween({LabelTitle, "TextTransparency", 0, 0.35})
			CreateTween({LabelIcon, "ImageTransparency", 0, 0.35})
			CreateTween({Selected, "Size", UDim2.new(0, 4, 0, 13), 0.35})
			CreateTween({Selected, "BackgroundTransparency", 0, 0.35})

			if SearchBox then
				SearchBox.Text = ""
			end
		end

		function Tab:Visible(Bool)
			if Bool == nil then
				Bool = not TabSelect.Visible
			end
			TabSelect.Visible = Bool and true or false
		end

		function Tab:Destroy()
			local WasEnabled = Tab.Enabled
			TabSelect:Destroy()
			Container:Destroy()

			for Index, Info in ipairs(redzlib.Tabs) do
				if Info.func == Tab then
					table.remove(redzlib.Tabs, Index)
					break
				end
			end
			if WasEnabled then
				ActiveTab = nil
				local Next = redzlib.Tabs[1]
				if Next then
					Next.func:Enable()
				end
			end
		end

		TabSelect.Activated:Connect(function()
			Tab:Enable()
		end)

		-- Element constructors ---------------------------------------------
		local Ctx = {Container = Container, Register = Register, Popup = Popup, Tab = Tab}

		function Tab:AddSection(C) return Builders.Section(Ctx, C) end
		function Tab:AddParagraph(C) return Builders.Paragraph(Ctx, C) end
		function Tab:AddLabel(C) return Builders.Label(Ctx, C) end
		function Tab:AddDivider(C) return Builders.Divider(Ctx, C) end
		function Tab:AddButton(C) return Builders.Button(Ctx, C) end
		function Tab:AddToggle(C) return Builders.Toggle(Ctx, C) end
		function Tab:AddDropdown(C) return Builders.Dropdown(Ctx, C) end
		function Tab:AddSlider(C) return Builders.Slider(Ctx, C) end
		function Tab:AddTextBox(C) return Builders.TextBox(Ctx, C) end
		function Tab:AddKeybind(C) return Builders.Keybind(Ctx, C) end
		function Tab:AddColorPicker(C) return Builders.ColorPicker(Ctx, C) end
		function Tab:AddDiscordInvite(C) return Builders.DiscordInvite(Ctx, C) end
		function Tab:AddConfigManager(C) return Builders.ConfigManager(Ctx, C) end
		function Tab:AddThemeSelector(C) return Builders.ThemeSelector(Ctx, C) end
		Tab.AddSeparator = Tab.AddDivider
		Tab.AddTextbox = Tab.AddTextBox

		return Tab
	end

	-- Wiring ---------------------------------------------------------------
	CloseButton.Activated:Connect(function()
		Window:CloseBtn()
	end)
	MinimizeButton.Activated:Connect(function()
		Window:MinimizeBtn()
	end)

	LibMaid:Give(UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed or not ToggleKey then return end
		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == ToggleKey then
			Window:Minimize()
		end
	end))

	table.insert(ViewportCallbacks, function()
		if MainFrame.Parent then
			KeepOnScreen(MainFrame)
		end
	end)

	if Configs.MobileButton ~= false and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		Window:AddMinimizeButton({})
	end

	-- Intro animation
	MainFrame.Size = UDim2.fromOffset(SizeX * 0.92, SizeY * 0.92)
	MainFrame.Position = UDim2.new(0.5, -SizeX * 0.46, 0.5, -SizeY * 0.46)
	CreateTween({MainFrame, "Size", UDim2.fromOffset(SizeX, SizeY), 0.35})
	CreateTween({MainFrame, "Position", UDim2.new(0.5, -SizeX / 2, 0.5, -SizeY / 2), 0.35})

	return Window
end

return redzlib
