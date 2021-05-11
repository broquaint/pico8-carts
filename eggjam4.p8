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
   {9,salmon},
   {11,lime}
}
tile_size = 16
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
         grid[i][j] = grid_sprites[randx(#grid_sprites)]
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

function animate_player_move(direction)
   local anim_args = {
      frames = 15,
      obj = player,
      cb = function() set_play_state('idle') end
   }
   if direction.x != nil then
      local from_x = player.x
      local to_x   = from_x + direction.x
      merge(anim_args, {
            from   = from_x,
            to     = to_x,
            slot   = 'x'
      })
   end
   if direction.y != nil then
      local from_y = player.y
      local to_y   = from_y + direction.y
      merge(anim_args, {
            from   = from_y,
            to     = to_y,
            slot   = 'y'
      })
   end

   animate_object_with(anim_args, animate_obj_move)
end

player = {
   x = 3*tile_size,
   y = 3*tile_size,
}
move = {
   left  = { x = -16 },
   right = { x = 16  },
   up    = { y = -16 },
   down  = { y = 16  }
}

function _update()
   if btnp(b_left) and in_play_state('idle') then
      set_play_state('switch')
      animate_player_move(move.left)
   end
   if btnp(b_right) and in_play_state('idle') then
      set_play_state('switch')
      animate_player_move(move.right)
   end
   if btnp(b_up) and in_play_state('idle') then
      set_play_state('switch')
      animate_player_move(move.up)
   end
   if btnp(b_down) and in_play_state('idle') then
      set_play_state('switch')
      animate_player_move(move.down)
   end

   frame_count += 1
   run_animations()   
end

function _draw()
   cls(navy)
   -- Draw grid
   for i = 1,7 do
      local n = i * tile_size
      line(n, tile_size, n,   112, silver)
      line(tile_size, n, 112, n,   silver)
   end
   -- Draw tiles
   for i = 1,6 do
      for j = 1,6 do
         local gs = grid[i][j]
         spr(gs[1], i*tile_size, j*tile_size, 2, 2)
      end
   end
   -- Draw player cursor
   local px0 = player.x + 1
   local py0 = player.y + 1
   local px1 = (px0 + tile_size - 2)
   local py1 = (py0 + tile_size - 2) - 1
   rect(px0, py0, px1, py1, silver)
   rect(px0-1, py0-1, px1+1, py1+1, red)
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000c111111111111000e22222222222200095555555555550008222222222222000f555555555555000b5555555555550000000000000000000000000
0007700000c777777777771000e77777777777200097777777777750008777777777772000f777777777775000b7777777777750000000000000000000000000
0007700000c777777777771000e77777777777200097777777777750008777777777772000f777777777775000b7777777777750000000000000000000000000
0070070000c777777777771000e77777777777200097777777777750008777777777772000f777777777775000b7777777777750000000000000000000000000
0000000000c777777777771000e77777777777200097777777777750008777777777772000f777777777775000b7777777777750000000000000000000000000
0000000000c777777777771000e77777777777200097777777777750008777777777772000f777777777775000b7777777777750000000000000000000000000
0000000000ca77777777771000ea777777777720009a777777777750008a77777777772000fa77777777775000ba777777777750000000000000000000000000
0000000000cdddd77777771000edddd777777720009dddd777777750008dddd77777772000fdddd77777775000bdddd777777750000000000000000000000000
0000000000cddcd77777771000edded777777720009dd9d777777750008dd8d77777772000fddfd77777775000bddbd777777750000000000000000000000000
0000000000cdcdd77777771000ededd777777720009d9dd777777750008d8dd77777772000fdfdd77777775000bdbdd777777750000000000000000000000000
0000000000cdddda7777771000edddda77777720009dddda77777750008dddda7777772000fdddda7777775000bdddda77777750000000000000000000000000
0000000000ccccccccccccc000eeeeeeeeeeeee00099999999999990008888888888888000fffffffffffff000bbbbbbbbbbbbb0000000000000000000000000
