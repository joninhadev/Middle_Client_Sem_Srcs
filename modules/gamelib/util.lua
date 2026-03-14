function postostring(pos)
  return pos.x .. " " .. pos.y .. " " .. pos.z
end

function dirtostring(dir)
  for k,v in pairs(Directions) do
    if v == dir then
      return k
    end
  end
end

function postostring(pos)
  return pos.x .. " " .. pos.y .. " " .. pos.z
end

function dirtostring(dir)
  for k,v in pairs(Directions) do
    if v == dir then
      return k
    end
  end
end

function formatMoney(arg_21_0, arg_21_1)
    local var_21_0 = string.format("%%1%s%%2", arg_21_1)
    local var_21_1 = arg_21_0

    repeat
        var_21_1, k = string.gsub(var_21_1, "^(-?%d+)(%d%d%d)", var_21_0)
    until k == 0

    return var_21_1
end

function string.capitalize(arg_22_0)
    return string.gsub(arg_22_0, "(%w)([%w]*)", function(arg_23_0, arg_23_1)
        return string.upper(arg_23_0) .. string.lower(arg_23_1)
    end)
end

function matchText(arg_24_0, arg_24_1)
    arg_24_0 = arg_24_0:lower()
    arg_24_1 = arg_24_1:lower()

    if arg_24_0 == arg_24_1 then
        return true
    end

    if #arg_24_0 >= 1 and arg_24_1:find(arg_24_0, 1, true) then
        return true
    end

    return false
end