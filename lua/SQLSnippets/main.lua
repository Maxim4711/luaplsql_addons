-- Pl/Sql Developer Lua Plug-In Addon: SQL Snippets
-- Variables
local AddMenu = ...
local plsql = plsql
local SYS, IDE = plsql.sys, plsql.ide
local ShowMessage = plsql.ShowMessage

-- IUP handling
local iup_initialized = false
local current_dlg = nil  -- Keep track of current dialog

local function cleanup_iup()
    if current_dlg then
        current_dlg:destroy()
        current_dlg = nil
    end
    if iup_initialized then
        iup.Close()
        iup_initialized = false
    end
end

-- Add OnDeactivate handler to ensure cleanup
local OnDeactivate = function()
    cleanup_iup()
end

local function init_iup()
    if iup_initialized then return true end
    
    local clibs = plsql.RootPath() .. '\\clibs\\iup\\'
    
    -- Load core IUP
    local iup_core, err = package.loadlib(clibs .. 'iup.dll', 'IupOpen')
    if not iup_core then
        ShowMessage("Failed to load IUP: " .. tostring(err))
        return false
    end
    iup_core()
    
    -- Load IUP Lua bindings
    local iup_init, err = package.loadlib(clibs .. 'iuplua51.dll', 'luaopen_iuplua')
    if not iup_init then
        ShowMessage("Failed to load IUP Lua bindings: " .. tostring(err))
        return false
    end
    iup_init()
    
    iup_initialized = true
    return true
end

-- Get window text (selected or all)
local function getWindowText()
    -- Check window type first
    local wtype = IDE.GetWindowType()
    if wtype == 0 then return nil end

    -- First try selected text
    local text = IDE.GetSelectedText()
    if text and text ~= "" then return text end
    
    -- If no selection, get all text
    text = IDE.GetText()
    return text
end

-- Helper function to normalize line endings
local function normalize_text(text)
    if not text then return "" end
    -- Convert to single \n line endings and trim spaces
    text = text:gsub('\r\n', '\n')
    text = text:gsub('\r', '\n')
    -- Remove trailing spaces from lines
    text = text:gsub(' *\n', '\n')
    -- Trim start/end
    text = text:match('^%s*(.-)%s*$')
    return text
end

-- Get snippets file path
local function get_snippets_file()
    return plsql.RootPath() .. '\\SQLSnippets\\snippets.sql'
end

-- Helper function to read all snippets
local function readSnippets()
    local snippets = {}
    local file = io.open(get_snippets_file(), "r")
    if not file then return snippets end
    
    local currentName = nil
    local currentSQL = {}
    
    for line in file:lines() do
        local snippetName = line:match("^--@@ (.+) @@--(.+)$")
        if snippetName then
            if currentName and #currentSQL > 0 then
                snippets[currentName] = table.concat(currentSQL, '\n')
            end
            currentName = snippetName
            currentSQL = {}
        elseif currentName then
            table.insert(currentSQL, line)
        end
    end
    
    if currentName and #currentSQL > 0 then
        snippets[currentName] = table.concat(currentSQL, '\n')
    end
    
    file:close()
    return snippets
end

local function saveSnippet(name, sql)
    -- Create directory if needed
    local dir = plsql.RootPath() .. '\\SQLSnippets'
    
    -- Check if directory exists using sys.stat
    local exists = sys.stat(dir)
    if not exists then
        -- Create directory using sys.mkdir
        local ok = sys.mkdir(dir)
        if not ok then
            ShowMessage("Cannot create snippets directory")
            return false
        end
    end
    
    -- Normalize SQL text
    sql = normalize_text(sql)
    if sql == "" then return false end
    
    -- Read existing snippets
    local snippets = readSnippets()
    snippets[name] = sql
    
    -- Write all snippets
    local file = io.open(get_snippets_file(), "w")
    if not file then
        ShowMessage("Cannot open snippets file for writing")
        return false
    end
    
    for sname, ssql in pairs(snippets) do
        file:write("--@@ " .. sname .. " @@--\n")
        file:write(ssql .. "\n\n")
    end
    
    file:close()
    return true
end

