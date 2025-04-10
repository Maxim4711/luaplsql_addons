-- Pl/Sql Developer Lua Plug-In Addon: Edit


-- Variables

local AddMenu = ...

local plsql = plsql
local SYS, IDE, SQL = plsql.sys, plsql.ide, plsql.sql

local ShowMessage = plsql.ShowMessage

local Gsub, Sub, Upper, Lower = string.gsub, string.sub, string.upper, string.lower

do
-- Session Info
	local function session_info()

		local sql = [[
		select
			to_number(substr(dbms_session.unique_session_id,9,4),'XXXX') instance,
			to_number(substr(dbms_session.unique_session_id,1,4),'XXXX') sid,
			to_number(substr(dbms_session.unique_session_id,5,4),'XXXX') serial#
        from dual
		]]

		if SQL.Execute(sql) ~= 0 then
			return nil, SQL.ErrorMessage()
		end
		
		local window_handle = IDE.GetWindowHandle()
		local client_handle = IDE.GetClientHandle()
		local child_handle = IDE.GetChildHandle()
		

		local text = "instance_id = " .. SQL.Field(1) .. " sid = " .. SQL.Field(2) .. " serial# = " .. SQL.Field(3)
		text = text .. "\n" .. " window_handle = " .. window_handle .. " client_handle = " .. client_handle .. " child_handle = " .. child_handle
		IDE.CreateWindow(plsql.WindowType.SQL, text)
		
	end
	AddMenu(session_info, "Lua / Custom / Session / Session Info")
end

-- Comment sql text
do
    local function comment_sql_text()

        local text = IDE.GetSelectedText()
        local isSelection = true
        
        if text == "" then
            text = IDE.GetText()
            isSelection = false
        end

        -- Split text into lines and comment each line
        local commented = {}
        for line in text:gmatch("([^\r\n]*)\r?\n?") do
            table.insert(commented, "-- " .. line)
        end
        
		if text:match("[\r\n]+$") then
          -- Replace the last line with an empty line (without comment prefix)
          commented[#commented] = ""
        end

        local result = table.concat(commented, "\r\n")
        
        if isSelection then
            IDE.InsertText(result)
        else
            IDE.SetText(result)
        end
    end
    AddMenu(comment_sql_text, "Lua / Edit / Selection / Comment Lines")
end

-- Uncomment sql text
do
    local function uncomment_sql_text()
        local text = IDE.GetSelectedText()
        local isSelection = true
        
        if text == "" then
            text = IDE.GetText()
            isSelection = false
        end
        
        -- Split text into lines and uncomment each line
        local uncommented = {}
        for line in text:gmatch("([^\r\n]*)\r?\n?") do
            -- Remove comment prefix if exists, otherwise keep line unchanged
            line = line:gsub("^%s*%-%-%s?", "")
            table.insert(uncommented, line)
        end
        
        local result = table.concat(uncommented, "\r\n")
        
        if isSelection then
            IDE.InsertText(result)
        else
            IDE.SetText(result)
        end
    end
    AddMenu(uncomment_sql_text, "Lua / Edit / Selection / Uncomment Lines")
end

-- Toggle comment for sql text
do
    local function toggle_comment_sql_text()
        local text = IDE.GetSelectedText()
        local isSelection = true
        
        if text == "" then
            text = IDE.GetText()
            isSelection = false
        end
        
        -- Detect if all lines are commented
        local allCommented = true
        for line in text:gmatch("[^\r\n]+") do
            if not line:match("^%s*%-%-") then
                allCommented = false
                break
            end
        end
        
        -- Toggle comments based on state
        local processed = {}
        for line in text:gmatch("([^\r\n]*)\r?\n?") do
            if allCommented then
                -- Remove comments if all lines are commented
                line = line:gsub("^%s*%-%-%s?", "")
            else
                -- Add comments if any line is uncommented
                line = "-- " .. line
            end
            table.insert(processed, line)
			
        end
		
		if processed[#processed]:gmatch("--$") then
			processed[#processed] = ""
		end
        
        local result = table.concat(processed, "\r\n")
        
        if isSelection then
            IDE.InsertText(result)
        else
            IDE.SetText(result)
        end
    end
    AddMenu(toggle_comment_sql_text, "Lua / Edit / Selection / Toggle Comment Lines")
end

-- Convert to upper case preserving quoted strings
do
    local function upper_case_text()
        local text = IDE.GetSelectedText()
        local isSelection = true
        
        if text == "" then
            text = IDE.GetText()
            isSelection = false
        end
        
        -- Function to process text while preserving quotes
        local function process_text(input)
            local result = ""
            local in_quotes = false
            local quote_char = nil
            local i = 1
            
            while i <= #input do
                local char = input:sub(i,i)
                
                -- Handle quotes
                if (char == "'" or char == '"') and 
                   (i == 1 or input:sub(i-1,i-1) ~= "\\") then
                    if not in_quotes then
                        in_quotes = true
                        quote_char = char
                    elseif char == quote_char then
                        in_quotes = false
                        quote_char = nil
                    end
                    result = result .. char
                else
                    -- Convert to upper case only if not in quotes
                    result = result .. (in_quotes and char or char:upper())
                end
                i = i + 1
            end
            
            return result
        end
        
        local result = process_text(text)
        
        if isSelection then
            IDE.InsertText(result)
        else
            IDE.SetText(result)
        end
    end
    AddMenu(upper_case_text, "Lua / Edit / Selection / Upper Case")
end

-- Convert to lower case preserving quoted strings
do
    local function lower_case_text()
        local text = IDE.GetSelectedText()
        local isSelection = true
        
        if text == "" then
            text = IDE.GetText()
            isSelection = false
        end
        
        -- Function to process text while preserving quotes
        local function process_text(input)
            local result = ""
            local in_quotes = false
            local quote_char = nil
            local i = 1
            
            while i <= #input do
                local char = input:sub(i,i)
                
                -- Handle quotes
                if (char == "'" or char == '"') and 
                   (i == 1 or input:sub(i-1,i-1) ~= "\\") then
                    if not in_quotes then
                        in_quotes = true
                        quote_char = char
                    elseif char == quote_char then
                        in_quotes = false
                        quote_char = nil
                    end
                    result = result .. char
                else
                    -- Convert to lower case only if not in quotes
                    result = result .. (in_quotes and char or char:lower())
                end
                i = i + 1
            end
            
            return result
        end
        
        local result = process_text(text)
        
        if isSelection then
            IDE.InsertText(result)
        else
            IDE.SetText(result)
        end
    end
    AddMenu(lower_case_text, "Lua / Edit / Selection / Lower Case")
end

-- Addon description
local function About()
	return "Edit Selection Functions"
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

