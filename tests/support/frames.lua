local Frames = {}
local Methods = {}
local Objects, Named, Originals = {}, {}, {}
local Installed, OriginalCreateFrame

local function Name(frame)
    return frame and (rawget(frame, "name") or ("<" .. frame.frameType .. ">")) or "nil"
end

local function Resolve(frame)
    if type(frame) == "string" then
        local found = Named[frame]
        if not found then error("unknown frame: " .. frame, 3) end
        return found
    end
    return frame
end

local Metatable = {
    __index = function(frame, key)
        if Methods[key] then return Methods[key] end
        if type(key) == "string" and key:match("^[A-Z]") then
            error("unsupported method " .. key .. " on " .. frame.frameType .. " " .. Name(frame), 2)
        end
    end,
}

function Frames.Create(frameType, name, parent, template)
    parent = Resolve(parent)
    if name and Named[name] then error("duplicate frame name: " .. name, 2) end
    local frame = setmetatable({
        frameType = frameType, name = name, template = template,
        children = {}, anchors = {}, scripts = {}, events = {},
        width = 0, height = 0, shown = true, text = "",
        frameLevel = 0, frameStrata = "MEDIUM",
    }, Metatable)
    Objects[#Objects + 1] = frame
    frame:SetParent(parent)
    if name then
        Originals[name] = { _G[name] }
        Named[name], _G[name] = frame, frame
    end
    return frame
end

function Frames.Install()
    if Installed then return end
    OriginalCreateFrame = _G.CreateFrame
    _G.CreateFrame = Frames.Create
    Installed = true
end

function Frames.Reset()
    for name, original in pairs(Originals) do _G[name] = original[1] end
    Objects, Named, Originals = {}, {}, {}
    if Installed then _G.CreateFrame = OriginalCreateFrame end
    Installed, OriginalCreateFrame = false, nil
end

function Methods:GetName() return self.name end
function Methods:GetParent() return self.parent end

function Methods:SetParent(parent)
    parent = Resolve(parent)
    local ancestor = parent
    while ancestor do
        if ancestor == self then error("cyclic parent for " .. Name(self), 2) end
        ancestor = ancestor.parent
    end
    if self.parent then
        for index, child in ipairs(self.parent.children) do
            if child == self then table.remove(self.parent.children, index); break end
        end
    end
    self.parent = parent
    if parent then parent.children[#parent.children + 1] = self end
end

function Methods:CreateFontString(name, layer, template)
    local region = Frames.Create("FontString", name, self, template)
    region.layer = layer
    return region
end

function Methods:CreateTexture(name, layer, template)
    local region = Frames.Create("Texture", name, self, template)
    region.layer = layer
    return region
end

function Methods:SetPoint(point, relativeTo, relativePoint, x, y)
    if type(relativeTo) == "number" then
        x, y, relativeTo, relativePoint = relativeTo, relativePoint, self.parent, point
    else
        relativeTo = Resolve(relativeTo) or self.parent
    end
    local anchor = { point, relativeTo, relativePoint or point, x or 0, y or 0 }
    for index, current in ipairs(self.anchors) do
        if current[1] == point then self.anchors[index] = anchor; return end
    end
    self.anchors[#self.anchors + 1] = anchor
end

function Methods:ClearAllPoints() self.anchors = {} end

function Methods:SetAllPoints(relativeTo)
    relativeTo = Resolve(relativeTo) or self.parent
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0)
end

function Methods:GetPoint(index)
    local anchor = self.anchors[index or 1]
    if anchor then return unpack(anchor, 1, 5) end
end

function Methods:GetNumPoints() return #self.anchors end
function Methods:SetSize(width, height) self.width, self.height = width, height end
function Methods:SetWidth(width) self.width = width end
function Methods:SetHeight(height) self.height = height end
function Methods:GetWidth() return self.width end
function Methods:GetHeight() return self.height end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:SetShown(shown) self.shown = not not shown end
function Methods:IsShown() return self.shown end

function Methods:IsVisible()
    return self.shown and (not self.parent or self.parent:IsVisible())
end

function Methods:SetText(text) self.text = text end
function Methods:GetText() return self.text end
function Methods:SetTexture(texture) self.texture, self.color = texture, nil end
function Methods:SetColorTexture(...) self.color, self.texture = { ... }, nil end
function Methods:SetFont(...) self.font = { ... }; return true end
function Methods:SetBackdrop(backdrop) self.backdrop = backdrop end
function Methods:SetBackdropColor(...) self.backdropColor = { ... } end
function Methods:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
function Methods:SetJustifyH(justify) self.justifyH = justify end
function Methods:SetWordWrap(wrap) self.wordWrap = wrap end
function Methods:SetAutoFocus(focus) self.autoFocus = focus end
function Methods:SetTextInsets(...) self.textInsets = { ... } end
function Methods:SetFrameLevel(level) self.frameLevel = level end
function Methods:GetFrameLevel() return self.frameLevel end
function Methods:SetFrameStrata(strata) self.frameStrata = strata end
function Methods:EnableMouse(enabled) self.mouseEnabled = not not enabled end
function Methods:SetScript(script, callback) self.scripts[script] = callback end
function Methods:GetScript(script) return self.scripts[script] end

function Methods:HookScript(script, callback)
    local original = self.scripts[script]
    self.scripts[script] = function(...)
        if original then original(...) end
        callback(...)
    end
end

function Methods:RegisterEvent(event) self.events[event] = true end
function Methods:UnregisterEvent(event) self.events[event] = nil end

function Frames.Fire(frame, script, ...)
    local callback = frame:GetScript(script)
    if callback then return callback(frame, ...) end
end

function Frames.Find(path, root)
    local current = root
    for part in path:gmatch("[^/]+") do
        if not current then
            current = Named[part]
        else
            local found
            for index, child in ipairs(current.children) do
                if child.name == part or tostring(index) == part then found = child; break end
            end
            current = found
        end
        if not current then return nil end
    end
    return current
end

local function Check(frame, field, actual, expected)
    if actual ~= expected then
        error(("%s %s: expected %s, got %s"):format(Name(frame), field, tostring(expected), tostring(actual)), 3)
    end
end

function Frames.AssertAnchor(frame, index, expected)
    local anchor = frame.anchors[index]
    if not anchor then error(Name(frame) .. " missing anchor " .. index, 2) end
    for field = 1, 5 do
        local actual, value = anchor[field], expected[field]
        if field == 2 then
            value = Resolve(value)
            if actual ~= value then
                error(Name(frame) .. " anchor " .. index .. " relativeTo: expected "
                    .. Name(value) .. " (" .. tostring(value) .. "), got "
                    .. Name(actual) .. " (" .. tostring(actual) .. ")", 2)
            end
        end
        Check(frame, "anchor " .. index .. " field " .. field, actual, value)
    end
end

function Frames.AssertSize(frame, width, height)
    Check(frame, "width", frame.width, width)
    Check(frame, "height", frame.height, height)
end

function Frames.AssertShown(frame, shown) Check(frame, "shown", frame:IsShown(), shown) end
function Frames.AssertVisible(frame, visible) Check(frame, "visible", frame:IsVisible(), visible) end
function Frames.AssertText(frame, text) Check(frame, "text", frame:GetText(), text) end

function Frames.Dump(root)
    local lines = {}
    local function Visit(frame, depth)
        local anchors = {}
        for _, anchor in ipairs(frame.anchors) do
            anchors[#anchors + 1] = ("%s->%s:%s(%s,%s)"):format(
                anchor[1], Name(anchor[2]), anchor[3], anchor[4], anchor[5])
        end
        lines[#lines + 1] = ("%s%s [%s] shown=%s anchors={%s} size=%sx%s text=%q"):format(
            string.rep("  ", depth), Name(frame), frame.frameType, tostring(frame.shown),
            table.concat(anchors, ", "), frame.width, frame.height, tostring(frame.text))
        for _, child in ipairs(frame.children) do Visit(child, depth + 1) end
    end
    if root then
        Visit(root, 0)
    else
        for _, frame in ipairs(Objects) do
            if not frame.parent then Visit(frame, 0) end
        end
    end
    return table.concat(lines, "\n")
end

Frames.Install()
return Frames
