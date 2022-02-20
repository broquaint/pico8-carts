pico-8 cartridge // http://www.pico-8.com
version 35
__lua__

-- eggjam feb 22
-- by broquaint

#include utils.lua

-- ANIMATION --
function animate(f)
   animate_obj({}, f)
end

function animate_obj(obj, animation)
   obj.co = cocreate(function()
         obj.animating = true
         animation(obj)
         obj.animating = false
         if(obj.cb) obj.cb(obj)
   end)
   coresume(obj.co)
   add(animations, obj)
end

function easein(t)
   return t*t
end
function easeoutquad(t)
  t-=1
  return 1-t*t
end
function lerp(a,b,t)
   return a+(b-a)*t
end

function animate_move(obj)
   animate_obj(obj, function()
              for f = 1, obj.frames do
                 obj.pos.x = lerp(obj.from_x, obj.to_x, easein(f/obj.frames))
                 obj.pos.y = lerp(obj.from_y, obj.to_y, easein(f/obj.frames))
                 yield()
              end
   end)
end
-- /ANIMATION --

-- Mathematical constants
-- hex angle
C_hex_angle = 60
-- trig step
C_trig_step = 1 / 360

-- Global game state
-- hex length
g_hex_length = 14
g_hex_grid = {}

function pos_to_id(x, y)
   return x .. "x" .. y
end
function id_to_pos()
end

function _setup_hexagon(col, row, x1, y1)
   local angle = C_hex_angle
   local hexagon = { column = col, row = row, id = pos_to_id(col, row), lines = {} }
   for _ = 1,6 do
      local x2, y2 = x1 + (g_hex_length * cos(angle * C_trig_step)), y1 + (g_hex_length * sin(angle * C_trig_step))
      add(hexagon.lines, { x1 = x1, y1 = y1, x2 = x2, y2 = y2, column = col, row = row })
      x1, y1 = x2, y2
      angle -= C_hex_angle
   end
   return hexagon
end

function setup_grid()
   for col = 1, 5 do
      for row = 1, 5 do
         if not((col == 2 or col == 4) and row == 1) then
            local x1, y1 = 7 + ((col-1) * 21), 1 + ((row-1) * 25 + (col % 2 * 13))
            local hex = _setup_hexagon(col, row, x1, y1)
            g_hex_grid[hex.id] = hex
            -- debug("added ", col, "x", row)
         else
            -- debug("skipped ", col, "x", row)
         end
      end
   end
end

-- g_hex_paths = {{},{},{}, {},{},{}}
g_no_top_path = { ["1x1"] = true, ["3x1"] = true, ["5x1"] = true }
g_no_bot_path = { ["1x5"] = true, ["3x5"] = true, ["5x5"] = true }
-- function _setup_paths()
--    for hex in all(g_hex_grid) do
--       if hex.column != 5 then
--          -- local col = hex.column % 2 != 0 and hex.column
--          local top_row = hex.row + (hex.column % 2 == 0 and -1 or 0)
--          local next_hex = not(g_no_top_path[hex.id]) and g_hex_grid[5 * hex.column + top_row] or { lines = {} }
--          debug(hex.id, ": col = ", hex.column + 1, ", row = ", top_row)--, " -> ", next_hex)
--          local top_path = { up = next_hex.lines[1], down = next_hex.lines[5], hex = next_hex }
--          g_hex_paths[hex.column][hex.row] = top_path
--       else
--       end
--    end
-- end

-- Round to nearest 5
function round5(n)
   local rem = n % 5
   return flr((n < 2.5 and n or (n+2.5)) / 5) * 5
end


function pk(k)
   -- Using tostr as it seems PICO-8's version of Lua doesn't support
   -- floats as keys The round5 is necessary as the "intersecting"
   -- points of the hexagons don't actually intersect. By rounding to
   -- the nearest 5 the "intersecting" points naturally group together.
   return tostr(round5(k))
end

g_point_graph = {}
function add_point(x, y, v)
   local xs = pk(x)
   if not g_point_graph[xs] then
      g_point_graph[xs] = {}
   end
   g_point_graph[xs][pk(y)] = v
