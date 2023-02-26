function run_animations()
   for obj in all(g_anims) do
      if costatus(obj.co) != 'dead' then
         assert(coresume(obj.co))
      else
         del(g_anims, obj)
      end
   end
end

function wait(n)
   for _ = 1,n do yield() end
end

function delay(f, n)
   animate(function() wait(n) f() end)
end

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
   add(g_anims, obj)
end

function easeinquad(t)
   return t*t
end
function easeoutquad(t)
  t-=1
  return 1-t*t
end
function easeinoutovershoot(t)
  if t<.5 then
    return (2.7*8*t*t*t-1.7*4*t*t)/2
  else
    t-=1
    return 1+(2.7*8*t*t*t+1.7*4*t*t)/2
  end
end
function lerp(a,b,t)
   return a+(b-a)*t
end
