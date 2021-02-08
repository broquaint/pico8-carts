pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- loodling
-- by broquaint

x = 4
y = 8
level = 1
jumping = false
falling = false
dy = 0

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
   if (btn(0) and x >= 1) then x=x-2 end
   if (btn(1) and x <= 118) then x=x+2 end

   if (btn(2) and y % 8 == 0) then
      jumping = true
      dy = 0.5
--      sfx(0)
   end

   local curgap = gapset[level] or {-1,-1}
   if(not jumping and not falling and x > curgap[1] and x < curgap[2]) then
      falling = true
      dy = 0.5
      level += 1
   end


   if (jumping and not falling) then
      jump()
   end
   if (falling and not jumping) then
      fall()
   end
end

function _draw()
   cls(1)

   for iy=1,7 do
      local liney = iy * 16
      line(0, liney, 128, liney, 7)
      local gap=gapset[iy]
      line(gap[1], liney, gap[2], liney, 1)
   end

   spr(1, x, y)
   print(x .. " x " .. y .. " @ " .. level, 0, 0, 12)
end

gapset={}
function _init()
   print("hi")
   local gaps={
      {8,16}, {16,24}, {24,32}, {32,40}, {40,48}, {48,56}, {56,64}, {64,72},
      {72,80}, {80,88}, {88,96}, {96,104}, {104,112}
   }
   for iy=1,7 do
      gapset[iy] = gaps[flr(rnd(#gaps))+1]
   end

end

__gfx__
000000001aaaaaa10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaeeaeea0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700aefaefaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000aaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000aaaaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700a9eaae9a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaeeeeaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000001aaaaaa10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000301001175012750167501a7501e7502275023750297502c7502c75024750217501570011700140000100013000190001900019000190003a00024000001000010000000000010000000000000000000000000
