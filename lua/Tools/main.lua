-- Pl/Sql Developer Lua Plug-In Addon: SQL Unwrapper (LibDeflate version)
local AddMenu = ...
local plsql = plsql
local SYS, IDE, SQL = plsql.sys, plsql.ide, plsql.sql
local ShowMessage = plsql.ShowMessage

-- Load LibDeflate from file
local lua_path = plsql.RootPath() .. "\\Tools\\"
local LibDeflate_fn, err = loadfile(lua_path .. "LibDeflate.lua")
if not LibDeflate_fn then
    ShowMessage("Error loading LibDeflate: " .. tostring(err))
    return {}
end

-- Execute to get the LibDeflate object
local LibDeflate = LibDeflate_fn()

-- Character mapping table for unwrapping
local CHARMAP = {
    0x3d, 0x65, 0x85, 0xb3, 0x18, 0xdb, 0xe2, 0x87, 0xf1, 0x52, 0xab, 0x63,
    0x4b, 0xb5, 0xa0, 0x5f, 0x7d, 0x68, 0x7b, 0x9b, 0x24, 0xc2, 0x28, 0x67,
    0x8a, 0xde, 0xa4, 0x26, 0x1e, 0x03, 0xeb, 0x17, 0x6f, 0x34, 0x3e, 0x7a,
    0x3f, 0xd2, 0xa9, 0x6a, 0x0f, 0xe9, 0x35, 0x56, 0x1f, 0xb1, 0x4d, 0x10,
    0x78, 0xd9, 0x75, 0xf6, 0xbc, 0x41, 0x04, 0x81, 0x61, 0x06, 0xf9, 0xad,
    0xd6, 0xd5, 0x29, 0x7e, 0x86, 0x9e, 0x79, 0xe5, 0x05, 0xba, 0x84, 0xcc,
    0x6e, 0x27, 0x8e, 0xb0, 0x5d, 0xa8, 0xf3, 0x9f, 0xd0, 0xa2, 0x71, 0xb8,
    0x58, 0xdd, 0x2c, 0x38, 0x99, 0x4c, 0x48, 0x07, 0x55, 0xe4, 0x53, 0x8c,
    0x46, 0xb6, 0x2d, 0xa5, 0xaf, 0x32, 0x22, 0x40, 0xdc, 0x50, 0xc3, 0xa1,
    0x25, 0x8b, 0x9c, 0x16, 0x60, 0x5c, 0xcf, 0xfd, 0x0c, 0x98, 0x1c, 0xd4,
    0x37, 0x6d, 0x3c, 0x3a, 0x30, 0xe8, 0x6c, 0x31, 0x47, 0xf5, 0x33, 0xda,
    0x43, 0xc8, 0xe3, 0x5e, 0x19, 0x94, 0xec, 0xe6, 0xa3, 0x95, 0x14, 0xe0,
    0x9d, 0x64, 0xfa, 0x59, 0x15, 0xc5, 0x2f, 0xca, 0xbb, 0x0b, 0xdf, 0xf2,
    0x97, 0xbf, 0x0a, 0x76, 0xb4, 0x49, 0x44, 0x5a, 0x1d, 0xf0, 0x00, 0x96,
    0x21, 0x80, 0x7f, 0x1a, 0x82, 0x39, 0x4f, 0xc1, 0xa7, 0xd7, 0x0d, 0xd1,
    0xd8, 0xff, 0x13, 0x93, 0x70, 0xee, 0x5b, 0xef, 0xbe, 0x09, 0xb9, 0x77,
    0x72, 0xe7, 0xb2, 0x54, 0xb7, 0x2a, 0xc7, 0x73, 0x90, 0x66, 0x20, 0x0e,
    0x51, 0xed, 0xf8, 0x7c, 0x8f, 0x2e, 0xf4, 0x12, 0xc6, 0x2b, 0x83, 0xcd,
    0xac, 0xcb, 0x3b, 0xc4, 0x4e, 0xc0, 0x69, 0x36, 0x62, 0x02, 0xae, 0x88,
    0xfc, 0xaa, 0x42, 0x08, 0xa6, 0x45, 0x57, 0xd3, 0x9a, 0xbd, 0xe1, 0x23,
    0x8d, 0x92, 0x4a, 0x11, 0x89, 0x74, 0x6b, 0x91, 0xfb, 0xfe, 0xc9, 0x01,
    0xea, 0x1b, 0xf7, 0xce
}

