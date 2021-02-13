pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- find the gap
-- by broquaint

-- constants
drop_normal = 1
drop_slow   = 2
drop_fast   = 4

sfx_drop_tbl = {
   [drop_normal] = 1,
   [drop_slow]   = 3,
   [drop_fast]   = 2
}

gapspr={2,5,6}

state_level_end = 'end of level'
state_running   = 'running'
state_no_void   = 'no void'

function reset_game_vars()
   level = 1
end

function reset_level_vars()
   x = 0
   y = 8
   dx = 2
   dy = 0
   jumping = false
   falling = false
   moving  = false
   facing = 4

   floor = 1
   floor_unlocked = true
   key_at = {}
   time_limit = 32 - min(level, 15)

   begin = t()
   gamestate = state_running
   lvldone = nil
   in_void = false

   set_gaps()
end

function set_gaps()
   gapset={}

   local default_gaps={
      {8,16}, {16,24}, {24,32}, {32,40}, {40,48}, {48,56}, {56,64}, {64,72},
      {72,80}, {80,88}, {88,96}, {96,104}, {104,112}
   }
   local gaps = copy_table(default_gaps)
   for iy=1,7 do
      local gapcount = randn(3)
      gapset[iy]={}
      for idx=1,gapcount do
         -- Remove gaps so they aren't repeated across floors.
         local gap = deli(gaps, randn(#gaps))
         add(gap, gapspr[randn(#gapspr)])
         gapset[iy][idx] = gap

         if(#gaps == 0) then
            gaps = copy_table(default_gaps)
         end
      end

      -- Ensure there's at least one non-slow gap.
      if every(gapset[iy], function(g) return fget(g[3]) == drop_slow end) then
         local gap = deli(gaps, randn(#gaps))
         add(gap, gapspr[1])
         gapset[iy][#gapset[iy] + 1] = gap
      end
   end
end

function _init()
   reset_level_vars()
   reset_game_vars()
end

function jump()
   if(dy > 0) then
      y -= flr(abs(dy*5))
      if(dy == 0.5) then
         dy += 0.3
      elseif(dy == 0.8) then
         dy += 0.2
      elseif(dy == 1) then
         dy += 0.1
      else
         dy = -0.5
      end
   else
      y += flr(abs(dy*5))
      if(dy == -0.5) then
         dy -= 0.3
      elseif(dy == -0.8) then
         dy -= 0.2
      elseif(dy == -1) then
         dy -= 0.1
      else
         dy = 0
         jumping = false
      end
   end
end

function ceil(n)
   return -flr(-n)
end

-- is_floor = 8

function fall()
   y += dy
   local sy = y + 8
   if(floor < 8 and sy % 16 == 0) then
      falling = false
      dy = 0
   elseif(flr(sy) >= 126) then
      if(dy == 0 and y >= 118) then
         y += 2
         in_void = true
      else
         y = 118
         falling = false
         dy = 0
      end
   end
end

function _update()
   -- lazy/temp hack to avoid x triggering a jump after level restart.
   if(t() - begin < 0.3) return

   if(gamestate == state_level_end) then
      if(btn(4)) reset_level_vars()
      -- Fall past the void, but not forever.
      if(y < 150) fall()
   elseif(gamestate == state_no_void) then
      if(btn(4)) _init()
   else
      local running_time = t() - begin
         if(flr(running_time) >= time_limit) then
         gamestate = state_no_void
         sfx(6)
         return
      end

      if(btn(0) or btn(1)) then
         moving = true
         if (btn(0) and x >= 1) then
            x -= dx
            facing = 3
         end
         if (btn(1) and x <= 118) then
            x += dx
            facing = 4
         end
      else
         moving = false
      end

      if(not jumping and not falling and not floor_locked) then
         for gap in all(gapset[floor] or {{-1,-1}}) do
            if((x + 2) > gap[1] and (x + 4) < gap[2]) then
               local effect = fget(gap[3])
               if(effect == drop_normal) then
                  dy = 1
                  dx = 2
               elseif(effect == drop_slow) then
                  dy = 0.25
                  dx = 2
               elseif(effect == drop_fast) then
                  dy = 4
                  dx = 3
               else
                  dx = 1
                  dy = 0.1
                  printh("what the heck?" .. arr_to_str(gap) .. " flag " .. effect)
               end

               falling = true
               floor += 1

               if(level > 1 and floor < 8 and randn(10) < level) then
                  floor_locked = true
                  key_at = {}
                  for _=1,min(4,ceil(randn(level)/4)) do
                     -- todo prevent dupes
                     add(key_at, {randn(15) * 8, floor * 16 - 8})
                  end
                  sfx(5)
               else
                  floor_locked = false
               end
               sfx(sfx_drop_tbl[effect])
               break
            end
         end
      end

      -- This should be after the falling check so a) you can't just spam
      -- jump to avoid slow gaps and b) so you can fall straight through gaps below.
      if (not falling and btn(5) and y % 8 == 0) then
         jumping = true
         dy = 0.5
         sfx(0)
      end

      if(not falling and floor_locked) then
         for idx,key in pairs(key_at) do
            if((x + 6) > key[1] and x < (key[1] + 6)) then
               deli(key_at, idx)
               sfx(4)
               break
            end
         end

         if(#key_at == 0) floor_locked = false
      end

      if (jumping and not falling) then
         jump()
      end
      if (falling and not jumping) then
         fall()
      end

      if(y >= 118) then
         local offset  = min(level, 15)
         local running_time = t() - begin
         local void_x1 = 32 + flr(running_time) + offset
         local void_x2 = 96 - flr(running_time) - offset

         if((x + 8) > void_x1 and x < void_x2) then
            fall()
            gamestate = state_level_end
            if(lvldone == nil) then
               lvldone = t()
               level += 1
            end
         end
      end
   end
end

function draw_key_at(key_x, key_y)
   for key in all(key_at) do
      local key_x = key[1]
      local key_y = key[2]
      local at = t() * 10 % 10
      local spr_idx = 7
      if(at % 10 < 2) then
         spr_idx = 7
      elseif(at % 10 < 4) then
         spr_idx = 8
      elseif(at % 10 < 6) then
         spr_idx = 7
      elseif(at % 10 < 8) then
         spr_idx = 9
      else
         spr_idx = 7
      end
      spr(spr_idx, key_x, key_y)
      -- rect(key_x,key_y,key_x+8,key_y+8,7)
   end
end

function draw_void(running_time)
   -- Draw the void layer.
   line(0, 126, 128, 126, 7)
   line(0, 127, 128, 127, 7)
   line(28, 126, 100, 126, 6)
   line(32, 127, 96, 127, 6)

   local offset  = min(level, 15)
   local void_x1 = 32 + flr(running_time) + offset
   local void_x2 = 96 - flr(running_time) - offset

   -- The void has ended
   if(void_x1 >= 64) return

   if(void_x1 <= 64) then
      line(void_x1 - 4, 126, void_x2 + 4, 126, 5)
      line(void_x1, 126, void_x2, 126, 0)
   end
   if(void_x1 <= 60) then
      line(void_x1, 127, void_x2, 127, 5)
      line(void_x1 + 4, 127, void_x2 - 4, 127, 0)
   end
end

function _draw()
   cls(1)
   map(1)

   for iy=1,7 do
      local liney = iy * 16

      for gap in all(gapset[iy]) do
         if(floor_locked and floor == iy) then
            spr(gap[3], gap[1], liney)
            line(gap[1], liney, gap[2] - 1, liney, 13)
         else
            spr(gap[3], gap[1], liney)
         end
      end
   end

   local running_time = t() - begin
   draw_void(running_time)

   if(floor_locked) then
      draw_key_at()
   end

   if(gamestate == state_no_void) then
      spr(facing + 7, x, y)
   else
      local at = flr(t() % 1 * 100)
      if(falling) then
         if(at < 25 or (at > 50 and at < 75)) then
            spr(facing + 52, x, y)
         else
            spr(facing, x, y)
         end
      elseif(moving) then
         if(at < 25 or (at > 50 and at < 75)) then
            spr(facing + 20, x, y)
         else
            spr(facing + 36, x, y)
         end
      else
         spr(facing, x, y)
      end
   end
   -- rect(x,y,x+8,y+8,7)

   local lvltime = nil
   local msg = ''
   if(gamestate == state_running) then
      msg = 'level ' .. level .. ': ' .. nice_time(time_limit - running_time) .. 's'
   elseif(gamestate == state_no_void) then
      msg = 'missed the void, reached lvl ' .. level
      print('press 🅾️ to retry', 0, 120, 12)
   else
      msg = 'entered the void at ' .. nice_time(lvldone - begin) .. 's'
      print('press 🅾️	to proceed', 0, 120, 12)
   end

--   print(msg .. ': '.. lvltime .. 's [' .. x .. " x " .. y .. '] ', 0, 0, 12)
   print(msg, 0, 0, 12)
end

function nice_time(inms)
   local sec = flr(inms)
   local ms = flr(inms * 100 % 100)
   return sec .. '.' .. ms
end

function copy_table(tbl)
   local ret = {}
   for i,v in pairs(tbl) do
      if(type(v) == 'table') then
         ret[i] = copy_table(v)
      else
         ret[i] = v
      end
   end
   return ret
end

function randn(n)
   return flr(rnd(n)) + 1
end

function every(t, f)
   for v in all(t) do
      if not f(v) then
         return false
      end
   end
   return true
end

-- Not supporting non-array tables as not using them.
function arr_to_str(a)
   local res = '['
   for v in all(a) do
      if(type(v) == 'table') then
         res = res .. arr_to_str(v)
      else
         res = res .. tostr(v)
      end
      res = res .. ", "
   end
   return sub(res, 0, #res - 2) .. "]"
end

__gfx__
000000001aaaaaa171d666d10000000000000000712ddd21713bbb31000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaeeaeea11d161d100aaaa0000aaaa001121d1211131b13100000000000000000aa0000000aaaa0000aaaa0000000000000000000000000000000000
00700700aefaefaa111d1d110acacaa00aacaca011121211111313110aa00000000000000aaaaaa00aaaaaa00aaaaaa000000000000000000000000000000000
00077000aaaaaaaa1111d1110acacaa00aacaca011112111111131110aaa99900aa000000aa090900acacaa00aacaca000000000000000000000000000000000
00077000aaaaaaaa111111110aaaa9a00a9aaaa011111111111111110aa090900aaa9990000000000aaaaaa00aaaaaa000000000000000000000000000000000
00700700a9eaae9a111111110aa99aa00aa99aa01111111111111111000000000aa0a0a0000000000aa99aa00aa99aa000000000000000000000000000000000
00000000aaeeeeaa1111111100aaaa0000aaaa00111111111111111100000000000000000000000000aaaa0000aaaa0000000000000000000000000000000000
000000001aaaaaa11111111104400440044004401111111111111111000000000000000000000000055005500550055000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000aaaa0000aaaa0000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000acacaa00aacaca000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000acacaa00aacaca000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000aaaa9a00a9aaaa000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000aa99aa00aa99aa000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000044aaa0000aaa44000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000004400440000000000000000000000000000000000000000000000000000000000000
00003000030000000000000000000000777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
0000300003b00000000000000000000056005600560056000000000000aaaa0000aaaa0000000000000000000000000000000000000000000000000000000000
0000b0000030000000000000000000000000000000000000000000000acacaa00aacaca000000000000000000000000000000000000000000000000000000000
000030000330000000000000000000000000000000000000000000000acacaa00aacaca000000000000000000000000000000000000000000000000000000000
00003b000b00000000000000000000000000000000000000000000000aaaa9a00a9aaaa000000000000000000000000000000000000000000000000000000000
000003000300000000000000000000000000000000000000000000000aa99aa00aa99aa000000000000000000000000000000000000000000000000000000000
0000330003300000000000000000000000000000000000000000000000aaa440044aaa0000000000000000000000000000000000000000000000000000000000
0000b000003000000000000000000000000000000000000000000000044000000000044000000000000000000000000000000000000000000000000000000000
00003000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000030000b300000000000000000000000000000000000000000000000aaaa0000aaaa0000000000000000000000000000000000000000000000000000000000
000000000300000000000000000000000000000000000000000000000acacaa00aacaca000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000acacaa00aacaca000000000000000000000000000000000000000000000000000000000
000000000000055500000000000000000000000000000000000000000aaaa9a00a9aaaa000000000000000000000000000000000000000000000000000000000
000000000000556500b03000000000300000000000000000000000000aa99aa00aa99aa000000000000000000000000000000000000000000000000000000000
00000000000056650330b00055000b3000000000000000000000000004aaaa4004aaaa4000000000000000000000000000000000000000000000000000000000
00000000000055550300300555500300000000000000000000000000004004000040040000000000000000000000000000000000000000000000000000000000
__gff__
0000010000020400000000000000000000000000000000000000000000000000000000000808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2626262223262626262223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2626262626262626262626000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252525252525252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3435343534353416161616160000000000003435000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2424242424242424242424242525252525252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222222200000000000000000000000000003435000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524242425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3435343534353435343534353435343534343435000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3435343534353435343534353435343534353435000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3435343534353435343534353435343534353435000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524252425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3435343534353435343534353435343534353435000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2425242524252425242524252425242524252425240000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3435343534353435343534353435343534353435340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000401000f7301174014740150401c0401f04021040220401e7400e7300d7300a7300572002720140000100013000190001900019000190003a00024000001000010000000000010000000000000000000000000
000600001a5501a55019550175501555013550105500c550085500055007500025000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050000225502255022540205401f5301e5301b520145200c5200955005500005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000e0000125701156011560115501055010540105400f5400f5400e5400d5400d5300c5300c5400a5400953007520045100050006300085000750006500055000450004500035000250000500005000000000000
0004000024110201201e1301e130201202413028140281402b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0106000012600126001460014600126211262314633146330e6210e62305613056130e6000e600056000560000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000013554135521355210541105441054113552135520d5540d5510c5410c5450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000140d0500d0500d050000000705007050070500c0500c0500c05000000070500805003050040000c0500c0500c0500000000000000000000000000000000000000000000000000000000000000000000000
001000140000000000000000022000220102301223013220000000000000000000000000009230092400a23007220022100020002200022000220000000000000000000000000000000000000000000000000000
__music__
00 0a0b4344

