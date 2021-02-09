pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- loodling
-- by broquaint

x = 4
y = 8
dy = 0
jumping = false
falling = false
facing = 4

floor = 1
floor_unlocked = true
key_at = {}

begin = t()
gamestate = 'running'
lvldone = nil

drop_normal = 1
drop_slow   = 2
drop_fast   = 4

sfx_drop_tbl = {
   [drop_normal] = 1,
   [drop_slow]   = 3,
   [drop_fast]   = 2
}

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

function fall()
   y += dy
   if((y + 8) % 16 == 0) then
      falling = false
      dy = 0
   end
end

function _update()
   if (btn(0) and x >= 1) then
      x -= 2
      facing = 3
   end
   if (btn(1) and x <= 118) then
      x += 2
      facing = 4
   end

   if (not falling and btn(2) and y % 8 == 0) then
      jumping = true
      dy = 0.5
      sfx(0)
   end

   if(not jumping and not falling and not floor_locked) then
      for gap in all(gapset[floor] or {{-1,-1}}) do
         if(x > gap[1] and x < gap[2]) then
            local effect = fget(gap[3])
            if(effect == drop_normal) then
               dy = 1
            elseif(effect == drop_slow) then
               dy = 0.125
            else
               dy = 4
            end

            falling = true
            floor += 1
            if(floor % 2 == 0 and floor < 8) then
               floor_locked = true
               key_at = {randn(16) * 8, floor * 16 - 8}
            else
               floor_locked = false
            end
            sfx(sfx_drop_tbl[effect])
            break
         end
      end
   end

   if(not falling and floor_locked and x > key_at[1] and x < key_at[1] + 8) then
      floor_locked = false
      sfx(4)
   end

   if (jumping and not falling) then
      jump()
   end
   if (falling and not jumping) then
      fall()
   end

   if(y == 120) then
      gamestate = 'end of level'
      if(lvldone == nil) lvldone = t()
   end
end

function draw_key_at(key_x, key_y)
   local at = t() * 10 % 10
   if(at % 10 < 2) then
      spr(7, key_x, key_y)
   elseif(at % 10 < 4) then
      spr(8, key_x, key_y)
   elseif(at % 10 < 6) then
      spr(7, key_x, key_y)
   elseif(at % 10 < 8) then
      spr(9, key_x, key_y)
   else
      spr(7, key_x, key_y)
   end
end

function _draw()
   cls(1)

   for iy=1,7 do
      local liney = iy * 16
      line(0, liney, 128, liney, 7)

      for gap in all(gapset[iy]) do
         if(floor_locked) then
            spr(gap[3], gap[1], liney)
            line(gap[1], liney, gap[2] - 1, liney, 13)
         else
            line(gap[1], liney, gap[2] - 1, liney, 1)
            spr(gap[3], gap[1], liney)
         end
      end
   end

   if(floor_locked) then
      draw_key_at(key_at[1], key_at[2])
   end

   spr(facing, x, y)

   local lvltime = nil
   local msg = ''
   if(gamestate == 'running') then
      lvltime = nice_time(t() - begin)
      msg = 'floor ' .. floor
   else
      lvltime = nice_time(lvldone - begin)
      msg = 'completed'
   end

   print(msg .. ': '.. lvltime .. 's [' .. x .. " x " .. y .. '] ', 0, 0, 12)
end

function nice_time(inms)
   local sec = flr(inms)
   local ms = flr(inms * 100 % 100)
   return sec .. '.' .. ms
end

function copy_table(tbl)
   local ret = {}
   for i,v in pairs(tbl) do
      ret[i] = v
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

gapset={}
gapspr={2,5,6}
function _init()
   local default_gaps={
      {8,16}, {16,24}, {24,32}, {32,40}, {40,48}, {48,56}, {56,64}, {64,72},
      {72,80}, {80,88}, {88,96}, {96,104}, {104,112}
   }
   local gaps = copy_table(default_gaps)
   for iy=1,7 do
      local gapcount = randn(3)
      gapset[iy]={}
      for idx=1,gapcount do
         if(#gaps == 0) then
            gaps = copy_table(default_gaps)
         end
         -- Remove gaps so they aren't repeated across floors.
         local gap = deli(gaps, randn(#gaps))
         add(gap, gapspr[randn(#gapspr)])
         gapset[iy][idx] = gap
      end

      -- Ensure there's at least one non-slow gap.
      if every(gapset[iy], function(g) return fget(g[3]) == drop_slow end) then
         local gap = deli(gaps, randn(#gaps))
         add(gap, gapspr[1])
         gapset[iy][#gapset[iy] + 1] = gap
      end
   end
end

__gfx__
000000001aaaaaa171d666d11111111111111111712ddd21713bbb31111111111111111111111111000000000000000000000000000000000000000000000000
00000000aaeeaeea11d161d111aaaa1111aaaa111121d1211131b13111111111111111111aa11111000000000000000000000000000000000000000000000000
00700700aefaefaa111d1d111acacaa11aacaca111121211111313111aa11111111111111aaaaaa1000000000000000000000000000000000000000000000000
00077000aaaaaaaa1111d1111acacaa11aacaca111112111111131111aaa99911aa111111aa19191000000000000000000000000000000000000000000000000
00077000aaaaaaaa111111111aaaa9a11a9aaaa111111111111111111aa191911aaa999111111111000000000000000000000000000000000000000000000000
00700700a9eaae9a111111111aa99aa11aa99aa11111111111111111111111111aa1a1a111111111000000000000000000000000000000000000000000000000
00000000aaeeeeaa1111111111aaaa1111aaaa111111111111111111111111111111111111111111000000000000000000000000000000000000000000000000
000000001aaaaaa11111111115511551155115511111111111111111111111111111111111111111000000000000000000000000000000000000000000000000
__gff__
0000010000020400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000401000f7301174014740150401c0401f04021040220401e7400e7300d7300a7300572002720140000100013000190001900019000190003a00024000001000010000000000010000000000000000000000000
000600001a5501a55019550175501555013550105500c550085500055007500025000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050000225502255022540205401f5301e5301b520145200c5200955005500005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00120000125701156011560115501055010540105400f5400f5400e5400d5400d5300c5300c5400b5400b5300b5200a5300952009520085200752006520055200453004530035200252000510005000000000000
0004000024130201401e1401e150201502414028160281602b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000140d0500d0500d050000000705007050070500c0500c0500c05000000070500805003050040000c0500c0500c0500000000000000000000000000000000000000000000000000000000000000000000000
001000140000000000000000022000220102301223013220000000000000000000000000009230092400a23007220022100020002200022000220000000000000000000000000000000000000000000000000000
__music__
00 0a0b4344