end

function get_point(x, y)
   local pt_col = g_point_graph[pk(x)]
   if not pt_col then
      debug("!!! Couldn't find point for ", pk(x), "x", pk(y), " [", tostr(x), "x", tostr(y), "]")
   end
   return pt_col[pk(y)]
end

function setup_point_graph()
   for id, hex in pairs(g_hex_grid) do
      local top_line = hex.lines[2]
      local tl_points = {
         right = {top_line.x2, top_line.y2},
         down  = {hex.lines[1].x1, hex.lines[1].y1},
      }
      if not g_no_top_path[hex.id] and g_hex_grid[pos_to_id(hex.column, hex.row - 1)] then
         local up_line = g_hex_grid[pos_to_id(hex.column, hex.row - 1)].lines[6]
         tl_points.up = {up_line.x2, up_line.y2}
      end

      -- LHS of top line
      add_point(top_line.x1, top_line.y1, tl_points)

      if (not g_no_top_path[hex.id]) and hex.column != 5 then
         local top_row   = hex.row + (hex.column % 2 == 0 and -1 or 0)
         local up_line   = g_hex_grid[pos_to_id(hex.column + 1, top_row)].lines[1]
         local down_line = hex.lines[3]
         -- RHS of top line
         add_point(top_line.x2, top_line.y2, {
            up = {up_line.x2, up_line.y2},
            down = {down_line.x2, down_line.y2}
         })
      end
   end
   -- debug("graph = ", g_point_graph)
end

-- Player states.
p_state_stopped = 'stopped'
p_state_moving  = 'moving'

function _init()
   animations = {}
   frame_count = 0

   setup_grid()
   setup_point_graph()

   local start_hex = g_hex_grid["1x2"]
   -- debug("starting at ", start_hex)
   player = {
      at = { x = start_hex.lines[2].x1, y = start_hex.lines[2].y1 },
      state = p_state_stopped
   }
end

function run_animations()
   for obj in all(animations) do
      if costatus(obj.co) != 'dead' then
         coresume(obj.co)
      else
         del(animations, obj)
      end
   end
end

function move_to_point(pt)
   player.state = p_state_moving
   animate_move({
         pos = player.at,
         from_x = player.at.x,
         from_y = player.at.y,
         to_x = pt[1],
         to_y = pt[2],
         frames = 30,
         cb = function() player.state = p_state_stopped end
   })
end

g_next_lines = {}
function _update()
   frame_count += 1

   run_animations()

   if player.state == p_state_stopped then
      local pt = get_point(player.at.x, player.at.y)
      g_next_lines = {}
      if pt.right then
         add(g_next_lines, { x1=player.at.x, y1=player.at.y, x2=pt.right[1], y2=pt.right[2] })
      end
      if pt.up then
         add(g_next_lines, { x1=player.at.x, y1=player.at.y, x2=pt.up[1], y2=pt.up[2] })
      end
      if pt.down then
         add(g_next_lines, { x1=player.at.x, y1=player.at.y, x2=pt.down[1], y2=pt.down[2] })
      end

      if pt.up and btnp(b_up) then
         debug("moving up to ", pt.up)
         move_to_point(pt.up)
      end
      if pt.down and btnp(b_down) then
         debug("moving down to ", pt.down)
         move_to_point(pt.down)
      end
      if pt.right and btnp(b_right) then
         debug("moving to ", pt.right)
         move_to_point(pt.right)
      end
   end
end

function _draw()
   cls(navy)
   for id, hexagon in pairs(g_hex_grid) do
      print(hexagon.id, hexagon.lines[1].x1 + 9, hexagon.lines[1].y1 - 2, white)
      for hl in all(hexagon.lines) do
         line(hl.x1, hl.y1, hl.x2, hl.y2, white + hexagon.column)
      end
   end

   for nl in all(g_next_lines) do
      line(nl.x1, nl.y1, nl.x2, nl.y2, white)
   end

   spr(1, player.at.x-4, player.at.y-4)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700006665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000066161500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000066666500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700006665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
