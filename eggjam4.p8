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

grid_sprites={
   {1,azure},
   {3,coral},
   {5,orange},
   {7,red},
--   {9,salmon},
--   {11,lime}
}
tile_size  = 12
space_size = 13

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
         grid[i][j] = {
            spr_idx = grid_sprites[randx(#grid_sprites)][1],
            gx = i,
            gy = j,
            x = i*tile_size+i,
            y = j*tile_size+j
         }
      end
   end
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
end

function finish_swap(args)
   if check_for_patterns(player.tile_held) then
      set_play_state('matched')
   else
      set_play_state('idle')
   end
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

function _draw()
   cls(black)

   -- Draw grid
   rectfill(tile_size+1, tile_size+1, 7 * tile_size + 9, 7 * tile_size + 9, silver)

   -- Draw tiles
   for i = 1,6 do
      for j = 1,6 do
         local gs = grid[i][j]
         spr(gs.spr_idx, gs.x, gs.y, 2, 2)
      end
   end

   -- Draw player cursor
   local px0 = player.x + 1
   local py0 = player.y + 1
   local px1 = (px0 + space_size)
   local py1 = (py0 + space_size)
   rect(px0-1, py0-1, px1+1, py1+1, player.held and red or yellow)
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000c11111111111000022222222222200009999999999990000bbbbbbbbbbbb0000f555555555555000b5555555555550000000000000000000000000
0007700000c77777777771000027777777777e000099999d7777790000b77777dbbbbb0000f777777777775000b7777777777750000000000000000000000000
0007700000c77777777771000027777777777e00009999d77777790000b777777dbbbb0000f777777777775000b7777777777750000000000000000000000000
0070070000c77777777771000027777777777e0000999d777777790000b7777777dbbb0000f777777777775000b7777777777750000000000000000000000000
0000000000c77777777771000027777777777e000099d7777777790000b77777777dbb0000f777777777775000b7777777777750000000000000000000000000
0000000000c77777777771000027777777777e00009d77777777790000b777777777db0000f777777777775000b7777777777750000000000000000000000000
0000000000cd777777777100002777777777de00009777777777d90000bd777777777b0000fa77777777775000ba777777777750000000000000000000000000
0000000000ccd7777777710000277777777dee0000977777777d990000bbd77777777b0000fdddd77777775000bdddd777777750000000000000000000000000
0000000000cccd77777771000027777777deee000097777777d9990000bbbd7777777b0000fddfd77777775000bddbd777777750000000000000000000000000
0000000000ccccd777777100002777777deeee00009777777d99990000bbbbd777777b0000fdfdd77777775000bdbdd777777750000000000000000000000000
0000000000cccccd7777710000277777deeeee0000977777d999990000bbbbbd77777b0000fdddda7777775000bdddda77777750000000000000000000000000
0000000000ccccccccccc10000eeeeeeeeeeee00009999999999990000bbbbbbbbbbbb0000fffffffffffff000bbbbbbbbbbbbb0000000000000000000000000
