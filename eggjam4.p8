pico-8 cartridge // http://www.pico-8.com
version 32
__lua__

-- tbc
-- by broquaint

#include utils.lua
#include animation.lua

game_state_menu       = 'menu'
game_state_gaming     = 'gaming'
game_state_splaining  = 'exposition'
game_state_level_done = 'lvldone'
game_state_level_fail = 'lvlfail'
game_state_complete   = 'complete'

play_state_idle = 'idle'
play_state_switch = 'switch'

-- br = 'bottom right',
-- bl = 'bottom left',
-- tr = 'top right',
-- tl = 'top left',

-- tl      tr      bl      br
-- oo xx # xx oo # xx xx # xx xx
-- oo xx # xx oo # xx xx # xx xx
--
-- xx xx # xx xx # oo xx # xx oo
-- xx xx # xx xx # oo xx # xx oo

grid_tiles={
   {idx=1,  colour={azure=1},   matches={bl=17}},
   {idx=3,  colour={coral=1},   matches={br=20}},
   {idx=5,  colour={lime=1},    matches={tl=5, br=22, cl=21,cr=6}},
   {idx=7,  colour={orange=1},  matches={tr=8, bl=23, cl=7,cr=24}},
   {idx=9,  colour={navy=1},    matches={tl=9}},
   {idx=11, colour={magenta=1}, matches={tr=12}},
--   {9,salmon},
--   {11,lime}
}
tile_size  = 12
space_size = 13