-- Unwrappable object types
local UNWRAPPABLE_TYPES = {
    ["FUNCTION"] = true,
    ["PROCEDURE"] = true,
    ["PACKAGE"] = true,
    ["PACKAGE BODY"] = true
}

-- Module-level variables
local unwrapMenuItem

-- Base64 decoder compatible with Lua 5.1/LuaJIT
-- This version avoids using bitwise operators
local function decode_base64(data)
    local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    
    -- Remove non-base64 characters
    data = data:gsub("[^A-Za-z0-9%+%/=]", "")
    
    local result = ""
    local i = 1
    
    while i <= #data do
        -- Get 4 characters for each base64 group
        local c1 = data:sub(i, i)
        local c2 = data:sub(i+1, i+1)
        local c3 = data:sub(i+2, i+2)
        local c4 = data:sub(i+3, i+3)
        
        -- Convert to values
        local v1 = b64:find(c1) - 1
        local v2 = b64:find(c2) - 1
        
        -- Combine first two values to get first byte
        local byte1 = (v1 * 4) + math.floor(v2 / 16)
        result = result .. string.char(byte1)
        
        -- Check for padding
        if c3 ~= "=" then
            local v3 = b64:find(c3) - 1
            local byte2 = ((v2 % 16) * 16) + math.floor(v3 / 4)
            result = result .. string.char(byte2)
            
            if c4 ~= "=" then
                local v4 = b64:find(c4) - 1
                local byte3 = ((v3 % 4) * 64) + v4
                result = result .. string.char(byte3)
            end
        end
        
        i = i + 4
    end
    
    return result
end

-- Text handling functions
local function cleanup_text(text)
    return text:gsub("\n%s*\n%s*\n+", "\n\n")  -- Multiple blank lines to one
           :gsub("[ \t]+\n", "\n")             -- Trailing whitespace
           :gsub("^%s*\n", "")                 -- Leading blank lines
           :gsub("\n%s*$", "")                 -- Trailing blank lines
end

local function get_window_text()
    -- First try selected text
    local text = IDE.GetSelectedText()
    if text and text ~= "" then 
        return text 
    end
    
    -- If no selection, get all text
    text = IDE.GetText()
    if text then
        return text
    end
    return ""
end

-- Database operations
local function get_source_from_db(owner, name, obj_type)
    SQL.SetVariable("owner", owner)
    SQL.SetVariable("name", name)
    SQL.SetVariable("type", obj_type)

    local sql = [[
        select text 
        from dba_source 
        where owner = :owner 
        and name = :name 
        and type = :type 
        order by line
    ]]

    if SQL.Execute(sql) ~= 0 then
        return nil, SQL.ErrorMessage()
    end

    local text = {}
    while not SQL.Eof() do
        table.insert(text, SQL.Field(1))
        SQL.Next()
    end
    SQL.ClearVariables()
    
    return table.concat(text)
end

