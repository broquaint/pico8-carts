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

-- INIT --

-- Mathematical constants
-- hex angle
C_hex_angle = 60
-- trig step
C_trig_step = 1 / 360

-- Global game state
-- hex length
g_hex_length = 14
g_hex_grid = {}

-- Indexing here is redundant but makes it easier for my brain.
g_row_score_map = {
   [1] = 5,
   [2] = 4,
   [3] = 3,
   [4] = 4,
   [5] = 5,
}
g_cell_score_map = {
   [1] = {},
   [2] = { [3] = 2, [4] = 2 },
   [3] = { [2] = 2, [3] = 1, [4] = 2 },
   [4] = { [3] = 2, [4] = 2 },
   [5] = {}
}

function pos_to_id(x, y)
   return x .. "x" .. y
end

function _setup_hexagon(col, row, x1, y1)
   local angle = C_hex_angle
   local hexagon = {
      column = col,
      row = row,
      id = pos_to_id(col, row),
      lines = {},
      score = g_cell_score_map[col][row] or g_row_score_map[row]
   }
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
         if not((col == 2 or col == 4) and row == 1) and not((row == 1 or row == 5) and col == 3) then
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
function add_point(hexes, x, y, v)
   local xs = pk(x)
   if not g_point_graph[xs] then
      g_point_graph[xs] = {}
   end
   -- Keep track of which hex the point belongs to
   v.hexes = hexes
   g_point_graph[xs][pk(y)] = v
end

function get_point(x, y)
   local pt_col = g_point_graph[pk(x)]
   if not pt_col then
      debug("!!! Couldn't find point for ", pk(x), "x", pk(y), " [", tostr(x), "x", tostr(y), "]")
   end
   return pt_col[pk(y)]
end

function is_line_in_hex(hex, line)
   local lp = {
      [pk(line.x1)]=true, [pk(line.y1)]=true, [pk(line.x2)]=true, [pk(line.y2)]=true
   }
   for l in all(hex.lines) do
      -- Ordering of points on a line is different for different lines!
      if lp[pk(l.x1)] and lp[pk(l.y1)] and lp[pk(l.x2)] and lp[pk(l.y2)] then
         debug(hex.id, " did ", lp)
         return true
      end
   end
   debug(hex.id, " did not have ", lp)
   return false
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
      local top_line_hexes = {hex}
      local hex_above_id = pos_to_id(hex.column, hex.row - 1)
      if(g_hex_grid[hex_above_id]) add(top_line_hexes, g_hex_grid[hex_above_id])
      add_point(top_line_hexes, top_line.x1, top_line.y1, tl_points)

      if (not g_no_top_path[hex.id]) and hex.column != 5 then
         local top_row   = hex.row + (hex.column % 2 == 0 and -1 or 0)
         if g_hex_grid[pos_to_id(hex.column + 1, top_row)] then
            local up_hex    = g_hex_grid[pos_to_id(hex.column + 1, top_row)]
            local up_line   = up_hex.lines[1]
            local down_line = hex.lines[3]
            -- RHS of top line
            add_point({hex, up_hex}, top_line.x2, top_line.y2, {
                         up = {up_line.x2, up_line.y2},
                         down = {down_line.x2, down_line.y2}
            })
         end
      end
   end

   -- Left edge
   for n in all({1,2,3,4,5}) do
      local hex = g_hex_grid["1x"..n]
      local first_line = hex.lines[1]
      add_point({hex}, first_line.x1, first_line.y1, {
            up = { first_line.x2, first_line.y2 },
            down = { hex.lines[6].x1, hex.lines[6].y1 }
      })
   end
   -- Right edge
   for n in all({1,2,3,4,5}) do
      local hex = g_hex_grid["5x"..n]
      local third_line = hex.lines[3]
      add_point({hex}, third_line.x1, third_line.y1, {
            up = { third_line.x2, third_line.y2 },
            down = { hex.lines[4].x1, hex.lines[4].y1 }
      })
   end

   -- TODO - Top & bottom grid edges
   -- debug("graph = ", g_point_graph)
end

-- Player states.
p_state_stopped = 'stopped'
p_state_moving  = 'moving'
-- Move types
p_move_up = "up"
p_move_down = "down"
p_move_right = "right"

function _init()
   animations = {}
   frame_count = 0

   setup_grid()
   setup_point_graph()

   local start_hex = g_hex_grid["1x3"]
   player = {
      at = { x = start_hex.lines[2].x1, y = start_hex.lines[2].y1 },
      state = p_state_stopped,
      moves = {}
   }