do
    local function AddSnippet()
        -- Get window text
        local sql = getWindowText()
        if not sql then
            ShowMessage("No active window")
            return
        end
        if sql == "" then
            ShowMessage("No SQL text available")
            return
        end
        
        -- Initialize IUP
        if not init_iup() then return end
        
        -- Create dialog
        local dlg
        local nameInput = iup.text{
            value="", 
            expand="YES"
        }
        
        local function okCallback()
            local name = nameInput.value
            if name and name ~= "" then
                if saveSnippet(name, sql) then
                    ShowMessage("Snippet saved successfully")
                end
                dlg:hide()
            else
                ShowMessage("Please enter a name for the snippet")
            end
        end

        -- Handle keyboard events for the input field
        function nameInput:k_any(key)
            if key == iup.K_CR then  -- Enter key
                okCallback()
                return iup.IGNORE
            elseif key == iup.K_ESC then  -- Escape key
                dlg:hide()
                return iup.IGNORE
            end
            return iup.CONTINUE
        end
        
        dlg = iup.dialog{
            iup.vbox{
                iup.label{title="Enter snippet name:"},
                nameInput,
                iup.hbox{
                    iup.button{title="OK", action=okCallback},
                    iup.button{title="Cancel", action=function() dlg:hide() end},
                    margin="10x10",
                    gap="5"
                },
                margin="10x10",
                gap="5"
            },
            title="Add SQL Snippet",
            size="200x80"
        }
        
        dlg:popup(iup.CENTER, iup.CENTER)
        dlg:destroy()
    end
    AddMenu(AddSnippet, "Lua / SQL Snippets / Add Snippet")
end

-- Recall Snippet
do
    local function RecallSnippet()
        -- Initialize IUP
        if not init_iup() then return end
        
        -- Read snippets
        local snippets = readSnippets()
        
        -- Get sorted names
        local names = {}
        for name, _ in pairs(snippets) do
            table.insert(names, name)
        end
        table.sort(names)
        
        if #names == 0 then
            ShowMessage("No snippets available")
            return
        end

        -- Create dialog
        local dlg
        local list = iup.list{
            expand="YES",
            visiblelines="10",
            visiblecolumns="20",
            dropdown="NO",
            multiple="NO"
        }
        
        local preview = iup.text{
            multiline="YES",
            expand="YES",
            readonly="YES",
            visiblelines="15",
            visiblecolumns="50",
            value=""
        }
        
        -- Populate list
        for i, name in ipairs(names) do
            list[i] = name
        end
        -- Select first item
        list.value = "1"
        preview.value = snippets[names[1]]
        
        local function insertSnippet()
            local idx = tonumber(list.value)
            if not idx then
                ShowMessage("Please select a snippet")
                return
            end
            
            local name = names[idx]
            if not name then
                ShowMessage("Invalid selection")
                return
            end
            
            local sql = snippets[name]
            if not sql then
                ShowMessage("Failed to get snippet content")
                return
            end
            if IDE.GetWindowType() > 0 then
		        IDE.InsertText(sql)
                dlg:hide()
            else
                ShowMessage("No active window to insert SQL")
            end
        end

        -- Handle selection changes
        function list:action(text, pos, state)
            if state == 1 then  -- Selection change
                local idx = tonumber(list.value)
                if idx and names[idx] then
                    local name = names[idx]
                    preview.value = snippets[name] or ""
                end
            end
        end

        -- Handle double-click
        function list:dblclick_cb(item, text)
            insertSnippet()
            return iup.DEFAULT
        end

        -- Handle keyboard events
        function list:k_any(key)
            if key == iup.K_CR or key == iup.K_SP then  -- Enter or Space
                insertSnippet()
                return iup.IGNORE  -- Prevent default handling
            elseif key == iup.K_ESC then  -- Escape
                dlg:hide()
                return iup.IGNORE
            end
            return iup.CONTINUE  -- Allow default handling for other keys
        end
        
        dlg = iup.dialog{
            iup.vbox{
                iup.hbox{
                    iup.vbox{
                        iup.label{title="Available Snippets:"},
                        list,
                    },
                    iup.vbox{
                        iup.label{title="Preview:"},
                        preview,
                    },
                    margin="10x10",
                    gap="10"
                },
                iup.hbox{
                    iup.button{title="Insert", action=insertSnippet},
                    iup.button{title="Close", action=function() dlg:hide() end},
                    margin="10x10",
                    gap="10"
                },
                margin="10x10"
            },
            title="Recall SQL Snippet",
            size="600x400",
            resize="YES",
            maxbox="YES"
        }
        
        dlg:show()
        iup.MainLoop()
        dlg:destroy()
    end
    
    AddMenu(RecallSnippet, "Lua / SQL Snippets / Recall Snippet")
end

-- Addon description
local function About()
    return "SQL Snippets Manager"
end

return {
    OnActivate,
    OnDeactivate,
    CanClose,
    AfterStart,
    AfterReload,
    OnBrowserChange,
    OnWindowChange,
    OnWindowCreate,
    OnWindowCreated,
    OnWindowClose,
    BeforeExecuteWindow,
    AfterExecuteWindow,
    OnConnectionChange,
    OnWindowConnectionChange,
    OnPopup,
    OnMainMenu,
    OnTemplate,
    OnFileLoaded,
    OnFileSaved,
    About,
    CommandLine,
    RegisterExport,
    ExportInit,
    ExportFinished,
    ExportPrepare,
    ExportData
}