-- Unwrapping functionality
local function unwrap_source(text)
    -- Find and extract wrapped content
    local _, after_header = text:find("wrapped.-a000000.-[\r\n]")
    if not after_header then
        error("Cannot find wrapped code header")
    end

    -- Find the end of the header section
    local pattern = string.rep("abcd[\r\n]+", 15) .. "[%x][\r\n]+[%x]+ [%x]+[\r\n]+"
    local _, after_abcd = text:find(pattern, after_header)
    if not after_abcd then
        error("Cannot find wrapped code structure")
    end

    -- Extract and decode base64 content
    local base64_content = {}
    for line in text:sub(after_abcd + 1):gmatch("[^\r\n]+") do
        if not line:match("^[A-Za-z0-9+/=]+$") then break end
        table.insert(base64_content, line)
    end
    
    local base64_str = table.concat(base64_content)
    local decoded = decode_base64(base64_str)
    if not decoded then
        error("Invalid base64 content")
    end

    -- Map bytes and create mapped string (skip first 20 bytes)
    local mapped = {}
    for i = 21, #decoded do
        local b = decoded:byte(i)
        if not b then break end
        local mapIndex = b + 1
        if not CHARMAP[mapIndex] then 
            ShowMessage("Invalid CHARMAP index at position " .. i .. ": " .. tostring(b))
            break 
        end
        table.insert(mapped, string.char(CHARMAP[mapIndex]))
    end
    
    local mapped_str = table.concat(mapped)
    
    -- Use LibDeflate to decompress
    local result = LibDeflate:DecompressZlib(mapped_str)
    
    if not result then
        error("Decompression failed")
    end

    return result
end

-- Function to create a new window with unwrapped code
local function create_result_window(text)
    IDE.CreateWindow(plsql.WindowType.Procedure, text)
    
    IDE.SetReadOnly(window, true)
    return true
end

-- Main unwrap function
local function view_unwrapped()
    local text
    
    -- Get source from browser or window
    local obj_type, owner, name = IDE.FirstSelectedObject()
    if obj_type and UNWRAPPABLE_TYPES[obj_type] then
        local err
        text, err = get_source_from_db(owner, name, obj_type)
        if not text then
            return ShowMessage(err)
        end
    else
        text = get_window_text()
        if not text or text == "" then
            return ShowMessage("No text selected or available")
        end
    end

    -- Check if wrapped
    if not text:match("wrapped") then
        return ShowMessage("Selected code is not wrapped")
    end

    -- Unwrap and display
    local success, result = pcall(unwrap_source, text)
    if not success then
        return ShowMessage("Failed to unwrap code: " .. tostring(result))
    end

    create_result_window("CREATE OR REPLACE " .. cleanup_text(result))
end

-- Plugin interface functions
local function OnActivate()
    if unwrapMenuItem then
        for obj_type in pairs(UNWRAPPABLE_TYPES) do
            IDE.CreatePopupItem(unwrapMenuItem, "View Unwrapped", obj_type)
        end
    end
    return true
end

local function About()
    return "SQL Unwrapper (LibDeflate)"
end

-- Initialize plugin
unwrapMenuItem = AddMenu(view_unwrapped, "Lua / Utilities / View Unwrapped")

-- Return interface - must be array-like with numeric indices
return {
    OnActivate,
    function() return true end,  -- OnDeactivate
    function() return true end,  -- CanClose
    function() return true end,  -- AfterStart
    function() return true end,  -- AfterReload
    function() return true end,  -- OnBrowserChange
    function() return true end,  -- OnWindowChange
    function() return true end,  -- OnWindowCreate
    function() return true end,  -- OnWindowCreated
    function() return true end,  -- OnWindowClose
    function() return true end,  -- BeforeExecuteWindow
    function() return true end,  -- AfterExecuteWindow
    function() return true end,  -- OnConnectionChange
    function() return true end,  -- OnWindowConnectionChange
    function() return true end,  -- OnPopup
    function() return true end,  -- OnMainMenu
    function() return true end,  -- OnTemplate
    function() return true end,  -- OnFileLoaded
    function() return true end,  -- OnFileSaved
    About,                      -- About
    function() return true end,  -- CommandLine
    function() return true end,  -- RegisterExport
    function() return true end,  -- ExportInit
    function() return true end,  -- ExportFinished
    function() return true end,  -- ExportPrepare
    function() return true end   -- ExportData
}