tile_id = 1
function make_tile(gx, gy, x, y)
   local tile = grid_tiles[randx(#grid_tiles)]
   x = x and x or gx*tile_size+gx
   y = y and y or gy*tile_size+gy
   local tid = tile_id
   tile_id += 1
   return {
      spr_idx = tile.idx,
      matches = tile.matches,
      colour  = tile.colour,
      gx = gx,
      gy = gy,
      x = x,
      y = y,
      id = tid
   }
end

function _init()
   anims={}
   frame_count = 0
   last_transition = 0
   current_game_state = game_state_gaming
   current_play_state = play_state_idle
   grid={}
   for i = 1,6 do
      grid[i] = {}
      for j = 1,6 do
         local tile = grid_tiles[randx(#grid_tiles)]
         grid[i][j] = make_tile(i, j)
      end
   end
end

function gt(gx, gy)
   local row = grid[gx]
   if(row == nil) return nil
   return row[gy]
end

function set_game_state(s)
   last_transition = frame_count
   current_game_state = s
end

function set_play_state(s)
   last_transition = frame_count
   current_play_state = s
end

function in_play_state(...)
   for v in all({...}) do
      if v == current_play_state then
         return true
      end
   end
   return false
end

function animate_obj_move(a)
   local fc, from, to, obj, slot = a.frames, a.from, a.to, a.obj, a.slot
   for f = 1, fc do
      obj[slot] = lerp(from, to, easeoutquad(f/fc))
      yield()
   end    
end

function swap_grid_tiles(a, b)
   local ax, ay = a.gx, a.gy
   local bx, by = b.gx, b.gy

   grid[ax][ay] = b
   grid[bx][by] = a

   a.gx = bx
   a.gy = by
   b.gx = ax
   b.gy = ay
end

function animate_y_move(args)
   animate_object_with(merge({slot = 'y'}, args), animate_obj_move)
end

swap_frame_count = 10
function animate_tile_swap(ta, tb, slot)
   local to = tb[slot]
   animate_object_with({
         obj  = tb,
         from = tb[slot],
         to   = ta[slot],
         slot = slot,
         frames = swap_frame_count,
   }, animate_obj_move)
   animate_object_with({
         obj  = ta,
         from = ta[slot],
         to   = to,
         slot = slot,
         frames = swap_frame_count,
         cb = function()
            swap_grid_tiles(ta, tb)
         end
   }, animate_obj_move)
end

function animate_player_move(direction)
   local anim_args = {
      frames = swap_frame_count,
      obj = player,
      cb = finish_swap
   }

   if direction.x != nil then
      local from_x = player.x
      local to_x   = from_x + direction.x
      merge(anim_args, {
            from   = from_x,
            to     = to_x,
            slot   = 'x'
      })

      player.gx += sgn(direction.x) * 1

      if player.held then
         local other_tile = grid[player.gx][player.gy]
         animate_tile_swap(player.tile_held, other_tile, 'x')
      end
   end

   if direction.y != nil then
      local from_y = player.y
      local to_y   = from_y + direction.y
      merge(anim_args, {
            from   = from_y,
            to     = to_y,
            slot   = 'y'
      })

      player.gy += sgn(direction.y) * 1

      if player.held then
         local other_tile = grid[player.gx][player.gy]
         animate_tile_swap(player.tile_held, other_tile, 'y')
      end
   end

   animate_object_with(anim_args, animate_obj_move)
end

function check_for_patterns(tile)
   function diamond_match(a)
      if(not a) return false

      -- xx xx
      -- xo @x
      -- xo ox
      -- xx xx
      if a.matches.bl then
         local b = gt(a.gx - 1, a.gy)
         local c = gt(a.gx - 1, a.gy + 1)
         local d = gt(a.gx,     a.gy + 1)

         if (b and c and d) and b.matches.br and c.matches.tr and d.matches.tl then
            return {bl=a,br=b,tr=c,tl=d}
         end
      end

      -- xx xx
      -- x@ ox
      -- xo ox
      -- xx xx
      if a.matches.br then
         local b = gt(a.gx + 1, a.gy)
         local c = gt(a.gx,     a.gy + 1)
         local d = gt(a.gx + 1, a.gy + 1)

         if (b and c and d) and b.matches.bl and c.matches.tr and d.matches.tl then
            return {br=a,bl=b,tr=c,tl=d}
         end
      end

      -- xx xx
      -- xo ox
      -- x@ ox
      -- xx xx
      if a.matches.tr then
         local b = gt(a.gx,     a.gy - 1)
         local c = gt(a.gx + 1, a.gy - 1)
         local d = gt(a.gx + 1, a.gy)

         if (b and c and d) and b.matches.br and c.matches.bl and d.matches.tl then
            return {tr=a,br=b,bl=c,tl=d}
         end
      end
      
      -- xx xx
      -- xo ox
      -- xo @x
      -- xx xx
      if a.matches.tl then
         local b = gt(a.gx - 1, a.gy - 1)
         local c = gt(a.gx,     a.gy - 1)
         local d = gt(a.gx - 1, a.gy)

         if (b and c and d) and b.matches.br and c.matches.bl and d.matches.tr then
            return {tl=a,br=b,bl=c,tr=d}
         end
      end

      return false
   end

   function cross_match(a)
      if(not a) return false

      -- xx xx
      -- xo @x
      -- xo ox
      -- xx xx
      if a.colour.lime then
         local b = gt(a.gx - 1, a.gy)
         local c = gt(a.gx - 1, a.gy + 1)
         local d = gt(a.gx,     a.gy + 1)

         if (b and c and d) and b.colour.orange and c.colour.lime and d.colour.orange then
            return {bl=a,br=b,tr=c,tl=d}
         end
      end

      -- xx xx
      -- x@ ox
      -- xo ox
      -- xx xx
      if a.colour.orange then
         local b = gt(a.gx + 1, a.gy)
         local c = gt(a.gx,     a.gy + 1)
         local d = gt(a.gx + 1, a.gy + 1)

         if (b and c and d) and b.colour.lime and c.colour.lime and d.colour.orange then
            return {br=a,bl=b,tr=c,tl=d}
         end
      end

      -- xx xx
      -- xo ox
      -- x@ ox
      -- xx xx
      if a.colour.lime then
         local b = gt(a.gx,     a.gy - 1)
         local c = gt(a.gx + 1, a.gy - 1)
         local d = gt(a.gx + 1, a.gy)

         if (b and c and d) and b.colour.orange and c.colour.lime and d.colour.orange then
            return {tr=a,br=b,bl=c,tl=d}
         end
      end
      
      -- xx xx
      -- xo ox
      -- xo @x
      -- xx xx
      if a.colour.orange then
         local b = gt(a.gx - 1, a.gy - 1)
         local c = gt(a.gx,     a.gy - 1)
         local d = gt(a.gx - 1, a.gy)

         if (b and c and d) and b.colour.orange and c.colour.lime and d.colour.lime then
            return {tl=a,br=b,bl=c,tr=d}
         end
      end

      return false
   end

   function window_match(a)
      if(not a) return false

      -- @x xo
      -- xx xx
      -- xx xx
      -- ox xo
      if a.matches.tl then
         local b = gt(a.gx + 1, a.gy)
         local c = gt(a.gx,     a.gy + 1)
         local d = gt(a.gx + 1, a.gy + 1)

         if (b and c and d) and b.matches.tr and c.matches.bl and d.matches.br then
            return {bl=c,br=d,tr=b,tl=a}
         end
      end

      -- ox x@
      -- xx xx
      -- xx xx
      -- ox xo
      if a.matches.tr then
         local b = gt(a.gx - 1, a.gy)
         local c = gt(a.gx - 1, a.gy + 1)
         local d = gt(a.gx,     a.gy + 1)

         if (b and c and d) and b.matches.tl and c.matches.bl and d.matches.br then
            return {bl=c,br=d,tr=a,tl=b}
         end
      end

      -- ox xo
      -- xx xx
      -- xx xx
      -- @x xo
      if a.matches.bl then
         local b = gt(a.gx,     a.gy - 1)
         local c = gt(a.gx + 1, a.gy - 1)
         local d = gt(a.gx + 1, a.gy)

         if (b and c and d) and b.matches.tl and c.matches.tr and d.matches.br then
            return {bl=a,br=d,tr=c,tl=b}
         end
      end

      -- ox xo
      -- xx xx
      -- xx xx
      -- ox x@
      if a.matches.br then
         local b = gt(a.gx - 1, a.gy - 1)
         local c = gt(a.gx,     a.gy - 1)
         local d = gt(a.gx - 1, a.gy)

         if (b and c and d) and b.matches.tl and c.matches.tr and d.matches.bl then
            return {bl=d,br=a,tr=c,tl=b}
         end
      end

      return false
   end

   local m = diamond_match(tile)
   if m then
      return { type = 'diamond', matched = m }
   end
   local m = cross_match(tile)
   if m then
      return { type = 'cross', matched = m }
   end
   local m = window_match(tile)
   if m then
      return { type = 'window', matched = m }
   end
   return false
end

function animate_match(matched)
   for m, t in pairs(matched) do t.matched = m end
   wait(10)
   for _,t in pairs(matched) do t.matched = nil end
   wait(7)
   for m, t in pairs(matched) do t.matched = m end
   wait(13)
   for _,t in pairs(matched) do t.matched = nil end
   wait(9)
   for m, t in pairs(matched) do t.matched = m end
   wait(15)
   for _,t in pairs(matched) do t.matched = nil end


   local br, bl = matched.br, matched.bl

   local moved = {}
   -- Calculate and create the tiles to move.
   for i = 1,br.gy + 1 do
      if i < 3 then
         -- This doesn't look quite right ... but that's fine.
         add(moved, {
                make_tile(br.gx, i, br.x, -((i+1) * tile_size + i)),
                gt(br.gx, i)
         })
         add(moved, {
                make_tile(bl.gx, i, bl.x, -((i+1) * tile_size + i)),
                gt(bl.gx, i)
         })
      else
         add(moved, {gt(br.gx, i-2), gt(br.gx, i)})
         add(moved, {gt(bl.gx, i-2), gt(bl.gx, i)})
      end
   end

   -- Add the new tiles to the grid and trigger move animation.
   for t in all(moved) do
      local new, old = t[1], t[2]
      grid[old.gx][old.gy] = new
      animate_y_move({
            obj  = new,
            from = new.y,
            to   = old.y,
            frames = 30,
            cb = function() new.gx = old.gx new.gy = old.gy end
      })
   end

   -- Lazy hack to wait for animations to finish.
   wait(30)

   player.held = false
   -- TODO add matches to a table somewhere ...
   set_play_state('idle')
end

tally = {
   diamond = 0,
   window = 0,
   cross = 0,
}

function finish_swap(args)
   local state = 'idle'
   if player.tile_held then
      local match = check_for_patterns(player.tile_held)
      if match then
         tally[match.type] += 1
         animate(function() animate_match(match.matched) end)
         state = 'matched'
      end
   end
   set_play_state(state)
end

player = {
   x = 3*space_size,
   y = 3*space_size,
   gx = 3,
   gy = 3,
   held = false
}
move = {
   left  = { x = -space_size },
   right = { x = space_size  },
   up    = { y = -space_size },
   down  = { y = space_size  }
}

function _update()
   local can_move = in_play_state('idle')
   if btnp(b_left) and can_move then
      set_play_state('switch')
      animate_player_move(move.left)
   end
   if btnp(b_right) and can_move then
      set_play_state('switch')
      animate_player_move(move.right)
   end
   if btnp(b_up) and can_move then
      set_play_state('switch')
      animate_player_move(move.up)
   end
   if btnp(b_down) and can_move then
      set_play_state('switch')
      animate_player_move(move.down)
   end
   if btnp(b_x) and can_move then
      player.held = not player.held
      player.tile_held = player.held and grid[player.gx][player.gy] or nil
   end

   frame_count += 1
   run_animations()   
end

-- diamond match offsets
dmo = {
   br = { x = 8, y = 8 },
   bl = { x = 0, y = 8 },
   tr = { x = 8, y = 0 },
   tl = { x = 0, y = 0 },
}

function _draw()
   cls(navy)

   -- Draw grid
   rectfill(tile_size+1, tile_size+1, 7 * tile_size + 9, 7 * tile_size + 9, silver)

   -- Draw tiles
   for i = 1,6 do
      for j = 1,6 do
         local gs = grid[i][j]
         if gs then
            if gs.matched then
               rectfill(gs.x+2, gs.y+2, gs.x+space_size, gs.y+space_size, white)
               local xo, yo = dmo[gs.matched].x, dmo[gs.matched].y
               spr(gs.matches[gs.matched], gs.x + xo, gs.y + yo)
            else
               spr(gs.spr_idx, gs.x, gs.y, 2, 2)
            end
         end
      end
   end

   if not in_play_state('matched') then
      local px0 = player.x + 1
      local py0 = player.y + 1
      local px1 = (px0 + space_size)
      local py1 = (py0 + space_size)
      rect(px0-1, py0-1, px1+1, py1+1, player.held and red or yellow)
   end

   -- draw ui
   print(tally.diamond, 18, 100, white)
   spr(33, 12, 108, 2, 2)
   print(tally.window,  38, 100, white)
   spr(35, 32, 108, 2, 2)
   print(tally.cross,  58, 100, white)
   spr(37, 52, 108, 2, 2)
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000c1111111111100002222222222220000bbbbbbbbb33300004449999999990000111111111111000022222222222200000000000000000000000000
0007700000c77777777771000027777777777e0000bbbbb37777730000477777499999000011111c77777c0000e77777e2222200000000000000000000000000
0007700000c77777777771000027777777777e0000bbbb37777773000047777774999900001111c777777c0000e777777e222200000000000000000000000000
0070070000c77777777771000027777777777e0000bbb37777777b00009777777749990000111c7777777c0000e7777777e22200000000000000000000000000
0000000000c77777777771000027777777777e0000bb377777777b0000977777777499000011c77777777c0000e77777777e2200000000000000000000000000
0000000000c77777777771000027777777777e0000b3777777777b000097777777774900001c777777777c0000e777777777e200000000000000000000000000
0000000000c17777777771000027777777772e0000b7777777773b0000947777777779000017777777777c0000e7777777777200000000000000000000000000
0000000000cc177777777100002777777772ee0000b777777773bb0000994777777779000017777777777c0000e7777777777200000000000000000000000000
0000000000ccc1777777710000277777772eee0000b77777773bbb0000999477777779000017777777777c0000e7777777777200000000000000000000000000
0000000000cccc17777771000027777772eeee000037777773bbbb0000999947777774000017777777777c0000e7777777777200000000000000000000000000
0000000000ccccc177777100002777772eeeee00003777773bbbbb0000999994777774000017777777777c0000e7777777777200000000000000000000000000
0000000000ccccccccccc10000eeeeeeeeeeee0000333bbbbbbbbb000099999999944400001ccccccccccc0000eeeeeeeeeee200000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000002ec1000000001111112222220000777779b7777700000000000000000000000000000000000000000000000000000000000000000000000000
00000000000002eecc1000000011111ce222220000777779b7777700000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002eeeccc10000001111c77e22220000777779b7777700000000000000000000000000000000000000000000000000000000000000000000000000
000000000002eeeecccc100000111c7777e222000077777437777700000000000000000000000000000000000000000000000000000000000000000000000000
00000000002eeeeeccccc1000011c777777e22000077777437777700000000000000000000000000000000000000000000000000000000000000000000000000
0000000000eeeeeecccccc00001c77777777e20000999444333bbb00000000000000000000000000000000000000000000000000000000000000000000000000
0000000000999999bbbbbb0000c1777777772e0000bbb33344499900000000000000000000000000000000000000000000000000000000000000000000000000
0000000000499999bbbbb30000cc17777772ee000077777347777700000000000000000000000000000000000000000000000000000000000000000000000000
0000000000049999bbbb300000ccc177772eee000077777347777700000000000000000000000000000000000000000000000000000000000000000000000000
0000000000004999bbb3000000cccc1772eeee000077777b97777700000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000499bb30000000ccccc12eeeee000077777b97777700000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000049b300000000cccccceeeeee000077777b97777700000000000000000000000000000000000000000000000000000000000000000000000000
