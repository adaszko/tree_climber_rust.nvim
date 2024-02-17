--[[

 * Use :InspectTree in a Rust buffert to show the syntax tree
 * Type 'a' in the tree buffer to reveal anonymous nodes
 * Remember about vim.inspect() for debugging
 * https://luals.github.io/wiki/annotations/

--]]

local M = {}


local ts = require('vim.treesitter')
local ts_utils = require("nvim-treesitter.ts_utils")
local parsers = require("nvim-treesitter.parsers")


---@type TSNode[][]
local buffer_selection_history = {}


---@generic T, U
---@param tbl T[]
---@param f fun(x: T): U
---@return U[]
local function map(tbl, f)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = f(v)
    end
    return t
end


M.init_selection = function()
    local buf = vim.api.nvim_get_current_buf()
    local node = ts_utils.get_node_at_cursor()
    buffer_selection_history[buf] = {{node}}
    ts_utils.update_selection(buf, node)
end


---@param nodes table<TSNode>
---@return boolean
local function all_nodes_have_the_same_parent(nodes)
    if #nodes == 0 then
        return true
    end
    local representant = nodes[1]:parent()
    for _, node in ipairs(nodes) do
        if node:parent() == nil then
            if representant ~= nil then
                return false
            end
        else
            if not node:parent():equal(representant) then
                return false
            end
        end
    end
    return true
end


---@param nodes table<TSNode>
---@return TSNode
local function get_shared_parent(nodes)
    assert(all_nodes_have_the_same_parent(nodes), "Invariant violated: Not all nodes share the same parent!")
    local parent = nodes[1]:parent()
    assert(parent ~= nil)
    return parent
end


