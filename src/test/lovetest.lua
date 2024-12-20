local lovetest = {}

-- Run the unit tests, On windows, don't quit. This allows the user to see the
-- test results in the console
function lovetest.run() 
  require "test/lunatest"

  for _, filename in ipairs(love.filesystem.getDirectoryItems('test')) do
    local index, _ = string.find(filename,  "test_")
    if index == 1 then
      local testname, _ = filename:gsub(".lua", "")
      lunatest.suite("test/" .. testname)
    end
  end

  local opts = {verbose=false}
  opts.quit_on_failure = love._os ~= "Windows"
  lunatest.run(nil, opts)

  if love._os ~= "Windows" then
    love.event.push("quit")
  end
end

return lovetest
