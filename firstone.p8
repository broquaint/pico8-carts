pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- loodling
-- by broquaint

x = 4
y = 8
floor = 1
jumping = false
falling = false
facing = 4
dy = 0
begin = t()
gamestate = 'running'
lvldone = nil

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
   y += 2 -- flr(abs(dy*5))
   if((y + 8) % 16 == 0) then
      falling = false
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


   if(not jumping and not falling) then
      for gap in all(gapset[floor] or {{-1,-1}}) do
         if(x > gap[1] and x < gap[2]) then
            falling = true
            dy = 0.5
            floor += 1
            sfx(1)
            break
         end
      end
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

function _draw()
   cls(1)

   for iy=1,7 do
      local liney = iy * 16
      line(0, liney, 128, liney, 7)

      for gap in all(gapset[iy]) do
         line(gap[1], liney, gap[2] - 1, liney, 1)
         spr(2, gap[1], liney)
      end
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

   print(msg .. ': '.. lvltime .. 's [' .. x .. " x " .. y .. ']', 0, 0, 12)
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

gapset={}
function _init()
   local default_gaps={
      {8,16}, {16,24}, {24,32}, {32,40}, {40,48}, {48,56}, {56,64}, {64,72},
      {72,80}, {80,88}, {88,96}, {96,104}, {104,112}
   }
   local gaps = copy_table(default_gaps)
   for iy=1,7 do
      local gapcount = flr(rnd(2)) + 1
      gapset[iy]={}
      for idx=1,gapcount do
         -- Remove gaps so they aren't repeated across floors.
         local gap = deli(gaps, flr(rnd(#gaps))+1)
         gapset[iy][idx] = gap
         if(#gaps == 0) then
            gaps = copy_table(default_gaps)
         end
      end
   end

end

__gfx__
000000001aaaaaa171d666d111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaeeaeea11d161d111aaaa1111aaaa110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700aefaefaa111d1d111acacaa11aacaca10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000aaaaaaaa1111d1111acacaa11aacaca10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000aaaaaaaa111111111aaaa9a11a9aaaa10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700a9eaae9a111111111aa99aa11aa99aa10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaeeeeaa1111111111aaaa1111aaaa110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000001aaaaaa11111111115511551155115510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000301000f7301174014740150401c0401f04021040220401e7400e7300d7300a7300572002720140000100013000190001900019000190003a00024000001000010000000000010000000000000000000000000
000600001a5501a55019550175501555013550105500c550085500055007500025000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