end

-- /INIT --

-- UPDATE --

function run_animations()
   for obj in all(animations) do
      if costatus(obj.co) != 'dead' then
         coresume(obj.co)
      else
         del(animations, obj)
      end
   end
end

g_level_history = {}
function move_to_point(point, move)
   local pt = point[move]

   for hexagon in all(point.hexes) do
      local line = {
         x1 = player.at.x,
         y1 = player.at.y,
         x2 = pt[1],
         y2 = pt[2],
      }
      if is_line_in_hex(g_hex_grid[hexagon.id], line) then
         add(g_level_history, {
                line = line,
                hex = hexagon.id
         })
      end
   end
   dump("moves = ", g_level_history)
   player.state = p_state_moving
   animate_move({
         pos = player.at,
         from_x = player.at.x,
         from_y = player.at.y,
         to_x = pt[1],
         to_y = pt[2],
         frames = 15,
         cb = function() player.state = p_state_stopped end
   })
end

g_next_lines = {}
function _update()
   frame_count += 1

   run_animations()

   if btnp(b_up) then
      add(player.moves, p_move_up)
   elseif btnp(b_down) then
      add(player.moves, p_move_down)
   elseif btnp(b_right) then
      add(player.moves, p_move_right)
   end

   if player.state == p_state_stopped then
      local pt = get_point(player.at.x, player.at.y)

      if #player.moves > 0 then
         local move = player.moves[1]
         if pt[move] then
            move_to_point(pt, move)
         end
         deli(player.moves, 1)
      end

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
   end
end

function _draw()
   cls(navy)
   for id, hexagon in pairs(g_hex_grid) do
      print(hexagon.id, hexagon.lines[1].x1 + 9, hexagon.lines[1].y1 + 4, white)
      spr(1 + hexagon.score, hexagon.lines[1].x1 + 11, hexagon.lines[1].y1 - 4)
      for hl in all(hexagon.lines) do
         line(hl.x1, hl.y1, hl.x2, hl.y2, white + hexagon.column)
      end
   end

   for nl in all(g_next_lines) do
      line(nl.x1, nl.y1, nl.x2, nl.y2, silver)
   end

   local scores = {}
   for id, move in pairs(g_level_history) do
      local pl = move.line
      line(pl.x1, pl.y1, pl.x2, pl.y2, white)
      scores[move.hex] = 1 + (scores[move.hex] or 0)
   end

   local total_score = 0
   for id, score in pairs(scores) do
      local hex = g_hex_grid[id]
      if score >= hex.score then
         total_score += hex.score
         spr(17 + hex.score, hex.lines[1].x1 + 11, hex.lines[1].y1 - 4)
      end
   end

   print(dumper("score ", total_score), 36, 2, white)

   spr(1, player.at.x-4, player.at.y-4)
   --spr(17, 94, player.at.y-4)
   print()
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005555000000d00000ddd0000dddddd00000dd000dddddd0000000000000000000000000000000000000000000000000000000000000000000000000
0070070005565650000dd0000ddddd000dddddd0000ddd000dd00000000000000000000000000000000000000000000000000000000000000000000000000000
000770000556565000ddd0000dd0dd000000dd0000dddd000ddddd00000000000000000000000000000000000000000000000000000000000000000000000000
0007700005955550000dd000000ddd00000dddd00dd0dd0000000dd0000000000000000000000000000000000000000000000000000000000000000000000000
0070070005599550000dd00000ddd0000d00ddd00dddddd00dd00dd0000000000000000000000000000000000000000000000000000000000000000000000000
000000000055550000dddd000ddddd0000dddd000000dd0000dddd00000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000067dd000000a00000aaa0000aaaaaa00000aa000aaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000
000000000dd67dd0000aa0000aaaaa000aaaaaa0000aaa000aa00000000000000000000000000000000000000000000000000000000000000000000000000000
000000006666677700aaa0000aa0aa000000aa0000aaaa000aaaaa00000000000000000000000000000000000000000000000000000000000000000000000000
0000000066666777000aa000000aaa00000aaaa00aa0aa0000000aa0000000000000000000000000000000000000000000000000000000000000000000000000
000000000dd67dd0000aa00000aaa0000a00aaa00aaaaaa00aa00aa0000000000000000000000000000000000000000000000000000000000000000000000000
000000000067dd0000aaaa000aaaaa0000aaaa000000aa0000aaaa00000000000000000000000000000000000000000000000000000000000000000000000000
00000000000dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