---Computes a table of nodes to select next.  If not possible, returns unchanged input table.
---@param current table<TSNode>
---@param parent TSNode
---@param get_node_text fun(n: TSNode): string
---@param get_query_captures fun(q: string, n: TSNode): table<TSNode>
---@return table<TSNode>
local function climb_tree(current, parent, get_node_text, get_query_captures)
    -- Preconditions
    assert(#current > 0)

    local prev_sibling_text = function (node)
        local prev_sibling = node:prev_sibling()
        if not prev_sibling then
            return nil
        end
        return get_node_text(prev_sibling)
    end

    local next_sibling_text = function (node, text)
        local next_sibling = node:next_sibling()
        if not next_sibling then
            return nil
        end
        return get_node_text(next_sibling)
    end

    local parent_type = parent:type()
    --dump(string.format("parent_type: %s", parent_type))
    if parent_type == 'tuple_expression' then
	assert(parent:child_count() ~= 3, "Single element tuple_expression should not exist")

        if #current == 1 then
            -- There's just one element selected => select it and its preceding/trailing comma
            local node = current[1]
            local prev_sibling = node:prev_sibling()
            local next_sibling = node:next_sibling()
            if get_node_text(next_sibling) == ")" then
                -- Last element => select it and it's optional preceding comma
                if get_node_text(prev_sibling) == "," then
                    return {prev_sibling, node}
                else
                    return {node}
                end
            elseif get_node_text(prev_sibling) == "(" then
                -- First element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            else
                -- Middle element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            end
        elseif get_node_text(current[1]:prev_sibling()) == "(" and get_node_text(current[#current]:next_sibling()) == ")" then
            -- There's more stuff selected => select entire tuple_expression
            return {parent}
        else
            -- There's multiple tuple element children selected => select inner text of the parens
            local inner_children = get_query_captures([[(tuple_expression _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], parent)
            return inner_children
        end
    elseif parent_type == 'tuple_type' then
	assert(parent:child_count() ~= 3, "Single element tuple_type should not exist")

        if #current == 1 then
            -- There's just one element selected => select it and its preceding/trailing comma
            local node = current[1]
            local prev_sibling = node:prev_sibling()
            local next_sibling = node:next_sibling()
            if get_node_text(next_sibling) == ")" then
                -- Last element => select it and it's optional preceding comma
                if get_node_text(prev_sibling) == "," then
                    return {prev_sibling, node}
                else
                    return {node}
                end
            elseif get_node_text(prev_sibling) == "(" then
                -- First element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            else
                -- Middle element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            end
        elseif get_node_text(current[1]:prev_sibling()) == "(" and get_node_text(current[#current]:next_sibling()) == ")" then
            -- There's more stuff selected => select entire tuple_type
            return {parent}
        else
            -- There's multiple tuple element children selected => select inner text of the parens
            local inner_children = get_query_captures([[(tuple_type _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], parent)
            return inner_children
        end
    elseif parent_type == 'arguments' then
	if parent:child_count() == 3 then
	    return {parent}
	end

        if #current == 1 then
            -- There's just one element selected => select it and its preceding/trailing comma
            local node = current[1]
            local prev_sibling = node:prev_sibling()
            local next_sibling = node:next_sibling()
            if get_node_text(next_sibling) == ")" then
                -- Last element => select it and it's optional preceding comma
                if get_node_text(prev_sibling) == "," then
                    return {prev_sibling, node}
                else
                    return {node}
                end
            elseif get_node_text(prev_sibling) == "(" then
                -- First element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            else
                -- Middle element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            end
        elseif get_node_text(current[1]:prev_sibling()) == "(" and get_node_text(current[#current]:next_sibling()) == ")" then
            -- There's more stuff selected => select entire arguments
            return {parent}
        else
            -- There's multiple element children selected => select inner text of the parens
            local inner_children = get_query_captures([[(arguments _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], parent)
            return inner_children
        end
    elseif parent_type == 'type_arguments' then
        if #current == 1 then
            -- There's just one element selected => select it and its preceding/trailing comma
            local node = current[1]
            local prev_sibling = node:prev_sibling()
            local next_sibling = node:next_sibling()
            if get_node_text(next_sibling) == ">" then
                -- Last element => select it and it's optional preceding comma
                if get_node_text(prev_sibling) == "," then
                    return {prev_sibling, node}
                else
                    return {node}
                end
            elseif get_node_text(prev_sibling) == "<" then
                -- First element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            else
                -- Middle element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            end
        elseif get_node_text(current[1]:prev_sibling()) == "<" and get_node_text(current[#current]:next_sibling()) == ">" then
            -- There's more stuff selected => select entire arguments
            return {parent}
        else
            -- There's multiple element children selected => select inner text of the parens
            local inner_children = get_query_captures([[(type_arguments _ @child (#not-eq? @child "<") (#not-eq? @child ">"))]], parent)
            return inner_children
        end
    elseif parent_type == 'array_expression' then
	if parent:child_count() == 3 then
	    return {parent}
	end

	if #current == 1 then
            -- There's just one element selected => select it and its preceding/trailing comma
            local node = current[1]
            local prev_sibling = node:prev_sibling()
            local next_sibling = node:next_sibling()
            if get_node_text(next_sibling) == "]" then
                -- Last element => select it and it's optional preceding comma
                if get_node_text(prev_sibling) == "," then
                    return {prev_sibling, node}
                else
                    return {node}
                end
            elseif get_node_text(prev_sibling) == "[" then
                -- First element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            else
                -- Middle element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            end
        elseif get_node_text(current[1]:prev_sibling()) == "[" and get_node_text(current[#current]:next_sibling()) == "]" then
            -- There's more stuff selected => select entire arguments
            return {parent}
        else
            -- There's multiple element children selected => select inner text of the parens
            local inner_children = get_query_captures([[(array_expression _ @child (#not-eq? @child "[") (#not-eq? @child "]"))]], parent)
            return inner_children
        end
    elseif parent_type == 'block' then
        local leftmost_node = current[1]
        local rightmost_node = current[#current]
        if prev_sibling_text(leftmost_node) == "{" and next_sibling_text(rightmost_node) == "}" then
            -- All children of a block are selected => select the block along with brackets
            return {parent}
        else
            -- Some children of a block are selected => select all the block's children
            local inner_children = get_query_captures([[(block _ @child (#not-eq? @child "{") (#not-eq? @child "}"))]], parent)
            return inner_children
        end
    elseif parent_type == 'parameters' then
	if parent:child_count() == 3 then
	    return {parent}
	end

        if #current == 1 then
            -- There's just one element selected => select it and its preceding/trailing comma
            local node = current[1]
            local prev_sibling = node:prev_sibling()
            local next_sibling = node:next_sibling()
            if get_node_text(next_sibling) == ")" then
                -- Last element => select it and it's optional preceding comma
                if get_node_text(prev_sibling) == "," then
                    return {prev_sibling, node}
                else
                    return {node}
                end
            elseif get_node_text(prev_sibling) == "(" then
                -- First element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            else
                -- Middle element => select it and it's optional trailing comma
                if get_node_text(next_sibling) == "," then
                    return {node, next_sibling}
                else
                    return {node}
                end
            end
        elseif get_node_text(current[1]:prev_sibling()) == "(" and get_node_text(current[#current]:next_sibling()) == ")" then
            -- There's more stuff selected => select entire arguments
            return {parent}
        else
            -- There's multiple element children selected => select inner text of the parens
            local inner_children = get_query_captures([[(parameters _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], parent)
            return inner_children
        end
    else
	return {parent}
    end
end


local function select_nodes(leftmost_node, rightmost_node)
    local start_row, start_col, _, _ = ts_utils.get_vim_range { leftmost_node:range() }
    local _, _, end_row, end_col = ts_utils.get_vim_range { rightmost_node:range() }
    vim.api.nvim_win_set_cursor(0, { start_row, start_col - 1 })
    vim.cmd "normal! o"
    vim.api.nvim_win_set_cursor(0, { end_row, end_col - 1 })
end


---@param left table<TSNode>
---@param right table<TSNode>
---@return boolean
local function node_tables_equal(left, right)
    assert(type(left) == "table")
    assert(type(right) == "table")
    if #left ~= #right then
	return false
    end
    for i=1,#left do
	if not left[i]:equal(right[i]) then
	    return false
	end
    end
    return true
end


local function get_selection(leftmost_node, rightmost_node)
    local start_row, start_col, _, _ = ts_utils.get_vim_range { leftmost_node:range() }
    local _, _, end_row, end_col = ts_utils.get_vim_range { rightmost_node:range() }
    return start_row, start_col, end_row, end_col
end


--[[
 * https://www.youtube.com/watch?v=IRd2zwF527M
 * https://tree-sitter.github.io/tree-sitter/using-parsers#pattern-matching-with-queries
--]]

-- https://github.com/nvim-treesitter/nvim-treesitter/blob/05962ae14a076c5806592b1d447adb0f9707c2c1/lua/nvim-treesitter/incremental_selection.lua#L57
M.select_incremental = function()
    local buf = vim.api.nvim_get_current_buf()
    local history = buffer_selection_history[buf]
    local current = history[#history]

    local get_node_text = function (node)
	return ts.get_node_text(node, 0)
    end

    local buffer_root_node = parsers.get_parser(buf):parse()[1]:root()
    assert(buffer_root_node:parent() == nil)
    local get_query_captures = function (query_string, root)
	local result = {}
	local query = ts.query.parse("rust", query_string)
        if root == nil then
            root = buffer_root_node
        end
	for _, node, _ in query:iter_captures(root, 0) do
	    table.insert(result, node)
	end
	return result
    end

    local node = current[#current]
    while true do
        local parent = node:parent()
        if not parent then
            parent = buffer_root_node:descendant_for_range(node:range())
            if not parent or node:equal(buffer_root_node) then
                -- Entire buffer is selected
                return
            end
        end

        assert(not parent:equal(node))
        local next = climb_tree(current, parent, get_node_text, get_query_captures)
        assert(#next >= 1)

        if not node_tables_equal(next, current) then
            local next_start_row, next_start_col, next_end_row, next_end_col = get_selection(next[1], next[#next])
            local current_start_row, current_start_col, current_end_row, current_end_col = get_selection(current[1], current[#current])
            local same_selection = (next_start_row == current_start_row and next_start_col == current_start_col and next_end_row == current_end_row and next_end_col == current_end_col)
            if not same_selection then
                select_nodes(next[1], next[#next])
                table.insert(history, next)
                return
            end
        end

        node = parent
    end
end


M.select_previous = function()
    local buf = vim.api.nvim_get_current_buf()
    local history = buffer_selection_history[buf]
    if #history > 1 then
	table.remove(history, #history)
	local nodes = history[#history]
	select_nodes(nodes[1], nodes[#nodes])
    end
end


---Just a test boilerplate wrapper to DRY tests -- no app logic here
---@param input_source_code string
---@return TSNode
local function get_root_node(input_source_code)
    local parser = ts.get_string_parser(input_source_code, "rust")
    local tree = parser:parse()
    local root = tree[1]:root()
    assert(root:type() == "source_file")
    assert(root:child_count() == 1)
    root = root:child(0)
    return root
end


---@param input string
---@return TSNode, (fun(n:TSNode): string), (fun(q:string,n:TSNode):TSNode[])
local function make_test(input)
    local root_node = get_root_node(input)

    local get_node_text = function (node)
	return ts.get_node_text(node, input)
    end

    local get_query_captures = function (query_string, root)
	local result = {}
	local query = ts.query.parse("rust", query_string)
	for _, node, _ in query:iter_captures(root, input) do
	    table.insert(result, node)
	end
	return result
    end

    return root_node, get_node_text, get_query_captures
end


-- tuple_expression {{{
---@param tuple_expression TSNode
---@param get_node_text function
---@param get_query_captures function
local function test_tuple_expression_middle_element(tuple_expression, get_node_text, get_query_captures)
    local integer_literal_321 = tuple_expression:child(3)
    assert(integer_literal_321:type() == "integer_literal")
    assert(get_node_text(integer_literal_321) == "321")

    local trailing_comma = tuple_expression:child(4)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {integer_literal_321}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {integer_literal_321, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(tuple_expression _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], tuple_expression)
    do
        local current = {integer_literal_321, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire tuple_expression
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {tuple_expression}))
    end
end


local function test_tuple_expression_last_element(tuple_expression, get_node_text, get_query_captures)
    local integer_literal_444 = tuple_expression:child(5)
    assert(integer_literal_444:type() == "integer_literal")
    assert(get_node_text(integer_literal_444) == "444")

    local preceding_comma = tuple_expression:child(4)
    assert(preceding_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {integer_literal_444}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {preceding_comma, integer_literal_444}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(tuple_expression _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], tuple_expression)
    do
        local current = {preceding_comma, integer_literal_444}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire tuple_expression
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {tuple_expression}))
    end
end


local function test_tuple_expression_first_element(tuple_expression, get_node_text, get_query_captures)
    local integer_literal_123 = tuple_expression:child(1)
    assert(integer_literal_123:type() == "integer_literal")
    assert(get_node_text(integer_literal_123) == "123")

    local trailing_comma = tuple_expression:child(2)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {integer_literal_123}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {integer_literal_123, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(tuple_expression _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], tuple_expression)
    do
        local current = {integer_literal_123, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire tuple_expression
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {tuple_expression}))
    end
end

local function test_tuple_expression()
    local expression_statement, get_node_text, get_query_captures = make_test([[(123, 321, 444)]])

    --[[
(expression_statement) ; [1:1 - 15]
 (tuple_expression) ; [1:1 - 15]
  "(" ; [1:1 - 1]
  (integer_literal) ; [1:2 - 4]
  "," ; [1:5 - 5]
  (integer_literal) ; [1:7 - 9]
  "," ; [1:10 - 10]
  (integer_literal) ; [1:12 - 14]
  ")" ; [1:15 - 15]
 ";" ; [1:16 - 15]
    --]]

    assert(expression_statement:type() == "expression_statement")
    local tuple_expression = expression_statement:child(0)
    assert(tuple_expression:type() == "tuple_expression")

    test_tuple_expression_middle_element(tuple_expression, get_node_text, get_query_captures)
    test_tuple_expression_last_element(tuple_expression, get_node_text, get_query_captures)
    test_tuple_expression_first_element(tuple_expression, get_node_text, get_query_captures)
end
-- }}}


-- tuple_type {{{
---@param tuple_type TSNode
---@param get_node_text function
---@param get_query_captures function
local function test_tuple_type_middle_element(tuple_type, get_node_text, get_query_captures)
    local primitive_type_u16 = tuple_type:child(3)
    assert(primitive_type_u16:type() == "primitive_type")
    assert(get_node_text(primitive_type_u16) == "u16")

    local trailing_comma = tuple_type:child(4)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {primitive_type_u16}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {primitive_type_u16, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(tuple_type _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], tuple_type)
    do
        local current = {primitive_type_u16, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire tuple_type
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {tuple_type}))
    end
end


local function test_tuple_type_last_element(tuple_type, get_node_text, get_query_captures)
    local primitive_type_u32 = tuple_type:child(5)
    assert(primitive_type_u32:type() == "primitive_type")
    assert(get_node_text(primitive_type_u32) == "u32")

    local preceding_comma = tuple_type:child(4)
    assert(preceding_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {primitive_type_u32}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {preceding_comma, primitive_type_u32}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(tuple_type _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], tuple_type)
    do
        local current = {preceding_comma, primitive_type_u32}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire tuple_type
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {tuple_type}))
    end
end


local function test_tuple_type_first_element(tuple_type, get_node_text, get_query_captures)
    local primitive_type_u8 = tuple_type:child(1)
    assert(primitive_type_u8:type() == "primitive_type")
    assert(get_node_text(primitive_type_u8) == "u8")

    local trailing_comma = tuple_type:child(2)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {primitive_type_u8}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {primitive_type_u8, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(tuple_type _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], tuple_type)
    do
        local current = {primitive_type_u8, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire tuple_type
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {tuple_type}))
    end
end

local function test_tuple_type()
    local function_item, get_node_text, get_query_captures = make_test([[fn f() -> (u8, u16, u32) {}]])

    --[[
(function_item) ; [1:1 - 27]
 "fn" ; [1:1 - 2]
 name: (identifier) ; [1:4 - 4]
 parameters: (parameters) ; [1:5 - 6]
  "(" ; [1:5 - 5]
  ")" ; [1:6 - 6]
 "->" ; [1:8 - 9]
 return_type: (tuple_type) ; [1:11 - 24]
  "(" ; [1:11 - 11]
  (primitive_type) ; [1:12 - 13]
  "," ; [1:14 - 14]
  (primitive_type) ; [1:16 - 18]
  "," ; [1:19 - 19]
  (primitive_type) ; [1:21 - 23]
  ")" ; [1:24 - 24]
 body: (block) ; [1:26 - 27]
  "{" ; [1:26 - 26]
  "}" ; [1:27 - 27]
    --]]

    assert(function_item:type() == "function_item")
    local tuple_type = function_item:child(4)
    assert(tuple_type:type() == "tuple_type")

    test_tuple_type_middle_element(tuple_type, get_node_text, get_query_captures)
    test_tuple_type_last_element(tuple_type, get_node_text, get_query_captures)
    test_tuple_type_first_element(tuple_type, get_node_text, get_query_captures)
end
-- }}}


-- call_expression {{{
local function test_call_expression_middle_argument(call_expression, get_node_text, get_query_captures)
    local arguments = call_expression:child(1)
    assert(arguments:type() == "arguments")

    local integer_literal_321 = arguments:child(3)
    assert(integer_literal_321:type() == "integer_literal")
    assert(get_node_text(integer_literal_321) == "321")

    local trailing_comma = arguments:child(4)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {integer_literal_321}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {integer_literal_321, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(arguments _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], call_expression)
    do
        local current = {integer_literal_321, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire arguments
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {arguments}))
    end
end

local function test_call_expression_last_argument(call_expression, get_node_text, get_query_captures)
    local arguments = call_expression:child(1)
    assert(arguments:type() == "arguments")

    local integer_literal_444 = arguments:child(5)
    assert(integer_literal_444:type() == "integer_literal")
    assert(get_node_text(integer_literal_444) == "444")

    local preceding_comma = arguments:child(4)
    assert(preceding_comma:type() == ",")

    -- 1) Select element + its preceding comma
    do
        local current = {integer_literal_444}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {preceding_comma, integer_literal_444}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(arguments _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], call_expression)
    do
        local current = {preceding_comma, integer_literal_444}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select function call arguments
    do
        local current = inner_children
        local parent = get_shared_parent(current)
        local actual = climb_tree(current, parent, get_node_text, get_query_captures)
        assert(node_tables_equal(actual, {arguments}))
    end

    -- 3) Select entire call_expression
    do
        local current = {arguments}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {call_expression}))
    end
end

local function test_call_expression_first_argument(call_expression, get_node_text, get_query_captures)
    local arguments = call_expression:child(1)
    assert(arguments:type() == "arguments")

    local integer_literal_123 = arguments:child(1)
    assert(integer_literal_123:type() == "integer_literal")
    assert(get_node_text(integer_literal_123) == "123")

    local trailing_comma = arguments:child(2)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {integer_literal_123}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {integer_literal_123, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(arguments _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], call_expression)
    do
        local current = {integer_literal_123, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire call_expression
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {arguments}))
    end
end

local function test_call_expression_function(call_expression, get_node_text, get_query_captures)
    local fn = call_expression:child(0)
    assert(fn:type() == "identifier")
    assert(get_node_text(fn) == "f")

    local arguments = call_expression:child(1)
    assert(arguments:type() == "arguments")

    -- 1) Select function name + its arguments
    do
        local current = {fn}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {call_expression}))
    end
end


local function test_call_expression()
    do
	local expression_statement, get_node_text, get_query_captures = make_test([[f(123, 321, 444)]])

--[[
(expression_statement) ; [1:1 - 16]
 (call_expression) ; [1:1 - 16]
  function: (identifier) ; [1:1 - 1]
  arguments: (arguments) ; [1:2 - 16]
   "(" ; [1:2 - 2]
   (integer_literal) ; [1:3 - 5]
   "," ; [1:6 - 6]
   (integer_literal) ; [1:8 - 10]
   "," ; [1:11 - 11]
   (integer_literal) ; [1:13 - 15]
   ")" ; [1:16 - 16]
 ";" ; [1:17 - 16]
--]]

	assert(expression_statement:type() == "expression_statement")
	local call_expression = expression_statement:child(0)
	assert(call_expression:type() == "call_expression")

	test_call_expression_middle_argument(call_expression, get_node_text, get_query_captures)
	test_call_expression_last_argument(call_expression, get_node_text, get_query_captures)
	test_call_expression_first_argument(call_expression, get_node_text, get_query_captures)
	test_call_expression_function(call_expression, get_node_text, get_query_captures)
    end

    do
	local expression_statement, get_node_text, get_query_captures = make_test([[f(123);]])

--[[
(expression_statement) ; [1:1 - 7]
 (call_expression) ; [1:1 - 6]
  function: (identifier) ; [1:1 - 1]
  arguments: (arguments) ; [1:2 - 6]
   "(" ; [1:2 - 2]
   (integer_literal) ; [1:3 - 5]
   ")" ; [1:6 - 6]
 ";" ; [1:7 - 7]
--]]

	assert(expression_statement:type() == "expression_statement")
	local call_expression = expression_statement:child(0)
	assert(call_expression:type() == "call_expression")
	local arguments = call_expression:child(1)
	assert(arguments:type() == "arguments")
	local integer_literal_123 = arguments:child(1)
	assert(integer_literal_123:type() == "integer_literal")
	assert(get_node_text(integer_literal_123) == "123")
        local current = {integer_literal_123}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {arguments}))
    end
end
-- }}}


-- type_arguments {{{
local function test_type_arguments_middle_element(type_arguments, get_node_text, get_query_captures)
    local type_identifier_b = type_arguments:child(3)
    assert(type_identifier_b:type() == "type_identifier")
    assert(get_node_text(type_identifier_b) == "B")

    local trailing_comma = type_arguments:child(4)
    assert(trailing_comma:type() == ",")

    -- 1) Select element + its trailing comma
    do
        local current = {type_identifier_b}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {type_identifier_b, trailing_comma}))
    end

    -- 2) Select inner < (just like normal mode command vi<)
    local inner_children = get_query_captures([[(type_arguments _ @child (#not-eq? @child "<") (#not-eq? @child ">"))]], type_arguments)
    do
        local current = {type_identifier_b, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire type_arguments
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {type_arguments}))
    end
end

local function test_type_arguments_last_element(type_arguments, get_node_text, get_query_captures)
    local type_identifier_b = type_arguments:child(5) assert(type_identifier_b:type() == "type_identifier")
    assert(get_node_text(type_identifier_b) == "C")

    local preceding_comma = type_arguments:child(4)
    assert(preceding_comma:type() == ",")

    -- 1) Select element + its trailing comma
    do
        local current = {type_identifier_b}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {preceding_comma, type_identifier_b}))
    end

    -- 2) Select inner < (just like normal mode command vi<)
    local inner_children = get_query_captures([[(type_arguments _ @child (#not-eq? @child "<") (#not-eq? @child ">"))]], type_arguments)
    do
        local current = {preceding_comma, type_identifier_b}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire type_arguments
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {type_arguments}))
    end
end

local function test_type_arguments_first_element(type_arguments, get_node_text, get_query_captures)
    local type_identifier_b = type_arguments:child(1)
    assert(type_identifier_b:type() == "type_identifier")
    assert(get_node_text(type_identifier_b) == "A")

    local trailing_comma = type_arguments:child(2)
    assert(trailing_comma:type() == ",")

    -- 1) Select element + its trailing comma
    do
        local current = {type_identifier_b}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {type_identifier_b, trailing_comma}))
    end

    -- 2) Select inner < (just like normal mode command vi<)
    local inner_children = get_query_captures([[(type_arguments _ @child (#not-eq? @child "<") (#not-eq? @child ">"))]], type_arguments)
    do
        local current = {type_identifier_b, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire type_arguments
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {type_arguments}))
    end
end

local function test_type_arguments()
    local type_item, get_node_text, get_query_captures = make_test([[type t = HashMap<A, B, C>;]])

    --[[
(type_item) ; [1:1 - 26]
 "type" ; [1:1 - 4]
 name: (type_identifier) ; [1:6 - 6]
 "=" ; [1:8 - 8]
 type: (generic_type) ; [1:10 - 25]
  type: (type_identifier) ; [1:10 - 16]
  type_arguments: (type_arguments) ; [1:17 - 25]
   "<" ; [1:17 - 17]
   (type_identifier) ; [1:18 - 18]
   "," ; [1:19 - 19]
   (type_identifier) ; [1:21 - 21]
   "," ; [1:22 - 22]
   (type_identifier) ; [1:24 - 24]
   ">" ; [1:25 - 25]
 ";" ; [1:26 - 26]
    --]]
    assert(type_item:type() == "type_item")
    local generic_type = type_item:named_child(1)
    assert(generic_type:type() == "generic_type")
    local type_arguments = generic_type:child(1)
    assert(type_arguments:type() == "type_arguments")

    test_type_arguments_middle_element(type_arguments, get_node_text, get_query_captures)
    test_type_arguments_last_element(type_arguments, get_node_text, get_query_captures)
    test_type_arguments_first_element(type_arguments, get_node_text, get_query_captures)
end
-- }}}


-- array_expression {{{
local function test_array_expression_middle_element(array_expression, get_node_text, get_query_captures)
    local integer_literal_321 = array_expression:child(3)
    assert(integer_literal_321:type() == "integer_literal")
    assert(get_node_text(integer_literal_321) == "321")

    local trailing_comma = array_expression:child(4)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {integer_literal_321}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {integer_literal_321, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(array_expression _ @child (#not-eq? @child "[") (#not-eq? @child "]"))]], array_expression)
    do
        local current = {integer_literal_321, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire array_expression
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {array_expression}))
    end
end

local function test_array_expression_last_element(array_expression, get_node_text, get_query_captures)
    local integer_literal_444 = array_expression:child(5)
    assert(integer_literal_444:type() == "integer_literal")
    assert(get_node_text(integer_literal_444) == "444")

    local preceding_comma = array_expression:child(4)
    assert(preceding_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {integer_literal_444}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {preceding_comma, integer_literal_444}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(array_expression _ @child (#not-eq? @child "[") (#not-eq? @child "]"))]], array_expression)
    do
        local current = {preceding_comma, integer_literal_444}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire array_expression
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {array_expression}))
    end
end

local function test_array_expression_first_element(array_expression, get_node_text, get_query_captures)
    local integer_literal_123 = array_expression:child(1)
    assert(integer_literal_123:type() == "integer_literal")
    assert(get_node_text(integer_literal_123) == "123")

    local trailing_comma = array_expression:child(2)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {integer_literal_123}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {integer_literal_123, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(array_expression _ @child (#not-eq? @child "[") (#not-eq? @child "]"))]], array_expression)
    do
        local current = {integer_literal_123, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire array_expression
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {array_expression}))
    end
end

local function test_array_expression()
    do
	local expression_statement, get_node_text, get_query_captures = make_test("[123, 321, 444]")

--[[
(expression_statement) ; [1:1 - 15]
 (array_expression) ; [1:1 - 15]
  "[" ; [1:1 - 1]
  (integer_literal) ; [1:2 - 4]
  "," ; [1:5 - 5]
  (integer_literal) ; [1:7 - 9]
  "," ; [1:10 - 10]
  (integer_literal) ; [1:12 - 14]
  "]" ; [1:15 - 15]
 ";" ; [1:16 - 15]
--]]
--
	assert(expression_statement:type() == "expression_statement")
	local array_expression = expression_statement:child(0)
	assert(array_expression:type() == "array_expression")

	test_array_expression_middle_element(array_expression, get_node_text, get_query_captures)
	test_array_expression_last_element(array_expression, get_node_text, get_query_captures)
	test_array_expression_first_element(array_expression, get_node_text, get_query_captures)
    end

    do
	local expression_statement, get_node_text, get_query_captures = make_test([[[123];]])

--[[
(expression_statement) ; [1:1 - 6]
 (array_expression) ; [1:1 - 5]
  "[" ; [1:1 - 1]
  (integer_literal) ; [1:2 - 4]
  "]" ; [1:5 - 5]
 ";" ; [1:6 - 6]
--]]

	assert(expression_statement:type() == "expression_statement")
	local array_expression = expression_statement:child(0)
	assert(array_expression:type() == "array_expression")
	local integer_literal_123 = array_expression:child(1)
	assert(integer_literal_123:type() == "integer_literal")
	assert(get_node_text(integer_literal_123) == "123")
        local current = {integer_literal_123}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {array_expression}))
    end
end
-- }}}


-- block {{{
local function test_block()
    local expression_statement, get_node_text, get_query_captures = make_test([[{123; 321; 444}]])

    --[[
(expression_statement) ; [1:1 - 15]
 (block) ; [1:1 - 15]
  "{" ; [1:1 - 1]
  (expression_statement) ; [1:2 - 5]
   (integer_literal) ; [1:2 - 4]
   ";" ; [1:5 - 5]
  (expression_statement) ; [1:7 - 10]
   (integer_literal) ; [1:7 - 9]
   ";" ; [1:10 - 10]
  (integer_literal) ; [1:12 - 14]
  "}" ; [1:15 - 15]
    --]]

    assert(expression_statement:type() == "expression_statement")
    local block = expression_statement:child(0)
    assert(block:type() == "block")

    -- 1) Select inner children of a block
    do
        local expression_statement_321 = block:child(2)
        assert(expression_statement_321:type() == "expression_statement")
        assert(get_node_text(expression_statement_321) == "321;")
        local inner_children = get_query_captures([[(block _ @child (#not-eq? @child "{") (#not-eq? @child "}"))]], expression_statement)
        local current = {expression_statement_321}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 2) Select entire block with brackets
    do
        local inner_children = get_query_captures([[(block _ @child (#not-eq? @child "{") (#not-eq? @child "}"))]], expression_statement)
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {block}))
    end
end
-- }}}


-- function_item {{{
local function test_function_item_middle_argument(function_item, get_node_text, get_query_captures)
    local parameters = function_item:child(2)
    assert(parameters:type() == "parameters")

    local parameter_b = parameters:child(3)
    assert(parameter_b:type() == "parameter")
    assert(get_node_text(parameter_b) == "b: u16")

    local trailing_comma = parameters:child(4)
    assert(trailing_comma:type() == ",")

    -- 1) Select tuple element + its trailing comma
    do
        local current = {parameter_b}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {parameter_b, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(parameters _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], function_item)
    do
        local current = {parameter_b, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire arguments
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {parameters}))
    end
end

local function test_function_item_last_argument(function_item, get_node_text, get_query_captures)
    local parameters = function_item:child(2)
    assert(parameters:type() == "parameters")

    local parameter_c = parameters:child(5)
    assert(parameter_c:type() == "parameter")
    assert(get_node_text(parameter_c) == "c: u32")

    local preceding_comma = parameters:child(4)
    assert(preceding_comma:type() == ",")

    -- 1) Select element + its preceding comma
    do
        local current = {parameter_c}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {preceding_comma, parameter_c}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(parameters _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], function_item)
    do
        local current = {preceding_comma, parameter_c}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select function call arguments
    do
        local current = inner_children
        local parent = get_shared_parent(current)
        local actual = climb_tree(current, parent, get_node_text, get_query_captures)
        assert(node_tables_equal(actual, {parameters}))
    end

    -- 3) Select entire function_item
    do
        local current = {parameters}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {function_item}))
    end
end

local function test_function_item_first_argument(function_item, get_node_text, get_query_captures)
    local parameters = function_item:child(2)
    assert(parameters:type() == "parameters")

    local parameter_a = parameters:child(1)
    assert(parameter_a:type() == "parameter")
    assert(get_node_text(parameter_a) == "a: u8")

    local trailing_comma = parameters:child(2)
    assert(trailing_comma:type() == ",")

    -- 1) Select child + its trailing comma
    do
        local current = {parameter_a}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {parameter_a, trailing_comma}))
    end

    -- 2) Select inner block (just like normal mode command vib)
    local inner_children = get_query_captures([[(parameters _ @child (#not-eq? @child "(") (#not-eq? @child ")"))]], function_item)
    do
        local current = {parameter_a, trailing_comma}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, inner_children))
    end

    -- 3) Select entire function_item
    do
        local current = inner_children
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {parameters}))
    end
end


local function test_function_item()
    do
	local function_item, get_node_text, get_query_captures = make_test([[fn f(a: u8, b: u16, c: u32) {}]])
	assert(function_item:type() == "function_item")

    --[[
(function_item) ; [1:1 - 30]
 "fn" ; [1:1 - 2]
 name: (identifier) ; [1:4 - 4]
 parameters: (parameters) ; [1:5 - 27]
  "(" ; [1:5 - 5]
  (parameter) ; [1:6 - 10]
   pattern: (identifier) ; [1:6 - 6]
   ":" ; [1:7 - 7]
   type: (primitive_type) ; [1:9 - 10]
  "," ; [1:11 - 11]
  (parameter) ; [1:13 - 18]
   pattern: (identifier) ; [1:13 - 13]
   ":" ; [1:14 - 14]
   type: (primitive_type) ; [1:16 - 18]
  "," ; [1:19 - 19]
  (parameter) ; [1:21 - 26]
   pattern: (identifier) ; [1:21 - 21]
   ":" ; [1:22 - 22]
   type: (primitive_type) ; [1:24 - 26]
  ")" ; [1:27 - 27]
 body: (block) ; [1:29 - 30]
  "{" ; [1:29 - 29]
  "}" ; [1:30 - 30]
    --]]

	test_function_item_middle_argument(function_item, get_node_text, get_query_captures)
	test_function_item_last_argument(function_item, get_node_text, get_query_captures)
	test_function_item_first_argument(function_item, get_node_text, get_query_captures)
    end

    do
	local function_item, get_node_text, get_query_captures = make_test([[fn f(x: usize) {}]])
	assert(function_item:type() == "function_item")

--[[
(function_item) ; [1:1 - 17]
 "fn" ; [1:1 - 2]
 name: (identifier) ; [1:4 - 4]
 parameters: (parameters) ; [1:5 - 14]
  "(" ; [1:5 - 5]
  (parameter) ; [1:6 - 13]
   pattern: (identifier) ; [1:6 - 6]
   ":" ; [1:7 - 7]
   type: (primitive_type) ; [1:9 - 13]
  ")" ; [1:14 - 14]
 body: (block) ; [1:16 - 17]
  "{" ; [1:16 - 16]
  "}" ; [1:17 - 17]
--]]

	local parameters = function_item:child(2)
	assert(parameters:type() == "parameters")

	local parameter_x = parameters:child(1)
	assert(parameter_x:type() == "parameter")
	assert(get_node_text(parameter_x) == "x: usize")

        local current = {parameter_x}
        local parent = get_shared_parent(current)
	local actual = climb_tree(current, parent, get_node_text, get_query_captures)
	assert(node_tables_equal(actual, {parameters}))
    end
end
-- }}}

M.test = function()
    test_tuple_expression()
    test_tuple_type()
    test_call_expression()
    test_type_arguments()
    test_array_expression()
    test_block()
    test_function_item()
end

return M

-- vim:foldmethod=marker